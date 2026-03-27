import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import {
  getAgentStatus,
  getLatestAssistantMessage,
  normalizeAgentLifecycle,
} from "./cursorAgents.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, "..");
const DEVICE_PREFS_PATH = path.join(ROOT_DIR, "fcm-device-preferences.json");

const WATCH_INTERVAL_MS = 5000;
const WATCH_LEASE_MS = 60 * 60 * 1000;
const RUNNING_PUSH_TTL_MS = 60 * 1000;
const DEFAULT_PREFS = {
  creating: true,
  running: true,
  finished: true,
  expired: true,
  assistant_message: true,
};

const agentWatchers = new Map();
let prefsLoaded = false;
const tokenPrefs = new Map();
let globalSeq = 0;

function normalizePrefs(prefs = {}) {
  return {
    creating: prefs.creating !== false,
    running: prefs.running !== false,
    finished: prefs.finished !== false,
    expired: prefs.expired !== false,
    assistant_message: prefs.assistant_message !== false,
  };
}

async function ensurePrefsLoaded() {
  if (prefsLoaded) return;
  prefsLoaded = true;
  try {
    const raw = await fs.readFile(DEVICE_PREFS_PATH, "utf8");
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return;
    for (const [token, prefs] of Object.entries(parsed)) {
      if (!token) continue;
      tokenPrefs.set(token, normalizePrefs(prefs));
    }
  } catch (_) {}
}

async function persistPrefs() {
  const out = {};
  for (const [token, prefs] of tokenPrefs.entries()) {
    out[token] = prefs;
  }
  await fs.writeFile(DEVICE_PREFS_PATH, JSON.stringify(out, null, 2), "utf8");
}

function nextEventId(agentId) {
  globalSeq += 1;
  return `${agentId}-${Date.now()}-${globalSeq}`;
}

function makeSseEventLine(event) {
  const data = JSON.stringify(event);
  return `id: ${event.eventId}\nevent: ${event.type}\ndata: ${data}\n\n`;
}

function ensureWatcher(agentId, sendFcmEvent) {
  let watcher = agentWatchers.get(agentId);
  if (watcher) return watcher;
  watcher = {
    agentId,
    timer: null,
    sseClients: new Set(),
    devices: new Map(), // token -> expiresAt
    lastLifecycle: null,
    lastAssistantFingerprint: null,
    lastRunningPushAt: 0,
  };
  agentWatchers.set(agentId, watcher);

  const tick = async () => {
    const now = Date.now();
    for (const [token, expiresAt] of watcher.devices.entries()) {
      if (expiresAt <= now) watcher.devices.delete(token);
    }
    if (watcher.sseClients.size === 0 && watcher.devices.size === 0) {
      if (watcher.timer) clearInterval(watcher.timer);
      agentWatchers.delete(agentId);
      return;
    }

    let status = null;
    try {
      status = await getAgentStatus(agentId);
    } catch (err) {
      console.warn(`[AgentEvents] status check failed for ${agentId}:`, err?.message || err);
    }
    const lifecycle = normalizeAgentLifecycle(status);
    const changedLifecycle = lifecycle !== watcher.lastLifecycle;
    watcher.lastLifecycle = lifecycle;

    if (changedLifecycle) {
      const event = {
        eventId: nextEventId(agentId),
        type: lifecycle,
        agentId,
        status: status?.status || null,
        at: new Date().toISOString(),
      };
      broadcastWatcherEvent(watcher, event, sendFcmEvent);
    } else if (lifecycle === "agent_running" && now - watcher.lastRunningPushAt > RUNNING_PUSH_TTL_MS) {
      watcher.lastRunningPushAt = now;
      const event = {
        eventId: nextEventId(agentId),
        type: "agent_running",
        agentId,
        status: status?.status || "running",
        at: new Date().toISOString(),
        heartbeat: true,
      };
      broadcastWatcherEvent(watcher, event, sendFcmEvent);
    }

    try {
      const latest = await getLatestAssistantMessage(agentId);
      if (!latest || !latest.fingerprint) return;
      if (latest.fingerprint === watcher.lastAssistantFingerprint) return;
      watcher.lastAssistantFingerprint = latest.fingerprint;
      const event = {
        eventId: nextEventId(agentId),
        type: "assistant_message",
        agentId,
        at: new Date().toISOString(),
        messagePreview: latest.preview,
        threadId: agentId,
        messageFingerprint: latest.fingerprint,
      };
      broadcastWatcherEvent(watcher, event, sendFcmEvent);
    } catch (err) {
      console.warn(`[AgentEvents] conversation check failed for ${agentId}:`, err?.message || err);
    }
  };

  watcher.timer = setInterval(tick, WATCH_INTERVAL_MS);
  tick();
  return watcher;
}

function shouldPushByPreference(type, prefs) {
  if (!prefs) return false;
  if (type === "assistant_message") return prefs.assistant_message;
  if (type === "agent_creating") return prefs.creating;
  if (type === "agent_running") return prefs.running;
  if (type === "agent_finished") return prefs.finished;
  if (type === "agent_expired") return prefs.expired;
  return false;
}

function getPushText(event) {
  if (event.type === "assistant_message") {
    return {
      title: "Agent message",
      body: event.messagePreview || "Your agent sent a new message.",
    };
  }
  if (event.type === "agent_creating") {
    return { title: "Agent starting", body: "Your agent is being created." };
  }
  if (event.type === "agent_running") {
    return { title: "Agent running", body: "Your agent is actively working." };
  }
  if (event.type === "agent_finished") {
    return { title: "Agent finished", body: "Your agent has completed its task." };
  }
  return { title: "Agent expired", body: "Your agent is no longer available." };
}

function broadcastWatcherEvent(watcher, event, sendFcmEvent) {
  if (event.type === "agent_running" && !event.heartbeat) {
    watcher.lastRunningPushAt = Date.now();
  }
  for (const client of watcher.sseClients) {
    try {
      client.write(makeSseEventLine(event));
    } catch (_) {}
  }
  for (const token of watcher.devices.keys()) {
    const prefs = tokenPrefs.get(token) || DEFAULT_PREFS;
    if (!shouldPushByPreference(event.type, prefs)) continue;
    const text = getPushText(event);
    sendFcmEvent({
      token,
      title: text.title,
      message: text.body,
      type: event.type,
      agentId: watcher.agentId,
      eventId: event.eventId,
      messagePreview: event.messagePreview || "",
      threadId: event.threadId || watcher.agentId,
    });
  }
}

export async function registerDeviceToken({ token, preferences }) {
  if (!token || typeof token !== "string") {
    throw new Error("token required");
  }
  await ensurePrefsLoaded();
  const normalized = normalizePrefs(preferences || {});
  tokenPrefs.set(token.trim(), normalized);
  await persistPrefs();
  return normalized;
}

export async function getDeviceTokenPrefs(token) {
  await ensurePrefsLoaded();
  return tokenPrefs.get(token) || DEFAULT_PREFS;
}

export async function updateDeviceTokenPrefs({ token, preferences }) {
  return registerDeviceToken({ token, preferences });
}

export function watchAgentForDevice({ agentId, token, sendFcmEvent }) {
  if (!agentId || !token) return;
  const watcher = ensureWatcher(agentId, sendFcmEvent);
  watcher.devices.set(token, Date.now() + WATCH_LEASE_MS);
}

export function attachSseClient({
  agentId,
  res,
  sendFcmEvent,
  token,
}) {
  const watcher = ensureWatcher(agentId, sendFcmEvent);
  watcher.sseClients.add(res);
  if (token) watcher.devices.set(token, Date.now() + WATCH_LEASE_MS);
  const hello = {
    eventId: nextEventId(agentId),
    type: "stream_ready",
    agentId,
    at: new Date().toISOString(),
  };
  res.write(makeSseEventLine(hello));

  return () => {
    watcher.sseClients.delete(res);
  };
}
