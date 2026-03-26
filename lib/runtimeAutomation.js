import { spawn } from "child_process";

let tunnelProcess = null;
let tunnelPublicUrl = "";
let lastTunnelError = "";

function parseTunnelUrl(text) {
  if (!text) return "";
  const match = String(text).match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com/i);
  return match ? match[0] : "";
}

export function getTunnelPublicUrl() {
  return tunnelPublicUrl;
}

export function getRuntimeState() {
  return {
    tunnel: {
      running: !!(tunnelProcess && !tunnelProcess.killed),
      pid: tunnelProcess?.pid || null,
      publicUrl: tunnelPublicUrl || "",
      lastError: lastTunnelError || "",
    },
  };
}

export async function startTunnel({
  targetUrl = "http://localhost:3000",
  executablePath,
  args,
} = {}) {
  if (tunnelProcess && !tunnelProcess.killed) {
    return {
      alreadyRunning: true,
      pid: tunnelProcess.pid || null,
      publicUrl: tunnelPublicUrl || "",
    };
  }

  const bin =
    executablePath ||
    process.env.CLOUDFLARED_PATH ||
    "cloudflared";
  const finalArgs = Array.isArray(args) && args.length
    ? args
    : ["tunnel", "--url", targetUrl];

  lastTunnelError = "";
  tunnelPublicUrl = "";
  const child = spawn(bin, finalArgs, {
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
    shell: false,
  });
  tunnelProcess = child;

  child.stdout?.on("data", (buf) => {
    const text = String(buf || "");
    const url = parseTunnelUrl(text);
    if (url) tunnelPublicUrl = url;
  });
  child.stderr?.on("data", (buf) => {
    const text = String(buf || "");
    const url = parseTunnelUrl(text);
    if (url) tunnelPublicUrl = url;
    if (text.trim()) lastTunnelError = text.trim().slice(0, 300);
  });
  child.on("exit", () => {
    tunnelProcess = null;
  });

  await new Promise((resolve) => setTimeout(resolve, 1200));
  return {
    started: true,
    pid: child.pid || null,
    publicUrl: tunnelPublicUrl || "",
    lastError: lastTunnelError || "",
  };
}

export async function stopTunnel() {
  if (!tunnelProcess || tunnelProcess.killed) {
    return { stopped: true, alreadyStopped: true };
  }
  const proc = tunnelProcess;
  return await new Promise((resolve) => {
    const done = () => resolve({ stopped: true, pid: proc.pid || null });
    proc.once("exit", done);
    try {
      proc.kill("SIGTERM");
      setTimeout(() => {
        if (!proc.killed) {
          try {
            proc.kill("SIGKILL");
          } catch (_) {}
        }
      }, 1500);
    } catch (_) {
      resolve({ stopped: false, pid: proc.pid || null });
    }
  });
}
