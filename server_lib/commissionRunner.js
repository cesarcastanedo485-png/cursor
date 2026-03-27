/**
 * Commission runner — loads playbooks, provides phase instructions for Cursor AI.
 * Phases are executed by Cursor (Composer), not by external APIs or terminal commands.
 */
import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, "..");
const DEFAULT_WORKSPACE = path.join(PROJECT_ROOT, "commissions");

function slugify(str) {
  if (!str || typeof str !== "string") return "client";
  return str
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

function getWorkspaceRoot() {
  const envPath = process.env.COMMISSIONS_WORKSPACE;
  if (envPath) {
    return path.isAbsolute(envPath) ? envPath : path.resolve(PROJECT_ROOT, envPath);
  }
  return DEFAULT_WORKSPACE;
}

export async function loadPlaybook(playbookId) {
  const playbookPath = path.join(
    PROJECT_ROOT,
    "public",
    "data",
    "playbooks",
    playbookId + ".json"
  );
  const resolved = path.resolve(playbookPath);
  const publicPlaybooks = path.resolve(PROJECT_ROOT, "public", "data", "playbooks");
  if (!resolved.startsWith(publicPlaybooks)) {
    throw new Error("Invalid playbook id");
  }
  const raw = await fs.readFile(playbookPath, "utf-8");
  return JSON.parse(raw);
}

/**
 * Get phase instructions for Cursor to execute.
 * Returns the prompt/instructions — Cursor does the actual building.
 */
export function getPhaseInstructions(playbook, phaseId, clientInfo) {
  const phase = (playbook.phases || []).find((p) => p.id === String(phaseId));
  if (!phase) throw new Error("Phase not found: " + phaseId);

  const promptTemplate = phase.promptTemplate || phase.prompt || "";
  const clientStr = clientInfo
    ? JSON.stringify(clientInfo, null, 2)
    : "{}";
  const instructions =
    typeof promptTemplate === "string"
      ? promptTemplate.replace("{{clientInfo}}", clientStr)
      : (phase.prompt || "") + "\n\nClient info:\n" + clientStr;

  return {
    phase,
    instructions,
    techStack: playbook.techStack || "HTML/CSS/JS",
  };
}

/**
 * Folder where commission files should live (local dev / Cursor desktop).
 * - Set COMMISSIONS_WORKSPACE to an absolute path (e.g. D:\\MordecaiCommissions) to use another drive.
 * - Playbook paths like ./commissions/[company-slug]-… resolve under that root (no double "commissions" folder).
 */
export function getWorkspaceForCommission(commissionId, clientInfo, playbook) {
  const root = getWorkspaceRoot();
  const prefix = playbook?.defaultWorkspacePrefix;
  if (prefix && clientInfo?.company) {
    const slug = slugify(clientInfo.company);
    let relative = prefix.replace("[company-slug]", slug).replace(/^\.\//, "");
    // Root is already the commissions directory; strip redundant commissions/ prefix from playbooks.
    if (relative.startsWith("commissions/")) {
      relative = relative.slice("commissions/".length);
    }
    if (path.isAbsolute(relative)) {
      return relative;
    }
    return path.resolve(root, relative);
  }
  const safeId = (commissionId || "default").replace(/[^a-zA-Z0-9_-]/g, "_");
  return path.join(root, safeId);
}
