/**
 * Commissions E2E preflight: optional .env hints + TCP port probe + GET /api/commissions/health.
 * Run with Mordecai stopped (env-only) or while `npm start` is running (full check).
 *
 * Usage:
 *   node scripts/commissions-preflight.mjs
 *   MORDECAI_PREFLIGHT_URL=http://127.0.0.1:3001 node scripts/commissions-preflight.mjs
 */
import dotenv from "dotenv";
import net from "net";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, "..");
dotenv.config({ path: path.join(repoRoot, ".env") });

const args = new Set(process.argv.slice(2));
const skipHealth = args.has("--skip-health");
const skipPort = args.has("--skip-port");

const port = parseInt(String(process.env.PORT || "3000"), 10) || 3000;
const base = (process.env.MORDECAI_PREFLIGHT_URL || `http://127.0.0.1:${port}`).replace(/\/$/, "");

function probePort(p) {
  return new Promise((resolve) => {
    const socket = net.createConnection({ port: p, host: "127.0.0.1" }, () => {
      socket.end();
      resolve(true);
    });
    socket.setTimeout(1500, () => {
      socket.destroy();
      resolve(false);
    });
    socket.on("error", () => resolve(false));
  });
}

async function main() {
  console.log("Mordecai — Commissions preflight\n");

  const hasEnvKey = !!(process.env.CURSOR_API_KEY && String(process.env.CURSOR_API_KEY).trim());
  const hasEnvRepo = !!(process.env.CURSOR_COMMISSION_REPO && String(process.env.CURSOR_COMMISSION_REPO).trim());
  const ws = process.env.COMMISSIONS_WORKSPACE;

  console.log("Environment (.env) — Commissions-related:");
  console.log(
    `  CURSOR_API_KEY:     ${hasEnvKey ? "set" : "not set (ok if saved in Mordecai Settings UI)"}`
  );
  console.log(
    `  CURSOR_COMMISSION_REPO: ${hasEnvRepo ? "set" : "not set (ok if saved in Mordecai Settings UI)"}`
  );
  console.log(`  COMMISSIONS_WORKSPACE: ${ws ? ws : "(default: <repo>/commissions)"}`);
  console.log(`  PORT: ${port}\n`);

  if (!skipPort) {
    const listening = await probePort(port);
    console.log(`Port ${port} (127.0.0.1): ${listening ? "something is listening" : "nothing listening"}`);
    if (!listening) {
      console.log("  → Start Mordecai: npm start\n");
    }
  }

  if (skipHealth) {
    console.log("(Skipped GET /api/commissions/health — use without --skip-health when server is up.)");
    return;
  }

  const url = `${base}/api/commissions/health`;
  console.log(`GET ${url}`);
  try {
    const res = await fetch(url, { headers: { Accept: "application/json" } });
    const text = await res.text();
    let body;
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
    if (!res.ok) {
      console.error(`  HTTP ${res.status}:`, body);
      process.exitCode = 1;
      return;
    }
    console.log("  OK:", body);
  } catch (err) {
    console.error("  Failed:", err.message || err);
    console.error("  Is Mordecai running? Try: npm start");
    process.exitCode = 1;
  }
}

main();
