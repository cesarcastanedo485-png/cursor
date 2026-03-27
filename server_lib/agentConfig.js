/**
 * Agent config — same flow as Cloud Agents: configure in app, no .env required.
 * Stored in config/agents.json (gitignored). Env vars still work as fallback.
 */
import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CONFIG_PATH = path.resolve(__dirname, "..", "config", "agents.json");

let cached = null;

async function loadConfig() {
  if (cached) return cached;
  try {
    const raw = await fs.readFile(CONFIG_PATH, "utf-8");
    cached = JSON.parse(raw);
  } catch (_) {
    cached = {};
  }
  return cached;
}

function envFallback() {
  return {
    cursorApiKey: (process.env.CURSOR_API_KEY || "").trim(),
    defaultRepo: (process.env.CURSOR_COMMISSION_REPO || "").trim(),
    ref: (process.env.CURSOR_COMMISSION_REF || "main").trim(),
  };
}

export async function getAgentConfig() {
  const file = await loadConfig();
  const env = envFallback();
  return {
    cursorApiKey: file.cursorApiKey || env.cursorApiKey,
    defaultRepo: file.defaultRepo || env.defaultRepo,
    ref: file.ref || env.ref || "main",
  };
}

export async function saveAgentConfig({ cursorApiKey, defaultRepo }) {
  const dir = path.dirname(CONFIG_PATH);
  await fs.mkdir(dir, { recursive: true });
  const existing = await loadConfig();
  const next = { ...existing };
  if (cursorApiKey !== undefined) {
    const k = String(cursorApiKey).trim();
    if (k) next.cursorApiKey = k;
  }
  if (defaultRepo !== undefined) {
    next.defaultRepo = String(defaultRepo).trim();
  }
  await fs.writeFile(CONFIG_PATH, JSON.stringify(next, null, 2), "utf-8");
  cached = next;
}

/** Safe check for UI — never exposes the key */
export async function getAgentConfigStatus() {
  const c = await getAgentConfig();
  return {
    configured: !!(c.cursorApiKey && c.defaultRepo),
    hasKey: !!c.cursorApiKey,
    hasRepo: !!c.defaultRepo,
    defaultRepo: c.defaultRepo || "",
  };
}
