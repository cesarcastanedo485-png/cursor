/**
 * Mordecai's Maximus — Remote control Cursor AI from your phone
 * Express server: chat API, push subscribe, GitHub PR alerts, desktop bridge webhook
 */
import express from "express";
import dotenv from "dotenv";
import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import {
  sendPush,
  getVapidPublicKey,
  addSubscription,
  removeSubscription,
} from "./pushNotifications.js";
import {
  loadPlaybook,
  getPhaseInstructions,
  getWorkspaceForCommission,
} from "./lib/commissionRunner.js";
import {
  isConfigured as cursorAgentsConfigured,
  launchAgent,
  sendFollowup,
  getAgentStatus,
} from "./lib/cursorAgents.js";
import {
  attachSseClient,
  registerDeviceToken,
  updateDeviceTokenPrefs,
  getDeviceTokenPrefs,
  watchAgentForDevice,
} from "./lib/agentEvents.js";
import { getAgentConfigStatus, saveAgentConfig } from "./lib/agentConfig.js";
import {
  createTask,
  pollTask,
  completeTask,
  errorTask,
  setTaskStatus,
  getTaskStats,
} from "./lib/bridgeTasks.js";
import { discoverCommissionFolders } from "./lib/commissionDiscovery.js";
import {
  getRuntimeState,
  startTunnel,
  stopTunnel,
  getTunnelPublicUrl,
} from "./lib/runtimeAutomation.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, ".env") });

const PORT = process.env.PORT || 3000;
const STATIC_ROOT = path.join(__dirname, "public");
const NODE_ENV = String(process.env.NODE_ENV || "development").toLowerCase();
const IS_PRODUCTION = NODE_ENV === "production";
const BRIDGE_SECRET = String(process.env.MORDECAI_BRIDGE_SECRET || "").trim();
const ADMIN_TOKEN = String(process.env.MORDECAI_ADMIN_TOKEN || "").trim();
const FCM_WEBHOOK_SECRET = String(process.env.MORDECAI_FCM_WEBHOOK_SECRET || "").trim();
const CORS_ALLOW_ORIGINS = String(process.env.CORS_ALLOW_ORIGINS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);
const launchRoutingMetrics = {
  bridgeAttempted: 0,
  bridgeAccepted: 0,
  bridgeDeduped: 0,
  bridgeReadinessChecks: 0,
  bridgeReadyTrue: 0,
  cloudFallbacks: 0,
  cloudFallbackReasons: {},
};

const app = express();
app.disable("x-powered-by");
app.use(helmet({ contentSecurityPolicy: false }));
app.use(
  express.json({
    limit: process.env.API_BODY_LIMIT || "512kb",
  })
);

if (IS_PRODUCTION && !BRIDGE_SECRET) {
  throw new Error(
    "MORDECAI_BRIDGE_SECRET is required in production."
  );
}

if (IS_PRODUCTION && !ADMIN_TOKEN) {
  throw new Error(
    "MORDECAI_ADMIN_TOKEN is required in production."
  );
}

function corsMiddleware(req, res, next) {
  const origin = String(req.headers.origin || "").trim();
  if (!origin) return next();
  if (CORS_ALLOW_ORIGINS.length === 0 || CORS_ALLOW_ORIGINS.includes(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
    res.setHeader(
      "Access-Control-Allow-Headers",
      "Content-Type, X-Bridge-Secret, X-Admin-Token, X-Mordecai-Request-Id, X-Fcm-Webhook-Secret, X-Notification-Preferences"
    );
    res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    if (req.method === "OPTIONS") return res.status(204).send("");
    return next();
  }
  return res.status(403).json({ error: "Origin not allowed" });
}
app.use(corsMiddleware);
app.use((req, res, next) => {
  const rid = requestId(req);
  req.mordecaiRequestId = rid;
  res.setHeader("X-Mordecai-Request-Id", rid);
  const started = Date.now();
  res.on("finish", () => {
    logEvent("info", "http_request", {
      rid,
      method: req.method,
      path: req.originalUrl || req.url,
      status: res.statusCode,
      elapsedMs: Date.now() - started,
      ip: req.ip,
    });
  });
  next();
});

const sensitiveLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number(process.env.API_RATE_LIMIT_PER_MIN || 90),
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests" },
});
const pollLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number(process.env.POLL_RATE_LIMIT_PER_MIN || 180),
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many poll requests" },
});

function requestId(req) {
  const id = String(
    req.headers["x-mordecai-request-id"] || `req_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  );
  return id.slice(0, 80);
}

function logEvent(level, event, meta = {}) {
  const payload = {
    at: new Date().toISOString(),
    level,
    event,
    ...meta,
  };
  const text = JSON.stringify(payload);
  if (level === "error") console.error(text);
  else if (level === "warn") console.warn(text);
  else console.log(text);
}

function requireBridgeSecret(req, res) {
  if (!BRIDGE_SECRET) {
    if (IS_PRODUCTION) {
      res.status(503).json({ error: "Bridge secret not configured" });
      return false;
    }
    return true;
  }
  if (req.headers["x-bridge-secret"] !== BRIDGE_SECRET) {
    res.status(401).json({ error: "Unauthorized" });
    return false;
  }
  return true;
}

function requireAdminToken(req, res) {
  if (!ADMIN_TOKEN) {
    if (IS_PRODUCTION) {
      res.status(503).json({ error: "Admin token not configured" });
      return false;
    }
    return true;
  }
  const token = String(req.headers["x-admin-token"] || "").trim();
  if (token !== ADMIN_TOKEN) {
    res.status(401).json({ error: "Unauthorized" });
    return false;
  }
  return true;
}

async function sendFcmEvent({
  token,
  title,
  message,
  type,
  agentId,
  eventId,
  messagePreview,
  threadId,
}) {
  const webhook = process.env.MORDECAI_FCM_WEBHOOK;
  if (!webhook || !token) return;
  try {
    const rid = `fcm_${Date.now()}`;
    await fetch(webhook, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Mordecai-Request-Id": rid,
        ...(FCM_WEBHOOK_SECRET
          ? { "X-Fcm-Webhook-Secret": FCM_WEBHOOK_SECRET }
          : {}),
      },
      body: JSON.stringify({
        token,
        title,
        message,
        type,
        agentId,
        id: agentId,
        eventId,
        messagePreview,
        threadId,
      }),
    });
  } catch (e) {
    logEvent("warn", "fcm_webhook_failed", { error: e.message });
  }
}

// Health check
app.get("/health", (_req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({ ok: true, uptime: process.uptime() });
});

// Runtime config for client-side phone/tunnel URL defaults.
app.get("/js/runtime-config.js", (_req, res) => {
  res.setHeader("Content-Type", "application/javascript; charset=utf-8");
  res.setHeader("Cache-Control", "no-store, max-age=0");
  const publicUrl =
    getTunnelPublicUrl() || process.env.MORDECAI_PUBLIC_URL || "";
  res.send(
    "window.__MORDECAI_PUBLIC_URL__ = " +
      JSON.stringify(publicUrl) +
      ";\n" +
      "window.__MORDECAI_HARDENED_MODE__ = " +
      JSON.stringify(IS_PRODUCTION) +
      ";\n"
  );
});

// Static
app.use(express.static(STATIC_ROOT));

// Manifest and SW — no cache
app.get("/manifest.json", (req, res) => {
  res.setHeader("Cache-Control", "no-cache, max-age=0");
  res.sendFile(path.join(STATIC_ROOT, "manifest.json"));
});
app.get("/sw.js", (req, res) => {
  res.setHeader("Cache-Control", "no-cache, max-age=0");
  res.sendFile(path.join(STATIC_ROOT, "sw.js"));
});

// Push: get VAPID public key
app.get("/api/push/vapid", (_req, res) => {
  const key = getVapidPublicKey();
  if (!key) return res.status(503).json({ error: "Push not configured" });
  res.json({ publicKey: key });
});

// Push: subscribe (save subscription)
app.post("/api/push/subscribe", sensitiveLimiter, express.json(), (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const sub = req.body;
  if (!sub || !sub.endpoint) {
    return res.status(400).json({ error: "Invalid subscription" });
  }
  addSubscription(sub);
  res.json({ ok: true });
});

// Push: unsubscribe
app.post("/api/push/unsubscribe", sensitiveLimiter, express.json(), (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const { endpoint } = req.body || {};
  if (endpoint) removeSubscription(endpoint);
  res.json({ ok: true });
});

// Push: send test notification (verify push works when app is closed)
app.post("/api/push/test", sensitiveLimiter, async (_req, res) => {
  if (!requireBridgeSecret(_req, res)) return;
  try {
    await sendPush(
      "Test notification",
      "If you see this when the app was closed, push is working!",
      "test"
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Mobile notification registration + preferences (FCM fanout settings)
app.post("/api/notifications/register-device", sensitiveLimiter, express.json(), async (req, res) => {
  try {
    if (!requireBridgeSecret(req, res)) return;
    const { token, preferences } = req.body || {};
    if (!token || typeof token !== "string") {
      return res.status(400).json({ error: "token required" });
    }
    const prefs = await registerDeviceToken({ token, preferences });
    res.json({ ok: true, preferences: prefs });
  } catch (err) {
    res.status(500).json({ error: err.message || "register failed" });
  }
});

app.post("/api/notifications/preferences", sensitiveLimiter, express.json(), async (req, res) => {
  try {
    if (!requireBridgeSecret(req, res)) return;
    const { token, preferences } = req.body || {};
    if (!token || typeof token !== "string") {
      return res.status(400).json({ error: "token required" });
    }
    const prefs = await updateDeviceTokenPrefs({ token, preferences });
    res.json({ ok: true, preferences: prefs });
  } catch (err) {
    res.status(500).json({ error: err.message || "preferences update failed" });
  }
});

app.get("/api/notifications/preferences", sensitiveLimiter, async (req, res) => {
  try {
    if (!requireBridgeSecret(req, res)) return;
    const token = String(req.query.token || "").trim();
    if (!token) return res.status(400).json({ error: "token required" });
    const preferences = await getDeviceTokenPrefs(token);
    res.json({ ok: true, preferences });
  } catch (err) {
    res.status(500).json({ error: err.message || "preferences fetch failed" });
  }
});

// Mordecai chat — planning and notes (building done by Cursor)
app.post("/api/mordecai/chat", express.json(), async (req, res) => {
  try {
    const body = req.body || {};
    const messages = Array.isArray(body.messages) ? body.messages : [];
    const lastUser = messages.filter((m) => m.role === "user").pop();
    const lastText = lastUser?.content || "";

    return res.json({
      content:
        "Use Cursor (Composer) to build your sites. This chat is for planning and notes. " +
        "Open your commission workspace in Cursor and ask: \"Build Phase X for this commission.\" " +
        "The phases and instructions are in the Commissions tab.",
      code: null,
      changes: [],
    });
  } catch (err) {
    console.error("Mordechaius Maximus chat error:", err);
    res.status(500).json({ error: err.message || "Chat failed" });
  }
});

// Agent config — same as Cloud Agents (configure in app, no .env)
app.get("/api/config/agents", async (_req, res) => {
  if (!requireAdminToken(_req, res)) return;
  try {
    const status = await getAgentConfigStatus();
    res.json(status);
  } catch (err) {
    res.status(500).json({ configured: false, hasKey: false, hasRepo: false });
  }
});
app.post("/api/config/agents", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireAdminToken(req, res)) return;
  try {
    const { cursorApiKey, defaultRepo } = req.body || {};
    await saveAgentConfig({ cursorApiKey, defaultRepo });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Commissions: launch agent (Phase 1) or followup (Phase 2+) — one agent per commission
app.post("/api/commissions/execute", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const { commissionId, phaseId, playbookId, clientInfo, cursorAgentId, referenceImage, githubRepo } =
      req.body || {};
    if (!playbookId || !phaseId) {
      return res.status(400).json({ error: "playbookId and phaseId required" });
    }

    const playbook = await loadPlaybook(playbookId);
    const { phase, instructions, techStack } = getPhaseInstructions(playbook, phaseId, clientInfo);
    const workDir = getWorkspaceForCommission(commissionId, clientInfo, playbook);
    try {
      await fs.mkdir(workDir, { recursive: true });
    } catch (err) {
      console.error("[Commissions] mkdir workspace:", workDir, err);
    }

    if (await cursorAgentsConfigured()) {
      if (cursorAgentId) {
        await sendFollowup({ agentId: cursorAgentId, instructions, referenceImage });
        res.json({
          success: true,
          agentMode: true,
          cursorAgentId,
          workspacePath: workDir,
          phase: { id: phase.id, name: phase.name },
          summary: `Phase ${phase.name} sent to agent. Same agent is working on it.`,
        });
      } else {
        const agent = await launchAgent({
          instructions,
          clientInfo,
          referenceImage,
          commissionId,
          playbookId,
          repoOverride: githubRepo,
        });
        res.json({
          success: true,
          agentMode: true,
          cursorAgentId: agent.id,
          workspacePath: workDir,
          phase: { id: phase.id, name: phase.name },
          summary: `Phase ${phase.name} — agent launched. When done, click Start Next Phase.`,
        });
      }
    } else {
      res.json({
        success: true,
        cursorMode: true,
        phase: { id: phase.id, name: phase.name },
        instructions,
        techStack,
        workspacePath: workDir,
        summary: `Phase ${phase.name}: configure Cursor API key and repo in Settings (same as Cloud Agents).`,
      });
    }
  } catch (err) {
    console.error("[Commissions] execute error:", err);
    res.status(500).json({ error: err.message || "Execute failed" });
  }
});

// Commissions: poll agent status
app.get("/api/commissions/agent-status/:agentId", async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const { agentId } = req.params;
    if (!agentId) return res.status(400).json({ error: "agentId required" });
    const status = await getAgentStatus(agentId);
    if (!status) return res.status(404).json({ error: "Agent not found" });
    res.json(status);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Agent realtime watch lease for push fallback.
app.post("/api/agents/watch", sensitiveLimiter, express.json(), async (req, res) => {
  try {
    if (!requireBridgeSecret(req, res)) return;
    const { agentId, token, preferences } = req.body || {};
    if (!agentId || !token) {
      return res.status(400).json({ error: "agentId and token required" });
    }
    await registerDeviceToken({ token, preferences });
    watchAgentForDevice({ agentId, token, sendFcmEvent });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message || "watch failed" });
  }
});

// Agent realtime stream (SSE) for in-app updates without manual refresh.
app.get("/api/agents/:agentId/stream", async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const agentId = String(req.params.agentId || "").trim();
  if (!agentId) return res.status(400).json({ error: "agentId required" });

  const token = String(req.query.token || "").trim();
  if (token) {
    const prefFromHeader = req.headers["x-notification-preferences"];
    let parsedPrefs = null;
    if (typeof prefFromHeader === "string" && prefFromHeader.trim()) {
      try {
        parsedPrefs = JSON.parse(prefFromHeader);
      } catch (_) {}
    }
    try {
      await registerDeviceToken({ token, preferences: parsedPrefs || undefined });
    } catch (_) {}
  }

  res.status(200);
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache, no-transform");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders?.();

  const detach = attachSseClient({
    agentId,
    res,
    sendFcmEvent,
    token: token || null,
  });
  const keepAlive = setInterval(() => {
    try {
      res.write(": ping\n\n");
    } catch (_) {}
  }, 25000);

  req.on("close", () => {
    clearInterval(keepAlive);
    detach();
    res.end();
  });
});

// Commissions: debug — instructions for Cursor to review
app.post("/api/commissions/debug", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const { phaseName, workspacePath } = req.body || {};
    res.json({
      summary: "Review checklist completed. Marked phase as ready for next step.",
      issues:
        "Run this checklist in Cursor: " +
        "\"Review phase output for broken links, runtime errors, missing files, responsive issues, and accessibility basics.\" " +
        (phaseName ? `Phase: ${phaseName}. ` : "") +
        (workspacePath ? `Workspace: ${workspacePath}.` : ""),
      suggestions: [],
    });
  } catch (err) {
    console.error("[Commissions] debug error:", err);
    res.status(500).json({ error: err.message || "Debug failed" });
  }
});

// Commissions: push notification when a phase reaches terminal completion.
app.post("/api/commissions/notify-complete", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const { commissionId, phaseId, phaseName, typeName } = req.body || {};
    if (!commissionId || !phaseId) {
      return res.status(400).json({ error: "commissionId and phaseId required" });
    }
    const title = "Commission phase done";
    const body =
      `${typeName || "Website"} • ${phaseName || phaseId} finished. ` +
      "Open Commissions to review and continue.";
    await sendPush(title, body, `commission-${commissionId}-${phaseId}`);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message || "notify failed" });
  }
});

// Commissions: health check (lightweight connectivity test)
app.get("/api/commissions/health", (_req, res) => {
  res.json({ ok: true });
});

// Commissions: get workspace path (for display)
app.post("/api/commissions/workspace-path", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const { commissionId, clientInfo, playbookId } = req.body || {};
    if (!playbookId) return res.json({ path: null });
    const playbook = await loadPlaybook(playbookId);
    const p = getWorkspaceForCommission(commissionId, clientInfo, playbook);
    res.json({ path: p });
  } catch (err) {
    res.json({ path: null });
  }
});

// Commissions: delete workspace (start over)
app.post("/api/commissions/delete-workspace", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const { commissionId, clientInfo, playbookId } = req.body || {};
    const playbook = await loadPlaybook(playbookId || "ecommerce-website").catch(() => null);
    const workDir = getWorkspaceForCommission(commissionId, clientInfo, playbook);
    const fs = await import("fs/promises");
    await fs.rm(workDir, { recursive: true, force: true });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message || "Delete failed" });
  }
});

// Desktop bridge task queue — phone submits, desktop polls and completes
app.post("/api/bridge/tasks", sensitiveLimiter, express.json(), (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const { prompt, repoUrl, branch, intent, fcmToken, idempotencyKey } = req.body || {};
  launchRoutingMetrics.bridgeAttempted += 1;
  if (!prompt || typeof prompt !== "string") {
    return res.status(400).json({ error: "prompt required" });
  }
  const created = createTask({
    prompt: prompt.trim(),
    repoUrl: repoUrl || "",
    branch: branch || "",
    intent: intent || "normal",
    fcmToken: fcmToken || null,
    idempotencyKey: idempotencyKey || null,
  });
  if (created.deduped) {
    launchRoutingMetrics.bridgeDeduped += 1;
  } else {
    launchRoutingMetrics.bridgeAccepted += 1;
  }
  res.json({ taskId: created.taskId, status: created.status, deduped: !!created.deduped });
});

app.get("/api/bridge/ready", sensitiveLimiter, (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  launchRoutingMetrics.bridgeReadinessChecks += 1;
  const stats = getTaskStats();
  const ready = true;
  if (ready) launchRoutingMetrics.bridgeReadyTrue += 1;
  res.json({
    ok: true,
    ready,
    queue: stats,
    checkedAt: new Date().toISOString(),
  });
});

app.post("/api/bridge/tasks/:taskId/status", sensitiveLimiter, express.json(), (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const { taskId } = req.params;
  const { status, message } = req.body || {};
  const updated = setTaskStatus(taskId, { status, message });
  if (!updated) {
    return res.status(404).json({ error: "Task not found or invalid status" });
  }
  res.json({ ok: true, task: updated });
});

app.post("/api/bridge/launch-telemetry", sensitiveLimiter, express.json(), (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const { path, fallbackReason } = req.body || {};
  const routePath = String(path || "").trim().toLowerCase();
  if (routePath === "cloud_fallback") {
    launchRoutingMetrics.cloudFallbacks += 1;
    const reason = String(fallbackReason || "unknown").trim().toLowerCase() || "unknown";
    launchRoutingMetrics.cloudFallbackReasons[reason] =
      (launchRoutingMetrics.cloudFallbackReasons[reason] || 0) + 1;
  }
  res.json({ ok: true });
});

app.get("/api/bridge/tasks/poll", pollLimiter, (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const deviceId = (req.query.deviceId || "").trim();
  if (!deviceId) {
    return res.status(400).json({ error: "deviceId required" });
  }
  const task = pollTask(deviceId);
  if (!task) {
    return res.status(204).send();
  }
  res.json(task);
});

app.post("/api/bridge/tasks/:taskId/complete", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const { taskId } = req.params;
  const { message } = req.body || {};
  const task = completeTask(taskId, { message });
  if (!task) {
    return res.status(404).json({ error: "Task not found" });
  }
  const pushMessage = message || "Desktop agent finished.";
  if (task.fcmToken) {
    await sendFcmEvent({
      token: task.fcmToken,
      title: "Agent finished",
      message: pushMessage,
      type: "agent_finished",
      agentId: taskId,
      eventId: `bridge-complete-${taskId}-${Date.now()}`,
      messagePreview: pushMessage.slice(0, 180),
      threadId: taskId,
    });
  }
  await sendPush("Agent done", pushMessage, "agent-done");
  res.json({ ok: true });
});

app.post("/api/bridge/tasks/:taskId/error", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const { taskId } = req.params;
  const { message } = req.body || {};
  const task = errorTask(taskId, { message });
  if (!task) {
    return res.status(404).json({ error: "Task not found" });
  }
  const pushMessage = message || "Desktop agent encountered an error.";
  if (task.fcmToken) {
    await sendFcmEvent({
      token: task.fcmToken,
      title: "Agent expired",
      message: pushMessage,
      type: "agent_expired",
      agentId: taskId,
      eventId: `bridge-error-${taskId}-${Date.now()}`,
      messagePreview: pushMessage.slice(0, 180),
      threadId: taskId,
    });
  }
  await sendPush("Agent error", pushMessage, "agent-error");
  res.json({ ok: true });
});

// Desktop bridge webhook — agent complete / agent error from Cursor companion
app.post(
  "/api/mordecai/events",
  sensitiveLimiter,
  express.json(),
  async (req, res) => {
    if (!requireBridgeSecret(req, res)) return;
    const { type, message } = req.body || {};
    if (type === "agent_complete") {
      await sendPush(
        "Agent done",
        message || "Desktop agent finished.",
        "agent-done"
      );
    } else if (type === "agent_error") {
      await sendPush(
        "Agent error",
        message || "Desktop agent encountered an error.",
        "agent-error"
      );
    }
    res.json({ ok: true });
  }
);

// Commissions: authenticated deep drive/folder discovery for existing workspaces.
app.post("/api/commissions/discover", sensitiveLimiter, async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const opts = req.body || {};
    const results = await discoverCommissionFolders({
      company: opts.company,
      playbookId: opts.playbookId,
      maxDepth: opts.maxDepth,
      maxEntriesPerDir: opts.maxEntriesPerDir,
      maxResults: opts.maxResults,
      maxTotalMs: opts.maxTotalMs,
      drives: opts.drives,
      includeRoots: opts.includeRoots,
    });
    res.json({ ok: true, ...results });
  } catch (err) {
    res.status(500).json({ error: err.message || "Discovery failed" });
  }
});

// Runtime automation: tunnel process control + status.
app.get("/api/runtime/status", sensitiveLimiter, (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  const state = getRuntimeState();
  res.json({
    ok: true,
    state,
    launchRoutingMetrics,
    publicUrl: getTunnelPublicUrl() || process.env.MORDECAI_PUBLIC_URL || "",
  });
});

app.post("/api/runtime/tunnel/start", sensitiveLimiter, express.json(), async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const port = Number(req.body?.port || PORT || 3000);
    const result = await startTunnel({
      targetUrl: `http://localhost:${port}`,
      executablePath: req.body?.executablePath,
      args: req.body?.args,
    });
    res.json({ ok: true, ...result, state: getRuntimeState() });
  } catch (err) {
    res.status(500).json({ error: err.message || "Tunnel start failed" });
  }
});

app.post("/api/runtime/tunnel/stop", sensitiveLimiter, async (req, res) => {
  if (!requireBridgeSecret(req, res)) return;
  try {
    const result = await stopTunnel();
    res.json({ ok: true, ...result, state: getRuntimeState() });
  } catch (err) {
    res.status(500).json({ error: err.message || "Tunnel stop failed" });
  }
});

// GitHub PR poll — runs periodically
const GITHUB_POLL_MS = 10 * 60 * 1000; // 10 min
let lastNotifiedPRs = new Set();
let githubUsername = null;

async function getGitHubUsername() {
  if (githubUsername) return githubUsername;
  const token = process.env.GITHUB_TOKEN;
  if (!token) return null;
  try {
    const res = await fetch("https://api.github.com/user", {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    });
    if (!res.ok) return null;
    const user = await res.json();
    githubUsername = user.login || null;
  } catch (_) {}
  return githubUsername;
}

async function pollGitHubPRs() {
  const token = process.env.GITHUB_TOKEN;
  const repos = (process.env.GITHUB_REPOS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  if (!token || repos.length === 0) return;

  const me = await getGitHubUsername();
  if (!me) return;

  try {
    for (const fullRepo of repos) {
      const [owner, repo] = fullRepo.split("/").filter(Boolean);
      if (!owner || !repo) continue;

      const res = await fetch(
        `https://api.github.com/repos/${owner}/${repo}/pulls?state=open`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
          },
        }
      );
      if (!res.ok) continue;

      const pulls = await res.json();
      for (const pr of pulls) {
        const key = `${fullRepo}#${pr.number}`;
        if (lastNotifiedPRs.has(key)) continue;

        const requested = pr.requested_reviewers || [];
        const needsMyReview = requested.some((r) => r.login === me);

        if (needsMyReview) {
          await sendPush(
            "PR needs review",
            `${pr.title} (#${pr.number}) in ${fullRepo}`,
            `pr-${key}`
          );
          lastNotifiedPRs.add(key);
        }
      }
    }
    if (lastNotifiedPRs.size > 50) {
      lastNotifiedPRs = new Set([...lastNotifiedPRs].slice(-30));
    }
  } catch (e) {
    console.warn("[GitHub] PR poll error:", e.message);
  }
}

if (process.env.GITHUB_TOKEN && process.env.GITHUB_REPOS) {
  pollGitHubPRs();
  setInterval(pollGitHubPRs, GITHUB_POLL_MS);
}

// SPA fallback: after express.static falls through (no file), serve index for HTML
// navigations (bookmark/deep link) without a file extension. Skips /api and real assets.
app.use((req, res, next) => {
  if (req.method !== "GET" && req.method !== "HEAD") return next();
  const p = req.path || "";
  if (p.startsWith("/api")) return next();
  const ext = path.extname(p);
  if (ext && ext !== ".html") return next();
  res.sendFile(path.join(STATIC_ROOT, "index.html"), (err) => {
    if (err) next(err);
  });
});

const server = app.listen(PORT, "0.0.0.0", () => {
  console.log(`Mordecai's Maximus running on port ${PORT}`);
  console.log(`Open http://localhost:${PORT} in your browser`);
  console.log("Commissions: phase instructions for Cursor (no external APIs)");
  if (getVapidPublicKey()) {
    console.log("Push notifications: enabled (VAPID configured)");
  }
});
