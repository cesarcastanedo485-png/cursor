/**
 * Push notification sender — VAPID, subscription persistence, 410 pruning
 */
import webpush from "web-push";
import { readFileSync, writeFileSync, existsSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const VAPID_PATH = path.join(__dirname, "push-vapid.json");
const SUBS_PATH = path.join(__dirname, "push-subscriptions.json");

let vapidKeys = null;

function loadVapid() {
  if (vapidKeys) return vapidKeys;
  try {
    if (existsSync(VAPID_PATH)) {
      vapidKeys = JSON.parse(readFileSync(VAPID_PATH, "utf8"));
      return vapidKeys;
    }
  } catch (_) {}
  vapidKeys = webpush.generateVAPIDKeys();
  try {
    writeFileSync(VAPID_PATH, JSON.stringify(vapidKeys, null, 2), "utf8");
    console.log("[Push] VAPID keys generated and saved");
  } catch (e) {
    console.warn("[Push] Could not save VAPID keys:", e.message);
  }
  return vapidKeys;
}

function loadSubscriptions() {
  try {
    if (existsSync(SUBS_PATH)) {
      return JSON.parse(readFileSync(SUBS_PATH, "utf8"));
    }
  } catch (_) {}
  return [];
}

function saveSubscriptions(subs) {
  try {
    writeFileSync(SUBS_PATH, JSON.stringify(subs, null, 2), "utf8");
  } catch (e) {
    console.warn("[Push] Could not save subscriptions:", e.message);
  }
}

function initWebPush() {
  const keys = loadVapid();
  if (!keys.publicKey || !keys.privateKey) return false;
  webpush.setVapidDetails(
    "mailto:noreply@mordecai-maximus.local",
    keys.publicKey,
    keys.privateKey
  );
  return true;
}

/**
 * Send push to all subscriptions; remove 410/404 endpoints
 */
export async function sendPush(title, body, tag = null) {
  if (!initWebPush()) return;
  const subs = loadSubscriptions();
  if (subs.length === 0) return;

  const payload = JSON.stringify({ title, body, tag: tag || "default" });
  const alive = [];

  for (const sub of subs) {
    try {
      await webpush.sendNotification(sub, payload, {
        TTL: 60,
        urgency: "high", // Deliver immediately, don't defer for power saving
      });
      alive.push(sub);
    } catch (e) {
      if (e.statusCode === 410 || e.statusCode === 404) {
        console.log("[Push] Removed expired subscription");
      } else {
        console.warn("[Push] Send failed:", e.message);
        alive.push(sub);
      }
    }
  }

  if (alive.length !== subs.length) {
    saveSubscriptions(alive);
  }
}

export function getVapidPublicKey() {
  loadVapid();
  return vapidKeys?.publicKey || null;
}

export function addSubscription(sub) {
  if (!sub || !sub.endpoint) return;
  const subs = loadSubscriptions();
  const idx = subs.findIndex((s) => s.endpoint === sub.endpoint);
  const entry = { ...sub, addedAt: Date.now() };
  if (idx >= 0) subs[idx] = entry;
  else subs.push(entry);
  saveSubscriptions(subs);
}

export function removeSubscription(endpoint) {
  const subs = loadSubscriptions().filter((s) => s.endpoint !== endpoint);
  saveSubscriptions(subs);
}
