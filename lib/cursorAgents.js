/**
 * Cursor Cloud Agents API — one agent per commission, followups for each phase.
 * Uses agent config (app Settings) or env fallback — same flow as Cloud Agents.
 */
import { getAgentConfig } from "./agentConfig.js";

const CURSOR_API = "https://api.cursor.com/v0";

function slugify(str) {
  if (!str || typeof str !== "string") return "client";
  return str
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

function normalizeRepo(repo) {
  if (!repo || typeof repo !== "string") return null;
  repo = repo.trim();
  if (!repo) return null;
  if (repo.startsWith("http")) return repo;
  return "https://github.com/" + repo.replace(/^\/+|\/+$/g, "");
}

export async function isConfigured() {
  const c = await getAgentConfig();
  return !!(c.cursorApiKey && c.defaultRepo);
}

/**
 * Launch agent (Phase 1 only). Returns { id, status, ... }.
 */
export async function launchAgent({
  instructions,
  clientInfo,
  referenceImage,
  commissionId,
  playbookId,
  repoOverride,
}) {
  const config = await getAgentConfig();
  const repo = normalizeRepo(repoOverride || config.defaultRepo);
  const key = (config.cursorApiKey || "").trim();

  if (!key) {
    throw new Error("Cursor API key not configured. Go to Settings and add your key (same as Cloud Agents).");
  }
  if (!repo) {
    throw new Error("GitHub repo not configured. Add a default repo in Settings or enter one in the commission form.");
  }

  const auth = "Basic " + Buffer.from(key + ":").toString("base64");
  const slug = slugify(clientInfo?.company || "commission");
  const branchName = `commission/${slug}-${Date.now()}`;

  const prompt = {
    text: instructions,
    images: [],
  };
  if (referenceImage && referenceImage.data) {
    prompt.images.push({
      data: referenceImage.data.replace(/^data:image\/\w+;base64,/, ""),
      dimension: referenceImage.dimension || { width: 1024, height: 768 },
    });
  }

  const body = {
    prompt,
    source: { repository: repo, ref: config.ref || "main" },
    target: {
      autoCreatePr: false,
      branchName,
    },
  };

  const res = await fetch(CURSOR_API + "/agents", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: auth,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error("Cursor API: " + (errText || res.statusText));
  }
  return res.json();
}

/**
 * Send followup to existing agent (Phase 2+). Same agent, next prompt.
 */
export async function sendFollowup({ agentId, instructions, referenceImage }) {
  const config = await getAgentConfig();
  const key = (config.cursorApiKey || "").trim();
  if (!key) {
    throw new Error("Cursor API key not configured. Go to Settings.");
  }

  const auth = "Basic " + Buffer.from(key + ":").toString("base64");
  const prompt = {
    text: instructions,
    images: [],
  };
  if (referenceImage && referenceImage.data) {
    prompt.images.push({
      data: referenceImage.data.replace(/^data:image\/\w+;base64,/, ""),
      dimension: referenceImage.dimension || { width: 1024, height: 768 },
    });
  }

  const res = await fetch(`${CURSOR_API}/agents/${agentId}/followup`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: auth,
    },
    body: JSON.stringify({ prompt }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error("Cursor API followup: " + (errText || res.statusText));
  }
  return res.json();
}

/**
 * Get agent status (for polling).
 */
export async function getAgentStatus(agentId) {
  const config = await getAgentConfig();
  if (!config.cursorApiKey) return null;
  const auth = "Basic " + Buffer.from(config.cursorApiKey.trim() + ":").toString("base64");
  const res = await fetch(`${CURSOR_API}/agents/${agentId}`, {
    headers: { Authorization: auth },
  });
  if (!res.ok) return null;
  return res.json();
}

/**
 * Get conversation history for an agent.
 */
export async function getAgentConversation(agentId) {
  const config = await getAgentConfig();
  if (!config.cursorApiKey) return null;
  const auth = "Basic " + Buffer.from(config.cursorApiKey.trim() + ":").toString("base64");
  const res = await fetch(`${CURSOR_API}/agents/${agentId}/conversation`, {
    headers: { Authorization: auth },
  });
  if (!res.ok) return null;
  return res.json();
}

/**
 * Return newest assistant message preview (if any).
 */
export async function getLatestAssistantMessage(agentId) {
  const conversation = await getAgentConversation(agentId);
  if (!conversation) return null;
  const rawMessages = Array.isArray(conversation)
    ? conversation
    : Array.isArray(conversation.messages)
      ? conversation.messages
      : Array.isArray(conversation.conversation)
        ? conversation.conversation
        : [];
  const messages = rawMessages
    .filter((m) => m && typeof m === "object")
    .map((m) => ({
      role: String(m.role || "").toLowerCase(),
      content: String(m.content || m.text || ""),
      timestamp: m.timestamp || m.created_at || m.updated_at || "",
    }));
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m.role !== "assistant") continue;
    if (!m.content.trim()) continue;
    return {
      content: m.content.trim(),
      preview: m.content.trim().slice(0, 180),
      timestamp: String(m.timestamp || ""),
      fingerprint: `${m.timestamp || "no-ts"}:${m.content.trim().slice(0, 120)}`,
    };
  }
  return null;
}

const STATUS_CREATING = new Set(["queued", "pending", "created", "starting", "initializing", "waiting"]);
const STATUS_RUNNING = new Set(["running", "in_progress", "processing", "working", "active"]);
const STATUS_FINISHED = new Set(["finished", "completed", "succeeded", "success", "done"]);
const STATUS_EXPIRED = new Set(["expired"]);

/**
 * Normalize Cursor agent status into lifecycle labels for notifications/UI.
 */
export function normalizeAgentLifecycle(statusPayload) {
  if (!statusPayload || typeof statusPayload !== "object") return "agent_expired";
  const status = String(statusPayload.status || "").trim().toLowerCase();
  if (STATUS_CREATING.has(status)) return "agent_creating";
  if (STATUS_RUNNING.has(status)) return "agent_running";
  if (STATUS_FINISHED.has(status)) return "agent_finished";
  if (STATUS_EXPIRED.has(status)) return "agent_expired";
  if (!status) return "agent_expired";
  if (status.includes("error") || status.includes("fail") || status.includes("cancel")) {
    return "agent_expired";
  }
  return "agent_running";
}
