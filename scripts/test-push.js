/**
 * Test push notifications — run: node scripts/test-push.js
 * Sends a mock notification to all subscribed clients.
 */
import { sendPush } from "../pushNotifications.js";
import { readFileSync, existsSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SUBS_PATH = path.join(__dirname, "..", "push-subscriptions.json");

async function main() {
  const subs = existsSync(SUBS_PATH)
    ? JSON.parse(readFileSync(SUBS_PATH, "utf8"))
    : [];
  console.log(`Subscriptions: ${subs.length}`);
  if (subs.length === 0) {
    console.log("No subscribers. Enable notifications in the app first, then run this again.");
    return;
  }
  console.log("Sending test push notification...");
  await sendPush("Test notification", "If you see this, push is working!", "test");
  console.log("Done. Check your device for the notification.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
