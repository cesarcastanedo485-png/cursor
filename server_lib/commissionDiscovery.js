import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import { getWorkspaceForCommission } from "./commissionRunner.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, "..");
const DEFAULT_ROOT = path.join(PROJECT_ROOT, "commissions");
const WINDOWS_DRIVES = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

function clampNum(value, fallback, min, max) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch (_) {
    return false;
  }
}

async function getDriveRoots(drives) {
  const list = Array.isArray(drives) && drives.length
    ? drives.map((d) => String(d).toUpperCase().replace(":", "")).filter(Boolean)
    : WINDOWS_DRIVES;
  const roots = [];
  for (const d of list) {
    const root = `${d}:\\`;
    if (await pathExists(root)) roots.push(root);
  }
  return roots;
}

function scoreDir({ dirName, fullPath, companySlug }) {
  let score = 0;
  const reasons = [];
  const lowDir = dirName.toLowerCase();
  const lowPath = fullPath.toLowerCase();
  if (lowDir.includes("commission") || lowPath.includes("commission")) {
    score += 35;
    reasons.push("name contains commission");
  }
  if (lowDir.includes("mordecai") || lowPath.includes("mordecai")) {
    score += 20;
    reasons.push("name contains mordecai");
  }
  if (companySlug && (lowDir.includes(companySlug) || lowPath.includes(companySlug))) {
    score += 30;
    reasons.push("matches company slug");
  }
  if (lowDir.includes("workspace") || lowPath.includes("workspace")) {
    score += 10;
    reasons.push("looks like workspace folder");
  }
  return { score, reasons };
}

function skipDirName(name) {
  const low = name.toLowerCase();
  return (
    low === "$recycle.bin" ||
    low === "system volume information" ||
    low === "windows" ||
    low === "program files" ||
    low === "program files (x86)" ||
    low === "programdata" ||
    low === "appdata" ||
    low === "node_modules" ||
    low === ".git"
  );
}

async function readDirSafe(dir) {
  try {
    return await fs.readdir(dir, { withFileTypes: true });
  } catch (_) {
    return null;
  }
}

function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

export async function discoverCommissionFolders({
  company,
  playbookId,
  maxDepth = 4,
  maxEntriesPerDir = 500,
  maxResults = 60,
  maxTotalMs = 12000,
  drives,
  includeRoots = [],
} = {}) {
  const startedAt = Date.now();
  const companySlug = slugify(company);
  const depthLimit = clampNum(maxDepth, 4, 1, 8);
  const entriesLimit = clampNum(maxEntriesPerDir, 500, 50, 5000);
  const resultsLimit = clampNum(maxResults, 60, 10, 300);
  const totalMs = clampNum(maxTotalMs, 12000, 1000, 60000);
  const driveRoots = process.platform === "win32" ? await getDriveRoots(drives) : [];
  const customRoots = (Array.isArray(includeRoots) ? includeRoots : [])
    .map((r) => String(r || "").trim())
    .filter(Boolean)
    .map((r) => path.resolve(r));
  const roots = Array.from(new Set([DEFAULT_ROOT, ...customRoots, ...driveRoots]));

  const discovered = [];
  const inspectedRoots = [];
  let visitedDirs = 0;
  let skippedDirs = 0;
  let timedOut = false;

  // Include expected workspace path first if we can infer it from playbook/company.
  if (playbookId && company) {
    try {
      const expected = getWorkspaceForCommission(
        "discovery_probe",
        { company },
        { defaultWorkspacePrefix: `./commissions/[company-slug]-${playbookId}` }
      );
      discovered.push({
        path: expected,
        exists: await pathExists(expected),
        score: 95,
        reasons: ["derived from playbook and company"],
      });
    } catch (_) {}
  }

  for (const root of roots) {
    if (Date.now() - startedAt >= totalMs) {
      timedOut = true;
      break;
    }
    if (!(await pathExists(root))) continue;
    inspectedRoots.push(root);
    const queue = [{ dir: root, depth: 0 }];
    while (queue.length) {
      if (Date.now() - startedAt >= totalMs) {
        timedOut = true;
        break;
      }
      const next = queue.shift();
      if (!next) continue;
      visitedDirs += 1;
      const entries = await readDirSafe(next.dir);
      if (!entries) {
        skippedDirs += 1;
        continue;
      }
      const dirs = entries
        .filter((e) => e.isDirectory())
        .slice(0, entriesLimit);
      for (const ent of dirs) {
        const child = path.join(next.dir, ent.name);
        if (skipDirName(ent.name)) {
          skippedDirs += 1;
          continue;
        }
        const scored = scoreDir({
          dirName: ent.name,
          fullPath: child,
          companySlug,
        });
        const looksInteresting = scored.score >= 25;
        if (looksInteresting) {
          const packageJson = path.join(child, "package.json");
          const hasPackageJson = await pathExists(packageJson);
          discovered.push({
            path: child,
            exists: true,
            hasPackageJson,
            score: scored.score + (hasPackageJson ? 8 : 0),
            reasons: hasPackageJson
              ? [...scored.reasons, "contains package.json"]
              : scored.reasons,
          });
          if (discovered.length >= resultsLimit) break;
        }
        if (next.depth < depthLimit) {
          queue.push({ dir: child, depth: next.depth + 1 });
        }
      }
      if (discovered.length >= resultsLimit) break;
    }
    if (timedOut || discovered.length >= resultsLimit) break;
  }

  const deduped = Array.from(
    new Map(discovered.map((d) => [d.path.toLowerCase(), d])).values()
  ).sort((a, b) => b.score - a.score);

  return {
    discovered: deduped.slice(0, resultsLimit),
    diagnostics: {
      inspectedRoots,
      visitedDirs,
      skippedDirs,
      elapsedMs: Date.now() - startedAt,
      timedOut,
      limits: {
        maxDepth: depthLimit,
        maxEntriesPerDir: entriesLimit,
        maxResults: resultsLimit,
        maxTotalMs: totalMs,
      },
    },
  };
}
