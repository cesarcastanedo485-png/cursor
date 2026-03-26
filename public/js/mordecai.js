/**
 * Mordecai's Maximus — Cursor-inspired chat
 * Microphone, agent selection, Keep all / Undo all, Planning vs Ask mode
 * Commissions tab: phased website building
 */
(function () {
  "use strict";

  const STORAGE_KEY = "mordecai_chats";
  const STORAGE_CURRENT = "mordecai_current_chat";
  const STORAGE_ACTIVE_COMMISSION = "mordecai_active_commission";
  const STORAGE_BRIDGE_SECRET = "mordecai_bridge_secret";
  const STORAGE_ADMIN_TOKEN = "mordecai_admin_token";

  let currentChatId = null;
  let chats = {};
  let pendingChanges = [];
  let isRecording = false;
  let recognition = null;
  let commissionTypes = null;
  let activeCommission = null;
  let referenceImageData = null;
  let commissionPollTimer = null;
  let commissionPollToken = null;

  const PHASE_STATUS = {
    pending: "pending",
    running: "running",
    needsDebug: "needs-debug",
    done: "done",
    failed: "failed",
  };

  const PREVIEW_URL_STORAGE_KEY = "mordecai_preview_url";
  const MORDECAI_PUBLIC_URL_STORAGE_KEY = "mordecai_public_base_url";

  function $(id) {
    return document.getElementById(id);
  }

  /** Safe API base: always returns "" or valid origin. Never allows backslashes. */
  function safeApiBase() {
    try {
      var base = typeof apiUrl === "function" ? apiUrl("") : "";
      if (base == null) base = "";
      base = String(base);
      if (base.indexOf("\\") >= 0) {
        console.error("[Mordecai] Invalid apiUrl base contains backslash:", base);
        return "";
      }
      if (base && base !== "/" && !base.startsWith("http")) {
        console.warn("[Mordecai] apiUrl base may be invalid, using empty:", base);
        return "";
      }
      return base === "/" ? "" : base;
    } catch (e) {
      console.error("[Mordecai] safeApiBase error:", e);
      return "";
    }
  }

  /** Build API URL safely. Rejects backslashes. */
  function safeApiPath(path) {
    if (!path || typeof path !== "string") return "/";
    path = path.replace(/\\/g, "/");
    if (path.charAt(0) !== "/") path = "/" + path;
    return path;
  }

  /** Fetch with URL validation. Logs and rejects invalid URLs. */
  function getSavedAuthHeaders() {
    var headers = {};
    try {
      var bridgeSecret = (localStorage.getItem(STORAGE_BRIDGE_SECRET) || "").trim();
      if (bridgeSecret) headers["X-Bridge-Secret"] = bridgeSecret;
      var adminToken = (localStorage.getItem(STORAGE_ADMIN_TOKEN) || "").trim();
      if (adminToken) headers["X-Admin-Token"] = adminToken;
    } catch (_) {}
    return headers;
  }

  function mergeHeaders(base, extra) {
    var out = {};
    [base || {}, extra || {}].forEach(function (src) {
      Object.keys(src).forEach(function (k) {
        out[k] = src[k];
      });
    });
    return out;
  }

  function safeFetch(urlOrPath, opts) {
    opts = opts || {};
    var authHeaders = getSavedAuthHeaders();
    var base = safeApiBase();
    var path = typeof urlOrPath === "string" ? urlOrPath : "";
    if (path.indexOf("/") === 0 || path.indexOf("http") === 0) {
      var url = path.indexOf("http") === 0 ? path : (base || "") + path;
      if (url.indexOf("\\") >= 0) {
        console.error("[Mordecai] BLOCKED invalid fetch URL (contains backslash):", url);
        return Promise.reject(new Error("Invalid URL: contains backslash"));
      }
      if (typeof console !== "undefined" && console.log) {
        console.log("[Mordecai] fetch:", url.slice(0, 80) + (url.length > 80 ? "…" : ""));
      }
      var callOpts = Object.assign({}, opts, {
        headers: mergeHeaders(authHeaders, opts.headers || {}),
      });
      return fetch(url, callOpts);
    }
    var full = (base || "") + safeApiPath(path);
    if (full.indexOf("\\") >= 0) {
      console.error("[Mordecai] BLOCKED invalid fetch URL (contains backslash):", full);
      return Promise.reject(new Error("Invalid URL: contains backslash"));
    }
    if (typeof console !== "undefined" && console.log) {
      console.log("[Mordecai] fetch:", full.slice(0, 80) + (full.length > 80 ? "…" : ""));
    }
    var fullOpts = Object.assign({}, opts, {
      headers: mergeHeaders(authHeaders, opts.headers || {}),
    });
    return fetch(full, fullOpts);
  }

  function showStatusEl(msg, duration) {
    const statusEl = $("mordecaiStatus");
    if (!statusEl) return;
    statusEl.textContent = msg || "";
    statusEl.hidden = !msg;
    if (duration && msg) {
      setTimeout(function () {
        statusEl.hidden = true;
        statusEl.textContent = "";
      }, duration);
    }
  }

  function loadChats() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      chats = raw ? JSON.parse(raw) : {};
    } catch (_) {
      chats = {};
    }
  }

  function saveChats() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(chats));
    } catch (_) {}
  }

  function createChat() {
    const id = "chat_" + Date.now();
    chats[id] = { id, messages: [], createdAt: Date.now(), title: "New chat" };
    saveChats();
    return id;
  }

  function getCurrentChat() {
    if (!currentChatId || !chats[currentChatId]) {
      currentChatId = createChat();
      try {
        localStorage.setItem(STORAGE_CURRENT, currentChatId);
      } catch (_) {}
    }
    return chats[currentChatId];
  }

  function renderChatList() {
    const list = $("chatList");
    if (!list) return;
    const ids = Object.keys(chats).sort((a, b) => (chats[b].createdAt || 0) - (chats[a].createdAt || 0));
    list.innerHTML = ids.slice(0, 20).map(function (id) {
      const c = chats[id];
      const title = (c && c.title) || "Chat";
      const active = id === currentChatId ? " active" : "";
      return '<button type="button" class="mordecai-chat-item' + active + '" data-id="' + escapeAttr(id) + '">' + escapeHtml(title) + "</button>";
    }).join("");
  }

  function escapeHtml(s) {
    const div = document.createElement("div");
    div.textContent = s;
    return div.innerHTML;
  }

  function escapeAttr(s) {
    return escapeHtml(s).replace(/"/g, "&quot;");
  }

  function renderMessages() {
    const container = $("messages");
    if (!container) return;
    const chat = getCurrentChat();
    const msgs = (chat && chat.messages) || [];
    container.innerHTML = msgs.map(function (m) {
      const role = m.role || "user";
      const text = (m.content || "").replace(/\n/g, "<br>");
      const code = m.code ? '<div class="code-block">' + escapeHtml(m.code) + "</div>" : "";
      return '<div class="mordecai-msg ' + role + '">' + text + code + "</div>";
    }).join("");
    container.scrollTop = container.scrollHeight;
  }

  function addMessage(role, content, code) {
    const chat = getCurrentChat();
    if (!chat.messages) chat.messages = [];
    chat.messages.push({ role, content, code: code || null });
    if (chat.messages.length === 1 && content) {
      chat.title = content.slice(0, 40) + (content.length > 40 ? "…" : "");
    }
    saveChats();
    renderMessages();
    renderChatList();
  }

  function setPendingChanges(changes) {
    pendingChanges = changes || [];
    const bar = $("actionsBar");
    if (bar) bar.hidden = pendingChanges.length === 0;
  }

  function getMode() {
    const planBtn = $("modePlan");
    return planBtn && planBtn.classList.contains("active") ? "plan" : "ask";
  }

  function getAgent() {
    const sel = $("agentSelect");
    return (sel && sel.value) || "agent";
  }

  function getActiveCommission() {
    try {
      const raw = localStorage.getItem(STORAGE_ACTIVE_COMMISSION);
      return raw ? JSON.parse(raw) : null;
    } catch (_) {
      return null;
    }
  }

  function setActiveCommission(commission) {
    activeCommission = commission;
    try {
      if (commission) {
        localStorage.setItem(STORAGE_ACTIVE_COMMISSION, JSON.stringify(commission));
      } else {
        localStorage.removeItem(STORAGE_ACTIVE_COMMISSION);
      }
    } catch (_) {}
  }

  async function sendToBackend(messages) {
    const comm = getActiveCommission();
    const res = await safeFetch("/api/mordecai/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        messages,
        mode: getMode(),
        agent: getAgent(),
        activeCommission: comm || undefined,
      }),
    });
    if (!res.ok) throw new Error("Chat request failed");
    return res.json();
  }

  async function sendMessage() {
    const input = $("mordecaiInput");
    const sendBtn = $("sendBtn");
    if (!input || !sendBtn) return;
    const text = (input.value || "").trim();
    if (!text) return;

    input.value = "";
    input.style.height = "auto";
    addMessage("user", text);

    sendBtn.disabled = true;
    const chat = getCurrentChat();
    chat.messages.push({ role: "assistant", content: "Thinking…", code: null });
    renderMessages();
    const thinkingEl = $("messages").lastElementChild;
    if (thinkingEl) thinkingEl.classList.add("thinking");

    try {
      const messages = (chat.messages || []).slice(0, -1).map(function (m) {
        return { role: m.role, content: m.content };
      });

      const data = await sendToBackend(messages);
      const content = (data && data.content) || "Use Cursor (Composer) to build. This chat is for planning and notes.";
      const code = data && data.code ? data.code : null;

      chat.messages[chat.messages.length - 1] = { role: "assistant", content, code };
      saveChats();
      renderMessages();

      if (data && data.changes && data.changes.length > 0) {
        setPendingChanges(data.changes);
      } else {
        setPendingChanges([]);
      }
    } catch (e) {
      console.error("Mordechaius Maximus chat error", e);
      chat.messages[chat.messages.length - 1] = { role: "assistant", content: "Error: " + (e.message || "Request failed"), code: null };
      saveChats();
      renderMessages();
      showStatusEl("Chat error. Is the server running?", 4000);
    } finally {
      sendBtn.disabled = false;
    }
  }

  function initMic() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      const btn = $("micBtn");
      if (btn) btn.title = "Voice input not supported in this browser";
      return;
    }

    recognition = new SpeechRecognition();
    recognition.continuous = false;
    recognition.interimResults = true;
    recognition.lang = "en-US";

    recognition.onresult = function (e) {
      const last = e.results.length - 1;
      const transcript = e.results[last][0].transcript;
      if (e.results[last].isFinal && transcript) {
        const input = $("mordecaiInput");
        if (input) input.value = (input.value + " " + transcript).trim();
      }
    };

    recognition.onerror = function () {
      isRecording = false;
      const btn = $("micBtn");
      if (btn) btn.classList.remove("recording");
    };

    recognition.onend = function () {
      isRecording = false;
      const btn = $("micBtn");
      if (btn) btn.classList.remove("recording");
    };
  }

  function toggleMic() {
    if (!recognition) return;
    if (isRecording) {
      recognition.stop();
    } else {
      recognition.start();
      isRecording = true;
      const btn = $("micBtn");
      if (btn) btn.classList.add("recording");
    }
  }

  function keepAll() {
    if (pendingChanges.length === 0) return;
    showStatusEl("Keep all — add file-edit backend to apply changes", 3000);
    setPendingChanges([]);
  }

  function undoAll() {
    setPendingChanges([]);
    showStatusEl("Undo all — changes discarded", 2000);
  }

  let screenStream = null;

  async function startScreenShare() {
    try {
      const stream = await navigator.mediaDevices.getDisplayMedia({ video: true });
      screenStream = stream;
      const overlay = $("mordecaiScreenOverlay");
      const video = $("mordecaiScreenVideo");
      if (overlay) overlay.hidden = false;
      if (video) {
        video.srcObject = stream;
      }
      stream.getVideoTracks()[0].onended = stopScreenShare;
    } catch (e) {
      showStatusEl("Screen share failed: " + (e.message || "Permission denied"), 3000);
    }
  }

  function stopScreenShare() {
    if (screenStream) {
      screenStream.getTracks().forEach(function (t) { t.stop(); });
      screenStream = null;
    }
    const overlay = $("mordecaiScreenOverlay");
    const video = $("mordecaiScreenVideo");
    if (overlay) overlay.hidden = true;
    if (video) video.srcObject = null;
  }

  function switchTab(tabId) {
    const chatView = $("chat-view");
    const commissionsView = $("commissions-view");
    const tabs = document.querySelectorAll(".mordecai-tab");
    tabs.forEach(function (t) {
      t.classList.toggle("active", t.dataset.tab === tabId);
      t.setAttribute("aria-pressed", t.dataset.tab === tabId ? "true" : "false");
    });
    if (tabId === "commissions") {
      if (chatView) chatView.hidden = true;
      if (commissionsView) commissionsView.hidden = false;
      loadCommissionTypes();
      if (activeCommission && activeCommission.phases && activeCommission.phases.length > 0) {
        renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
        showCommSection("commPhaseSection");
      } else {
        showCommSection("commCategorySection");
      }
    } else {
      if (chatView) chatView.hidden = false;
      if (commissionsView) commissionsView.hidden = true;
    }
  }

  var COMMISSION_TYPES_FALLBACK = {
    websites: {
      types: [
        { name: "E-commerce", playbookId: "ecommerce-website" },
        { name: "Scheduling", playbookId: "scheduling-website" },
        { name: "Blog", playbookId: "blog-website" },
        { name: "Portfolio", playbookId: "portfolio-website" },
      ],
    },
    apps: { types: [] },
  };

  async function loadCommissionTypes() {
    if (commissionTypes) return commissionTypes;
    try {
      const res = await safeFetch("/data/commission-types.json");
      commissionTypes = res.ok ? await res.json() : COMMISSION_TYPES_FALLBACK;
      if (!commissionTypes?.websites?.types?.length) commissionTypes = COMMISSION_TYPES_FALLBACK;
    } catch (_) {
      commissionTypes = COMMISSION_TYPES_FALLBACK;
    }
    return commissionTypes;
  }

  async function loadPlaybook(playbookId) {
    const res = await safeFetch("/data/playbooks/" + playbookId + ".json");
    if (!res.ok) throw new Error("Playbook not found");
    return res.json();
  }

  function showCommSection(sectionId) {
    ["commCategorySection", "commTypeSection", "commFormSection", "commPhaseSection"].forEach(function (id) {
      const el = $(id);
      if (el) el.hidden = id !== sectionId;
    });
    if (sectionId === "commTypeSection") {
      var t = (commissionTypes && commissionTypes.websites && commissionTypes.websites.types) ? commissionTypes.websites.types : null;
      renderTypeCards(t);
    }
    if (sectionId === "commPhaseSection" && activeCommission) {
      resetStuckInProgress();
      setPhaseLoading(false);
      checkCommissionApiAndRender();
    }
  }

  async function checkCommissionApiAndRender() {
    var errEl = $("commApiError");
    var listEl = $("commPhaseList");
    if (!errEl || !listEl) return;
    try {
      var res = await safeFetch("/api/commissions/health");
      if (!res.ok || res.status === 404) {
        errEl.textContent = "Commission API not available. If you're on port 3001, open http://localhost:3000 instead (npm start runs the API there).";
        errEl.hidden = false;
        listEl.innerHTML = "";
        if ($("commProjectPath")) $("commProjectPath").hidden = true;
        return;
      }
      errEl.hidden = true;
      if (activeCommission && activeCommission.phases) {
        renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
        var runningEntry = Object.entries(activeCommission.phaseStatus || {}).find(function (entry) {
          return entry[1] === PHASE_STATUS.running;
        });
        if (runningEntry && activeCommission.cursorAgentId) {
          var runningPhaseId = runningEntry[0];
          var runningPhase = activeCommission.phases.find(function (p) { return p.id === runningPhaseId; });
          startPhasePolling(runningPhaseId, runningPhase ? runningPhase.name : runningPhaseId, activeCommission.cursorAgentId);
        }
      }
      updateProjectPath();
    } catch (e) {
      errEl.textContent = "Commission API not available. If you're on port 3001, open http://localhost:3000 instead (npm start runs the API there).";
      errEl.hidden = false;
      listEl.innerHTML = "";
      if ($("commProjectPath")) $("commProjectPath").hidden = true;
    }
  }

  function resetStuckInProgress() {
    if (!activeCommission || !activeCommission.phaseStatus) return;
    var changed = false;
    Object.keys(activeCommission.phaseStatus).forEach(function (pid) {
      if (activeCommission.phaseStatus[pid] === "in-progress") {
        activeCommission.phaseStatus[pid] = PHASE_STATUS.running;
        changed = true;
      }
    });
    if (changed) setActiveCommission(activeCommission);
  }

  function renderTypeCards(types) {
    const container = $("commTypeCards");
    if (!container) return;
    var list = (types && types.length > 0) ? types : (COMMISSION_TYPES_FALLBACK.websites && COMMISSION_TYPES_FALLBACK.websites.types) || [];
    if (list.length === 0) return;
    try {
      container.innerHTML = list.map(function (t) {
        var pid = (t && t.playbookId) ? String(t.playbookId) : "";
        var nm = (t && t.name) ? String(t.name) : "Unknown";
        return '<button type="button" class="comm-card" data-playbook-id="' + escapeAttr(pid) + '" data-type-name="' + escapeAttr(nm) + '">' + escapeHtml(nm) + "</button>";
      }).join("");
    } catch (e) {
      console.error("[Mordecai] renderTypeCards error:", e);
    }
  }

  function renderPhaseList(phases, phaseStatus) {
    const container = $("commPhaseList");
    if (!container) return;
    phaseStatus = phaseStatus || {};
    container.innerHTML = phases.map(function (p, i) {
      const status = phaseStatus[p.id] || PHASE_STATUS.pending;
      const prevStatus = i ? (phaseStatus[phases[i - 1].id] || PHASE_STATUS.pending) : PHASE_STATUS.done;
      const canStart = status === PHASE_STATUS.pending && prevStatus === PHASE_STATUS.done;
      const canRetry = status === PHASE_STATUS.failed;
      const canChecklist = status === PHASE_STATUS.needsDebug || status === PHASE_STATUS.done;
      const canContinue =
        status === PHASE_STATUS.done &&
        phases[i + 1] &&
        (phaseStatus[phases[i + 1].id] || PHASE_STATUS.pending) === PHASE_STATUS.pending;
      const canForceDone = status === PHASE_STATUS.running;
      return '<div class="comm-phase-item" data-phase-id="' + escapeAttr(p.id) + '">' +
        '<span class="comm-phase-name">' + escapeHtml(p.name) + "</span>" +
        '<span class="comm-phase-badge ' + status + '">' + status + "</span>" +
        '<div class="comm-phase-actions">' +
        (canStart ? '<button type="button" class="comm-phase-btn primary" data-action="start">Start Phase</button>' : "") +
        (canRetry ? '<button type="button" class="comm-phase-btn primary" data-action="start">Retry Phase</button>' : "") +
        (canChecklist ? '<button type="button" class="comm-phase-btn" data-action="debug">Review Checklist</button>' : "") +
        (canForceDone ? '<button type="button" class="comm-phase-btn" data-action="force-done">Mark complete anyway</button>' : "") +
        (canContinue ? '<button type="button" class="comm-phase-btn" data-action="continue">Continue</button>' : "") +
        "</div></div>";
    }).join("");
  }

  var phaseAbortController = null;

  function setPhaseLoading(loading, phaseName) {
    const el = $("commPhaseLoading");
    const textEl = $("commPhaseLoadingText");
    const cancelBtn = $("commCancelPhase");
    if (el) el.hidden = !loading;
    if (textEl) textEl.textContent = phaseName ? "Loading: " + phaseName + "…" : "Loading phase…";
    if (cancelBtn) cancelBtn.style.visibility = loading ? "visible" : "hidden";
  }

  function showLastResult(dataOrSummary, filesChanged) {
    const el = $("commLastResult");
    if (!el) return;
    const data = typeof dataOrSummary === "object" ? dataOrSummary : { summary: dataOrSummary, filesChanged };
    if (!data.summary && !data.instructions && !data.agentMode) {
      el.hidden = true;
      return;
    }
    el.hidden = false;
    if (data.agentMode) {
      var wp = data.workspacePath
        ? "<p><strong>Your commission workspace folder:</strong> <code>" +
          escapeHtml(data.workspacePath) +
          "</code></p>" +
          "<p><small>Cloud Agent commits to your GitHub repo. On your PC: open this folder in Cursor, pull the commission branch, then run the site (e.g. <code>npm install</code> and <code>npm run dev -- -p 3001</code> so Mordecai can keep port 3000).</small></p>"
        : "";
      el.innerHTML =
        "<strong>One agent, one workspace.</strong><br>" +
        escapeHtml(data.summary || "") +
        wp;
    } else if (data.cursorMode && data.instructions) {
      el.innerHTML =
        "<strong>Ask Cursor (Composer) to build this phase:</strong><br>" +
        "<p>Workspace folder: <code>" + escapeHtml(data.workspacePath || "") + "</code></p>" +
        "<p>Copy the instructions below and paste into Cursor Composer:</p>" +
        "<pre class=\"comm-instructions\">" + escapeHtml(data.instructions) + "</pre>";
    } else {
      el.textContent = data.summary;
      if (data.filesChanged && data.filesChanged.length) {
        el.innerHTML = escapeHtml(data.summary) + "<br><small>Files: " + escapeHtml(data.filesChanged.join(", ")) + "</small>";
      }
    }
  }

  function updateProjectPath() {
    const el = $("commProjectPath");
    if (!el || !activeCommission) return;
    if (!activeCommission.clientInfo?.company) {
      el.hidden = true;
      return;
    }
    apiGetWorkspacePath().then(function (data) {
      if (data && data.path) {
        el.textContent = "Project folder: " + data.path;
        el.hidden = false;
      } else {
        el.hidden = true;
      }
    }).catch(function () { el.hidden = true; });
  }

  function normalizePreviewUrl(raw) {
    var v = String(raw || "").trim();
    if (!v) return "";
    if (!/^https?:\/\//i.test(v)) {
      v = "http://" + v;
    }
    return v;
  }

  function loadPreviewUrl() {
    try {
      return localStorage.getItem(PREVIEW_URL_STORAGE_KEY) || "";
    } catch (_) {
      return "";
    }
  }

  function savePreviewUrl(v) {
    try {
      localStorage.setItem(PREVIEW_URL_STORAGE_KEY, v || "");
    } catch (_) {}
  }

  function runtimeMordecaiPublicUrl() {
    try {
      var runtimeValue =
        typeof window !== "undefined" ? window.__MORDECAI_PUBLIC_URL__ : "";
      return String(runtimeValue || "").trim();
    } catch (_) {
      return "";
    }
  }

  function loadMordecaiPublicUrl() {
    try {
      var fromStorage = localStorage.getItem(MORDECAI_PUBLIC_URL_STORAGE_KEY) || "";
      if (fromStorage) return fromStorage;
      return runtimeMordecaiPublicUrl();
    } catch (_) {
      return runtimeMordecaiPublicUrl();
    }
  }

  function saveMordecaiPublicUrl(v) {
    try {
      localStorage.setItem(MORDECAI_PUBLIC_URL_STORAGE_KEY, v || "");
    } catch (_) {}
  }

  function updateMordecaiPublicUrlHint(el, normalizedUrl) {
    if (!el) return;
    var host = (location && location.hostname ? location.hostname : "").toLowerCase();
    var isLocal = host === "localhost" || host === "127.0.0.1";
    if (!isLocal) {
      el.hidden = true;
      return;
    }
    var originText = location.origin || "this browser";
    if (normalizedUrl) {
      el.textContent =
        "Desktop origin is " +
        originText +
        ". Phone should use: " +
        normalizedUrl +
        " (not localhost).";
      if (typeof console !== "undefined" && console.info) {
        console.info("[Mordecai] Phone URL hint:", normalizedUrl, "| current origin:", originText);
      }
    } else {
      el.textContent =
        "Desktop origin is " +
        originText +
        ". Set your ngrok/tunnel URL so phone WebView does not use localhost.";
    }
    el.hidden = false;
  }

  async function apiGetWorkspacePath() {
    const res = await safeFetch("/api/commissions/workspace-path", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        commissionId: activeCommission?.id,
        clientInfo: activeCommission?.clientInfo,
        playbookId: activeCommission?.playbookId,
      }),
    });
    return res.ok ? res.json() : { path: null };
  }

  async function apiDeleteWorkspace() {
    const res = await safeFetch("/api/commissions/delete-workspace", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        commissionId: activeCommission?.id,
        clientInfo: activeCommission?.clientInfo,
        playbookId: activeCommission?.playbookId,
      }),
    });
    if (!res.ok) {
      const data = await res.json().catch(function () { return {}; });
      throw new Error(data.error || "Delete failed");
    }
  }

  async function apiExecutePhase(commissionId, phaseId, playbookId, clientInfo, cursorAgentId, githubRepo, signal) {
    const body = {
      commissionId,
      phaseId,
      playbookId,
      clientInfo,
      cursorAgentId: cursorAgentId || undefined,
      referenceImage: referenceImageData || undefined,
      githubRepo: githubRepo || undefined,
    };
    const res = await safeFetch("/api/commissions/execute", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: signal || undefined,
    });
    if (!res.ok) {
      const err = await res.json().catch(function () { return { error: res.statusText }; });
      throw new Error(err.error || "Execute failed");
    }
    return res.json();
  }

  async function apiGetAgentStatus(agentId) {
    const res = await safeFetch("/api/commissions/agent-status/" + encodeURIComponent(agentId), {
      method: "GET",
      headers: { Accept: "application/json" },
    });
    if (!res.ok) {
      const err = await res.json().catch(function () { return { error: res.statusText }; });
      const e = new Error(err.error || "Agent status failed");
      e.httpStatus = res.status;
      throw e;
    }
    return res.json();
  }

  async function apiNotifyPhaseComplete(payload) {
    const res = await safeFetch("/api/commissions/notify-complete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      throw new Error("notify complete failed");
    }
  }

  function clearCommissionPolling() {
    if (commissionPollTimer) {
      clearTimeout(commissionPollTimer);
      commissionPollTimer = null;
    }
    commissionPollToken = null;
  }

  function readAgentState(payload) {
    if (!payload || typeof payload !== "object") {
      return { terminal: false, success: false, label: "running" };
    }
    const statusValue =
      payload.status ||
      payload.state ||
      (payload.agent && (payload.agent.status || payload.agent.state)) ||
      "";
    const status = String(statusValue || "").toLowerCase();
    const hasError = !!(payload.error || payload.lastError || payload.failureReason);
    const finishedAt = payload.finishedAt || payload.completedAt || payload.endedAt;

    if (hasError || /(fail|error|cancel|timeout|aborted|stopped)/.test(status)) {
      return { terminal: true, success: false, label: status || "failed" };
    }
    if (/(complete|done|success|succeed|finished|ready)/.test(status)) {
      return { terminal: true, success: true, label: status };
    }
    if (finishedAt && !hasError) {
      return { terminal: true, success: true, label: "completed" };
    }
    return { terminal: false, success: false, label: status || "running" };
  }

  function startPhasePolling(phaseId, phaseName, agentId) {
    if (!activeCommission || !agentId || !phaseId) return;
    clearCommissionPolling();
    var attempt = 0;
    var delays = [3000, 5000, 8000, 12000, 20000];
    const pollKey =
      String(activeCommission.id || "") + ":" + String(phaseId) + ":" + String(agentId);
    commissionPollToken = pollKey;

    function tick() {
      if (!activeCommission || commissionPollToken !== pollKey) return;
      apiGetAgentStatus(agentId)
        .then(function (statusPayload) {
          if (!activeCommission || commissionPollToken !== pollKey) return;
          const s = readAgentState(statusPayload);
          if (!s.terminal) {
            attempt = Math.min(attempt + 1, delays.length - 1);
            commissionPollTimer = setTimeout(tick, delays[attempt]);
            return;
          }

          if (s.success) {
            activeCommission.phaseStatus[phaseId] = PHASE_STATUS.needsDebug;
            activeCommission.currentPhase = phaseId;
            setActiveCommission(activeCommission);
            renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
            showStatusEl("Phase " + (phaseName || phaseId) + " finished. Run checklist, then continue.", 7000);
            showLastResult({
              summary:
                "Phase " +
                (phaseName || phaseId) +
                " finished. Run Review Checklist to verify output, then continue.",
              agentMode: true,
              workspacePath: activeCommission.workspacePath || "",
            });
            apiNotifyPhaseComplete({
              commissionId: activeCommission.id,
              phaseId: phaseId,
              phaseName: phaseName || phaseId,
              typeName: activeCommission.typeName || "Website",
            }).catch(function () {});
          } else {
            activeCommission.phaseStatus[phaseId] = PHASE_STATUS.failed;
            setActiveCommission(activeCommission);
            renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
            showStatusEl(
              "Phase " +
                (phaseName || phaseId) +
                " failed. Check agent output, then retry or force-complete.",
              8000
            );
          }
          clearCommissionPolling();
        })
        .catch(function (err) {
          if (!activeCommission || commissionPollToken !== pollKey) return;
          if (err && err.httpStatus === 404) {
            activeCommission.phaseStatus[phaseId] = PHASE_STATUS.failed;
            setActiveCommission(activeCommission);
            renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
            showStatusEl(
              "Could not find this agent in Cursor (invalid or expired id). Check your API settings, then retry the phase.",
              10000
            );
            clearCommissionPolling();
            return;
          }
          attempt = Math.min(attempt + 1, delays.length - 1);
          commissionPollTimer = setTimeout(tick, delays[attempt]);
        });
    }

    commissionPollTimer = setTimeout(tick, 1500);
  }

  async function apiDebugPhase(commissionId, phaseId, workspacePath) {
    const res = await safeFetch("/api/commissions/debug", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ commissionId, phaseId, workspacePath }),
    });
    if (!res.ok) {
      const err = await res.json().catch(function () { return { error: res.statusText }; });
      throw new Error(err.error || "Debug failed");
    }
    return res.json();
  }

  function bindCommissionEvents() {
    const catSection = $("commCategorySection");
    const typeSection = $("commTypeSection");
    const formSection = $("commFormSection");
    const phaseSection = $("commPhaseSection");
    const previewInput = $("commPreviewUrl");
    const previewOpenBtn = $("commPreviewOpen");
    const previewCopyBtn = $("commPreviewCopy");
    const previewQrBtn = $("commPreviewQr");
    const previewQrImg = $("commPreviewQrImg");
    const mordecaiPublicUrlInput = $("commMordecaiPublicUrl");
    const mordecaiPublicUrlOpenBtn = $("commMordecaiOpen");
    const mordecaiPublicUrlCopyBtn = $("commMordecaiCopy");
    const mordecaiPublicUrlQrBtn = $("commMordecaiQr");
    const mordecaiPublicUrlQrImg = $("commMordecaiQrImg");
    const mordecaiPublicUrlHint = $("commMordecaiPublicUrlHint");
    const discoverCompanyInput = $("commDiscoverCompany");
    const discoverBtn = $("commDiscoverBtn");
    const discoverStatus = $("commDiscoverStatus");
    const discoverList = $("commDiscoverList");

    if (mordecaiPublicUrlInput) {
      var initialPhoneUrl = normalizePreviewUrl(loadMordecaiPublicUrl());
      mordecaiPublicUrlInput.value = initialPhoneUrl;
      updateMordecaiPublicUrlHint(mordecaiPublicUrlHint, initialPhoneUrl);
      mordecaiPublicUrlInput.addEventListener("change", function () {
        var normalized = normalizePreviewUrl(mordecaiPublicUrlInput.value || "");
        mordecaiPublicUrlInput.value = normalized;
        saveMordecaiPublicUrl(normalized);
        updateMordecaiPublicUrlHint(mordecaiPublicUrlHint, normalized);
      });
      mordecaiPublicUrlInput.addEventListener("blur", function () {
        var normalized = normalizePreviewUrl(mordecaiPublicUrlInput.value || "");
        mordecaiPublicUrlInput.value = normalized;
        saveMordecaiPublicUrl(normalized);
        updateMordecaiPublicUrlHint(mordecaiPublicUrlHint, normalized);
      });
    }
    if (mordecaiPublicUrlOpenBtn) {
      mordecaiPublicUrlOpenBtn.addEventListener("click", function () {
        var u = normalizePreviewUrl(mordecaiPublicUrlInput ? mordecaiPublicUrlInput.value : "");
        if (!u) {
          showStatusEl("Enter a Mordecai phone URL first (ngrok or tunnel).", 3000);
          return;
        }
        if (mordecaiPublicUrlInput) mordecaiPublicUrlInput.value = u;
        saveMordecaiPublicUrl(u);
        updateMordecaiPublicUrlHint(mordecaiPublicUrlHint, u);
        window.open(u, "_blank", "noopener");
      });
    }
    if (mordecaiPublicUrlCopyBtn) {
      mordecaiPublicUrlCopyBtn.addEventListener("click", function () {
        var u = normalizePreviewUrl(mordecaiPublicUrlInput ? mordecaiPublicUrlInput.value : "");
        if (!u) {
          showStatusEl("Enter a Mordecai phone URL first.", 3000);
          return;
        }
        if (mordecaiPublicUrlInput) mordecaiPublicUrlInput.value = u;
        saveMordecaiPublicUrl(u);
        updateMordecaiPublicUrlHint(mordecaiPublicUrlHint, u);
        navigator.clipboard.writeText(u).then(function () {
          showStatusEl("Mordecai phone URL copied.", 2500);
        }).catch(function () {
          showStatusEl("Could not copy. Select and copy manually.", 3000);
        });
      });
    }
    if (mordecaiPublicUrlQrBtn && mordecaiPublicUrlQrImg) {
      mordecaiPublicUrlQrBtn.addEventListener("click", function () {
        var u = normalizePreviewUrl(mordecaiPublicUrlInput ? mordecaiPublicUrlInput.value : "");
        if (!u) {
          showStatusEl("Enter a Mordecai phone URL first.", 3000);
          return;
        }
        if (mordecaiPublicUrlInput) mordecaiPublicUrlInput.value = u;
        saveMordecaiPublicUrl(u);
        updateMordecaiPublicUrlHint(mordecaiPublicUrlHint, u);
        mordecaiPublicUrlQrImg.src =
          "https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=" +
          encodeURIComponent(u);
        mordecaiPublicUrlQrImg.hidden = false;
      });
    }

    if (previewInput) {
      previewInput.value = loadPreviewUrl();
      previewInput.addEventListener("change", function () {
        savePreviewUrl(previewInput.value || "");
      });
    }
    if (previewOpenBtn) {
      previewOpenBtn.addEventListener("click", function () {
        var u = normalizePreviewUrl(previewInput ? previewInput.value : "");
        if (!u) {
          showStatusEl("Enter a preview URL first (LAN IP or tunnel).", 3000);
          return;
        }
        savePreviewUrl(u);
        window.open(u, "_blank", "noopener");
      });
    }
    if (previewCopyBtn) {
      previewCopyBtn.addEventListener("click", function () {
        var u = normalizePreviewUrl(previewInput ? previewInput.value : "");
        if (!u) {
          showStatusEl("Enter a preview URL first.", 3000);
          return;
        }
        savePreviewUrl(u);
        navigator.clipboard.writeText(u).then(function () {
          showStatusEl("Preview URL copied.", 2500);
        }).catch(function () {
          showStatusEl("Could not copy. Select and copy manually.", 3000);
        });
      });
    }
    if (previewQrBtn && previewQrImg) {
      previewQrBtn.addEventListener("click", function () {
        var u = normalizePreviewUrl(previewInput ? previewInput.value : "");
        if (!u) {
          showStatusEl("Enter a preview URL first.", 3000);
          return;
        }
        savePreviewUrl(u);
        previewQrImg.src =
          "https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=" +
          encodeURIComponent(u);
        previewQrImg.hidden = false;
      });
    }

    if (discoverBtn && discoverStatus && discoverList) {
      discoverBtn.addEventListener("click", function () {
        discoverStatus.textContent = "Scanning drives and folders...";
        discoverList.hidden = true;
        discoverList.innerHTML = "";
        var payload = {
          company: discoverCompanyInput ? (discoverCompanyInput.value || "").trim() : "",
          playbookId: activeCommission && activeCommission.playbookId ? activeCommission.playbookId : undefined,
          maxDepth: 4,
          maxResults: 40,
          maxTotalMs: 12000,
        };
        safeFetch("/api/commissions/discover", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        })
          .then(function (r) {
            return r.ok
              ? r.json()
              : r.json().then(function (d) {
                  throw new Error(d.error || "Discovery failed");
                });
          })
          .then(function (data) {
            var list = Array.isArray(data.discovered) ? data.discovered : [];
            var d = data.diagnostics || {};
            discoverStatus.textContent =
              "Found " +
              list.length +
              " candidates. Visited " +
              String(d.visitedDirs || 0) +
              " folders in " +
              String(d.elapsedMs || 0) +
              "ms.";
            if (list.length === 0) {
              discoverList.hidden = false;
              discoverList.innerHTML = "<p>No likely commission folders found.</p>";
              return;
            }
            discoverList.hidden = false;
            discoverList.innerHTML =
              "<ul>" +
              list
                .map(function (item) {
                  var reason = Array.isArray(item.reasons) ? item.reasons.join(", ") : "";
                  return (
                    "<li><code>" +
                    escapeHtml(item.path || "") +
                    "</code>" +
                    (reason
                      ? '<br><small>score ' +
                        String(item.score || 0) +
                        " — " +
                        escapeHtml(reason) +
                        "</small>"
                      : "") +
                    "</li>"
                  );
                })
                .join("") +
              "</ul>";
          })
          .catch(function (err) {
            discoverStatus.textContent = "Discovery error: " + (err.message || "Unknown");
          });
      });
    }

    var secretsToggle = $("commSecretsToggle");
    var secretsContent = $("commSecretsContent");
    if (secretsToggle && secretsContent) {
      secretsToggle.addEventListener("click", function () {
        var expanded = secretsToggle.getAttribute("aria-expanded") === "true";
        secretsToggle.setAttribute("aria-expanded", !expanded);
        secretsContent.hidden = expanded;
      });
    }
    var settingsInline = $("commSettingsInline");
    var settingsOverlay = $("settingsOverlay");
    if (settingsInline && settingsOverlay) {
      settingsInline.addEventListener("click", function () {
        settingsOverlay.hidden = false;
        safeFetch("/api/config/agents").then(function (r) { return r.json(); }).then(function (s) {
          var repoEl = $("agentConfigRepo");
          if (repoEl) repoEl.value = s.defaultRepo || "";
          var statusEl = $("agentConfigStatus");
          if (statusEl) {
            statusEl.textContent = s.configured ? "Configured. Commissions will launch agents." : "Add your Cursor API key and default repo (same as Cloud Agents).";
          }
        }).catch(function () {});
      });
    }

    document.querySelectorAll(".mordecai-tab").forEach(function (btn) {
      btn.addEventListener("click", function () {
        switchTab(btn.dataset.tab || "chat");
      });
    });

    document.querySelectorAll(".comm-card[data-category]").forEach(function (btn) {
      if (btn.disabled) return;
      btn.addEventListener("click", function () {
        const cat = btn.dataset.category;
        if (cat === "websites") {
          loadCommissionTypes().then(function (types) {
            const t = (types && types.websites && types.websites.types) ? types.websites.types : null;
            renderTypeCards(t);
          }).catch(function () {
            renderTypeCards(null);
          });
          showCommSection("commTypeSection");
        }
      });
    });

    var backToCat = $("commBackToCategory");
    if (backToCat) backToCat.addEventListener("click", function () { showCommSection("commCategorySection"); });

    var backToType = $("commBackToType");
    if (backToType) backToType.addEventListener("click", function () { showCommSection("commTypeSection"); });

    var backToForm = $("commBackToForm");
    if (backToForm) backToForm.addEventListener("click", function () {
      if (activeCommission) showCommSection("commFormSection");
    });

    var startOver = $("commStartOver");
    if (startOver) startOver.addEventListener("click", function () {
      if (!activeCommission) return;
      if (phaseAbortController) phaseAbortController.abort();
      clearCommissionPolling();
      var alsoDelete = confirm("Start new commission? OK = also delete project folder, Cancel = keep folder and go back.");
      function goBack() {
        activeCommission = null;
        setActiveCommission(null);
        showCommSection("commCategorySection");
      }
      if (alsoDelete) {
        apiDeleteWorkspace().catch(function () { /* ignore */ }).finally(goBack);
      } else {
        goBack();
      }
    });

    var deleteFolder = $("commDeleteFolder");
    if (deleteFolder) deleteFolder.addEventListener("click", function () {
      if (!activeCommission) return;
      if (phaseAbortController) phaseAbortController.abort();
      clearCommissionPolling();
      if (confirm("Delete the project folder from disk? This cannot be undone.")) {
        apiDeleteWorkspace()
          .then(function () { showStatusEl("Project folder deleted.", 3000); updateProjectPath(); })
          .catch(function (err) { showStatusEl("Delete failed: " + (err.message || "Unknown"), 4000); });
      }
    });

    var cancelPhase = $("commCancelPhase");
    if (cancelPhase) cancelPhase.addEventListener("click", function () {
      if (phaseAbortController) {
        phaseAbortController.abort();
        var pid = Object.keys(activeCommission.phaseStatus || {}).find(function (k) {
          return activeCommission.phaseStatus[k] === PHASE_STATUS.running;
        });
        if (pid) {
          activeCommission.phaseStatus[pid] = PHASE_STATUS.pending;
          setActiveCommission(activeCommission);
          renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
        }
      }
      clearCommissionPolling();
      setPhaseLoading(false);
    });

    document.addEventListener("click", function (e) {
      var typeCard = e.target.closest(".comm-card[data-playbook-id]");
      if (typeCard && typeSection && !typeSection.hidden) {
        var playbookId = typeCard.dataset.playbookId;
        var typeName = typeCard.dataset.typeName;
        activeCommission = {
          id: "comm_" + Date.now(),
          playbookId,
          typeName,
          currentPhase: null,
          phaseStatus: {},
          clientInfo: null,
          phases: null,
        };
        showCommSection("commFormSection");
        return;
      }

      var phaseBtn = e.target.closest(".comm-phase-btn");
      if (phaseBtn && activeCommission) {
        var item = phaseBtn.closest(".comm-phase-item");
        var phaseId = item ? item.dataset.phaseId : null;
        var action = phaseBtn.dataset.action;
        if (!phaseId) return;

        if (action === "start") {
          var phase = activeCommission.phases.find(function (p) { return p.id === phaseId; });
          activeCommission.phaseStatus[phaseId] = PHASE_STATUS.running;
          renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
          setPhaseLoading(true, phase ? phase.name : null);
          phaseAbortController = new AbortController();
          apiExecutePhase(
            activeCommission.id,
            phaseId,
            activeCommission.playbookId,
            activeCommission.clientInfo,
            activeCommission.cursorAgentId || undefined,
            activeCommission.clientInfo?.githubRepo || undefined,
            phaseAbortController.signal
          ).then(function (data) {
            if (data.cursorAgentId) activeCommission.cursorAgentId = data.cursorAgentId;
            if (data.workspacePath) activeCommission.workspacePath = data.workspacePath;
            activeCommission.currentPhase = phaseId;
            setActiveCommission(activeCommission);
            renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
            var msg = "";
            if (data.agentMode) {
              msg = "Phase queued. Waiting for Cursor agent to finish…";
              startPhasePolling(phaseId, phase ? phase.name : phaseId, activeCommission.cursorAgentId);
              showLastResult({
                agentMode: true,
                summary: data.summary || "Phase queued with the same commission agent.",
                workspacePath: data.workspacePath || "",
              });
            } else if (data.cursorMode) {
              activeCommission.phaseStatus[phaseId] = PHASE_STATUS.done;
              msg = "Copy instructions to Cursor Composer.";
              showLastResult(data);
            } else {
              activeCommission.phaseStatus[phaseId] = PHASE_STATUS.done;
              msg = data.summary;
              showLastResult(data);
            }
            setActiveCommission(activeCommission);
            renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
            showStatusEl(msg, 5000);
          }).catch(function (err) {
            if (err.name !== "AbortError") {
              activeCommission.phaseStatus[phaseId] = PHASE_STATUS.failed;
              setActiveCommission(activeCommission);
              renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
              var msg = err.message || "Unknown";
              if (msg === "Failed to fetch" || (err.name && err.name === "TypeError" && String(err).includes("fetch"))) {
                msg = "Could not reach server. Is Mordecai running? (npm start or node server.js)";
              }
              showStatusEl("Error: " + msg, 6000);
            }
          }).finally(function () {
            phaseAbortController = null;
            setPhaseLoading(false);
          });
        } else if (action === "debug") {
          var phase = activeCommission.phases.find(function (p) { return p.id === phaseId; });
          setPhaseLoading(true, phase ? "Review " + phase.name : null);
          phaseAbortController = new AbortController();
          (function () {
            var opts = { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ commissionId: activeCommission.id, phaseId, phaseName: phase ? phase.name : phaseId, cursorAgentId: activeCommission.cursorAgentId || undefined, workspacePath: activeCommission.workspacePath || undefined }), signal: phaseAbortController.signal };
            safeFetch("/api/commissions/debug", opts)
              .then(function (r) { return r.ok ? r.json() : r.json().then(function (d) { throw new Error(d.error || "Debug failed"); }); })
              .then(function (data) {
                activeCommission.phaseStatus[phaseId] = PHASE_STATUS.done;
                setActiveCommission(activeCommission);
                renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
                var msg = data.issues || data.summary || "Checklist complete";
                showStatusEl("Review: " + msg.slice(0, 120), 5000);
              })
              .catch(function (err) { if (err.name !== "AbortError") showStatusEl("Debug error: " + (err.message || "Unknown"), 4000); })
              .finally(function () { phaseAbortController = null; setPhaseLoading(false); });
          })();
        } else if (action === "force-done") {
          activeCommission.phaseStatus[phaseId] = PHASE_STATUS.done;
          setActiveCommission(activeCommission);
          renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
          showStatusEl("Marked complete manually. Continue when ready.", 5000);
          clearCommissionPolling();
        } else if (action === "continue") {
          var idx = activeCommission.phases.findIndex(function (p) { return p.id === phaseId; });
          if (idx >= 0 && activeCommission.phases[idx + 1]) {
            var nextPhase = activeCommission.phases[idx + 1];
            activeCommission.phaseStatus[nextPhase.id] = PHASE_STATUS.running;
            renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
            setPhaseLoading(true, nextPhase.name);
            phaseAbortController = new AbortController();
            apiExecutePhase(
              activeCommission.id,
              nextPhase.id,
              activeCommission.playbookId,
              activeCommission.clientInfo,
              activeCommission.cursorAgentId || undefined,
              activeCommission.clientInfo?.githubRepo || undefined,
              phaseAbortController.signal
            ).then(function (data) {
              if (data.cursorAgentId) activeCommission.cursorAgentId = data.cursorAgentId;
              if (data.workspacePath) activeCommission.workspacePath = data.workspacePath;
              activeCommission.currentPhase = nextPhase.id;
              setActiveCommission(activeCommission);
              renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
              var msg = "";
              if (data.agentMode) {
                msg = "Next phase queued. Waiting for Cursor agent to finish…";
                startPhasePolling(nextPhase.id, nextPhase.name, activeCommission.cursorAgentId);
                showLastResult({
                  agentMode: true,
                  summary: data.summary || "Follow-up sent to the same agent.",
                  workspacePath: data.workspacePath || "",
                });
              } else if (data.cursorMode) {
                activeCommission.phaseStatus[nextPhase.id] = PHASE_STATUS.done;
                msg = "Copy instructions to Cursor Composer.";
                showLastResult(data);
              } else {
                activeCommission.phaseStatus[nextPhase.id] = PHASE_STATUS.done;
                msg = data.summary;
                showLastResult(data);
              }
              setActiveCommission(activeCommission);
              renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
              showStatusEl(msg, 5000);
            }).catch(function (err) {
              if (err.name !== "AbortError") {
                activeCommission.phaseStatus[nextPhase.id] = PHASE_STATUS.failed;
                setActiveCommission(activeCommission);
                renderPhaseList(activeCommission.phases, activeCommission.phaseStatus);
                var msg = err.message || "Unknown";
                if (msg === "Failed to fetch" || (err.name && err.name === "TypeError" && String(err).includes("fetch"))) {
                  msg = "Could not reach server. Is Mordecai running? (npm start or node server.js)";
                }
                showStatusEl("Error: " + msg, 6000);
              }
            }).finally(function () {
              phaseAbortController = null;
              setPhaseLoading(false);
            });
          }
        }
      }
    });

    var form = $("commClientForm");
    if (form) {
      form.addEventListener("submit", function (e) {
        e.preventDefault();
        activeCommission.clientInfo = {
          company: ($("commCompany") || {}).value || "",
          description: ($("commDescription") || {}).value || "",
          cta: ($("commCta") || {}).value || "",
          pageCount: ($("commPageCount") || {}).value || "",
          custom: ($("commCustom") || {}).value || "",
          githubRepo: ($("commGithubRepo") || {}).value || "",
        };
        activeCommission.cursorAgentId = null;
        clearCommissionPolling();
        loadPlaybook(activeCommission.playbookId).then(function (playbook) {
          activeCommission.phases = playbook.phases || [];
          activeCommission.phaseStatus = {};
          setActiveCommission(activeCommission);
          renderPhaseList(activeCommission.phases);
          showCommSection("commPhaseSection");
        }).catch(function (err) {
          showStatusEl("Could not load playbook: " + (err.message || "Unknown"), 4000);
        });
      });
    }

    var refInput = $("commReferenceImage");
    var refPreview = $("commImagePreview");
    var refClear = $("commClearImage");
    if (refInput) {
      refInput.addEventListener("change", function () {
        var file = refInput.files && refInput.files[0];
        referenceImageData = null;
        if (refPreview) { refPreview.hidden = true; refPreview.innerHTML = ""; }
        if (refClear) refClear.hidden = true;
        if (!file || !file.type.startsWith("image/")) return;
        var reader = new FileReader();
        reader.onload = function () {
          var img = new Image();
          img.onload = function () {
            referenceImageData = {
              data: reader.result,
              dimension: { width: img.naturalWidth, height: img.naturalHeight },
            };
            if (refPreview) {
              refPreview.innerHTML = "<img src=\"" + escapeAttr(reader.result) + "\" alt=\"Reference\" />";
              refPreview.hidden = false;
            }
            if (refClear) refClear.hidden = false;
          };
          img.src = reader.result;
        };
        reader.readAsDataURL(file);
      });
    }
    if (refClear) {
      refClear.addEventListener("click", function () {
        referenceImageData = null;
        if (refInput) refInput.value = "";
        if (refPreview) { refPreview.hidden = true; refPreview.innerHTML = ""; }
        refClear.hidden = true;
      });
    }
  }

  function bindEvents() {
    const newBtn = $("newChatBtn");
    const sendBtn = $("sendBtn");
    const input = $("mordecaiInput");
    const micBtn = $("micBtn");
    const keepAllBtn = $("keepAllBtn");
    const undoAllBtn = $("undoAllBtn");
    const modeAsk = $("modeAsk");
    const modePlan = $("modePlan");

    if (newBtn) {
      newBtn.addEventListener("click", function () {
        currentChatId = createChat();
        try {
          localStorage.setItem(STORAGE_CURRENT, currentChatId);
        } catch (_) {}
        renderMessages();
        renderChatList();
        setPendingChanges([]);
      });
    }

    if (sendBtn) sendBtn.addEventListener("click", sendMessage);

    if (input) {
      input.addEventListener("keydown", function (e) {
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault();
          sendMessage();
        }
      });
      input.addEventListener("input", function () {
        input.style.height = "auto";
        input.style.height = Math.min(input.scrollHeight, 120) + "px";
      });
    }

    if (micBtn) micBtn.addEventListener("click", toggleMic);

    if (keepAllBtn) keepAllBtn.addEventListener("click", keepAll);
    if (undoAllBtn) undoAllBtn.addEventListener("click", undoAll);

    const screenShareBtn = $("screenShareBtn");
    const stopScreenBtn = $("stopScreenBtn");
    if (screenShareBtn) screenShareBtn.addEventListener("click", startScreenShare);
    if (stopScreenBtn) stopScreenBtn.addEventListener("click", stopScreenShare);

    if (modeAsk) {
      modeAsk.addEventListener("click", function () {
        if (modePlan) modePlan.classList.remove("active");
        modeAsk.classList.add("active");
      });
    }
    if (modePlan) {
      modePlan.addEventListener("click", function () {
        if (modeAsk) modeAsk.classList.remove("active");
        modePlan.classList.add("active");
      });
    }

    const list = $("chatList");
    if (list) {
      list.addEventListener("click", function (e) {
        const btn = e.target.closest(".mordecai-chat-item");
        if (!btn || !btn.dataset.id) return;
        currentChatId = btn.dataset.id;
        try {
          localStorage.setItem(STORAGE_CURRENT, currentChatId);
        } catch (_) {}
        renderMessages();
        renderChatList();
        setPendingChanges([]);
      });
    }

    var settingsBtn = $("settingsBtn");
    var settingsOverlay = $("settingsOverlay");
    var settingsCloseBtn = $("settingsCloseBtn");
    var agentConfigForm = $("agentConfigForm");
    var agentConfigStatus = $("agentConfigStatus");
    var launchMetricsRefreshBtn = $("launchMetricsRefreshBtn");
    var launchMetricsOutput = $("launchMetricsOutput");
    if (settingsBtn && settingsOverlay) {
      settingsBtn.addEventListener("click", function () {
        settingsOverlay.hidden = false;
        var bridgeEl = $("agentConfigBridgeSecret");
        var adminEl = $("agentConfigAdminToken");
        try {
          if (bridgeEl) bridgeEl.value = localStorage.getItem(STORAGE_BRIDGE_SECRET) || "";
          if (adminEl) adminEl.value = localStorage.getItem(STORAGE_ADMIN_TOKEN) || "";
        } catch (_) {}
        safeFetch("/api/config/agents").then(function (r) { return r.json(); }).then(function (s) {
          var repoEl = $("agentConfigRepo");
          if (repoEl) repoEl.value = s.defaultRepo || "";
          if (agentConfigStatus) {
            agentConfigStatus.textContent = s.configured ? "Configured. Commissions will launch agents." : "Add your Cursor API key and default repo (same as Cloud Agents).";
          }
        }).catch(function () {
          if (agentConfigStatus) agentConfigStatus.textContent = "";
        });
        if (launchMetricsRefreshBtn) {
          launchMetricsRefreshBtn.click();
        }
      });
    }
    if (settingsCloseBtn && settingsOverlay) {
      settingsCloseBtn.addEventListener("click", function () { settingsOverlay.hidden = true; });
    }
    if (agentConfigForm) {
      agentConfigForm.addEventListener("submit", function (e) {
        e.preventDefault();
        var keyEl = $("agentConfigKey");
        var repoEl = $("agentConfigRepo");
        var bridgeEl = $("agentConfigBridgeSecret");
        var adminEl = $("agentConfigAdminToken");
        var key = keyEl ? keyEl.value : "";
        var repo = repoEl ? repoEl.value.trim() : "";
        var bridgeSecret = bridgeEl ? (bridgeEl.value || "").trim() : "";
        var adminToken = adminEl ? (adminEl.value || "").trim() : "";
        try {
          localStorage.setItem(STORAGE_BRIDGE_SECRET, bridgeSecret);
          localStorage.setItem(STORAGE_ADMIN_TOKEN, adminToken);
        } catch (_) {}
        var extraHeaders = {};
        if (adminToken) extraHeaders["X-Admin-Token"] = adminToken;
        if (bridgeSecret) extraHeaders["X-Bridge-Secret"] = bridgeSecret;
        safeFetch("/api/config/agents", {
          method: "POST",
          headers: mergeHeaders(
            { "Content-Type": "application/json" },
            extraHeaders
          ),
          body: JSON.stringify({ cursorApiKey: key, defaultRepo: repo }),
        }).then(function (r) {
          if (!r.ok) return r.json().then(function (d) { throw new Error(d.error || "Save failed"); });
          if (agentConfigStatus) agentConfigStatus.textContent = "Saved. You can now use agent mode in Commissions.";
          if (keyEl) keyEl.value = "";
          showStatusEl("Settings saved.", 3000);
        }).catch(function (err) {
          if (agentConfigStatus) agentConfigStatus.textContent = "Error: " + (err.message || "Save failed");
        });
      });
    }
    if (launchMetricsRefreshBtn && launchMetricsOutput) {
      launchMetricsRefreshBtn.addEventListener("click", function () {
        launchMetricsOutput.textContent = "Loading runtime metrics…";
        safeFetch("/api/runtime/status")
          .then(function (r) {
            return r.ok
              ? r.json()
              : r.json().then(function (d) { throw new Error(d.error || "Metrics request failed"); });
          })
          .then(function (data) {
            var metrics = data && data.launchRoutingMetrics ? data.launchRoutingMetrics : {};
            var tunnel = data && data.state && data.state.tunnel ? data.state.tunnel : {};
            launchMetricsOutput.textContent = JSON.stringify(
              {
                at: new Date().toISOString(),
                tunnelRunning: !!tunnel.running,
                tunnelPublicUrl: tunnel.publicUrl || "",
                launchRoutingMetrics: metrics,
              },
              null,
              2
            );
          })
          .catch(function (err) {
            launchMetricsOutput.textContent = "Failed to load metrics: " + (err.message || "Unknown");
          });
      });
    }
  }

  function init() {
    var loadingEl = document.getElementById("commPhaseLoading");
    if (loadingEl) loadingEl.hidden = true;
    if (typeof window !== "undefined") {
      window.addEventListener("error", function (e) {
        var url = (e.target && (e.target.src || e.target.href)) || e.filename || e.message || "";
        if (url && url.indexOf("\\") >= 0) {
          console.error("[Mordecai] Invalid path fetch bug detected (backslash in URL):", url);
        }
      }, true);
      window.addEventListener("unhandledrejection", function (e) {
        var s = String(e.reason || "");
        if (s.indexOf("\\") >= 0 || s.indexOf("permissions") >= 0 && s.indexOf("workspace-path") >= 0) {
          console.error("[Mordecai] Blocked invalid path in promise:", s.slice(0, 100));
        }
      });
    }
    loadChats();
    activeCommission = getActiveCommission();
    if (activeCommission && activeCommission.phaseStatus) {
      var invalid = false;
      Object.keys(activeCommission.phaseStatus).forEach(function (k) {
        var v = activeCommission.phaseStatus[k];
        if (
          v !== PHASE_STATUS.pending &&
          v !== PHASE_STATUS.running &&
          v !== PHASE_STATUS.needsDebug &&
          v !== PHASE_STATUS.done &&
          v !== PHASE_STATUS.failed
        ) {
          invalid = true;
          activeCommission.phaseStatus[k] = PHASE_STATUS.pending;
        }
        if (v === "in-progress") {
          activeCommission.phaseStatus[k] = PHASE_STATUS.running;
          invalid = true;
        }
      });
      if (invalid) setActiveCommission(activeCommission);
    }
    try {
      currentChatId = localStorage.getItem(STORAGE_CURRENT);
    } catch (_) {}
    if (!currentChatId || !chats[currentChatId]) {
      currentChatId = createChat();
    }
    setPhaseLoading(false); /* ensure loading bar never starts visible (e.g. after reload) */
    initMic();
    bindEvents();
    bindCommissionEvents();
    renderMessages();
    renderChatList();
    setPendingChanges([]);
    if (typeof console !== "undefined" && console.log) {
      console.log("Mordecai ready – invalid path fetch bug fixed (no pi\\permissions attempts)");
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
