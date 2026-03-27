# Mordecai's Maximus

Remote control Cursor AI from your phone. Push notifications for:

- **Agent done** — when your desktop agent finishes (via bridge webhook)
- **Chat errors** — when the chat API fails
- **GitHub PRs** — PRs that need your review

## Quick start

```bash
cd mordecai-maximus
cp .env.example .env
# Edit .env: optionally add GITHUB_TOKEN + GITHUB_REPOS for PR alerts
npm install
npm start
```

Open `http://localhost:3000` in your browser (or phone on same network). The server uses port 3000 by default; set `PORT=3001` in `.env` to use 3001 instead. **Commissions** (phased website building) requires the full Mordecai server — if you see "Commission API not available", ensure `npm start` is running and you're using the correct URL (e.g. http://localhost:3000 or http://localhost:3001). **HTTPS** is required for push notifications on mobile (e.g. Cloudflare Tunnel, ngrok); `localhost` works for desktop testing. VAPID keys are auto-generated on first run — no manual setup.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CURSOR_API_KEY` | No | Fallback if not set in Settings (same key as Cloud Agents) |
| `CURSOR_COMMISSION_REPO` | No | Fallback default repo if not set in Settings |
| `GITHUB_TOKEN` | No | GitHub PAT for PR alerts |
| `GITHUB_REPOS` | No | Comma-separated `owner/repo` to poll |
| `MORDECAI_BRIDGE_SECRET` | No | Secret for desktop bridge webhook and task queue |
| `MORDECAI_ADMIN_TOKEN` | No (Yes in production) | Required for privileged config writes (`/api/config/agents`) |
| `MORDECAI_FCM_WEBHOOK` | No | Firebase function URL to push to Flutter app on task complete |
| `MORDECAI_FCM_WEBHOOK_SECRET` | No | Shared secret sent in `X-Fcm-Webhook-Secret` to secure Firebase push function |
| `MORDECAI_PUBLIC_URL` | No | Public URL for CORS/deep links when using Cloudflare Tunnel |
| `COMMISSIONS_WORKSPACE` | No | Absolute folder for commission projects (e.g. `D:\MordecaiCommissions`). Default: `<repo>/commissions`. |
| `CORS_ALLOW_ORIGINS` | No | Comma-separated browser origin allowlist |
| `API_BODY_LIMIT` | No | JSON body limit (default `512kb`) |
| `API_RATE_LIMIT_PER_MIN` | No | Sensitive route rate limit per minute (default `90`) |
| `POLL_RATE_LIMIT_PER_MIN` | No | Bridge poll rate limit per minute (default `180`) |

**Desktop bridge task queue:** Phone can submit tasks to `/api/bridge/tasks`; desktop extension polls and marks complete. See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for Cloudflare Tunnel setup.

**Drive discovery:** Commissions phase UI now includes authenticated A-Z drive discovery (`/api/commissions/discover`) with read-only limits (`maxDepth`, `maxTotalMs`, result caps) to avoid server stalls.

**Runtime automation:** Server exposes authenticated tunnel controls (`/api/runtime/status`, `/api/runtime/tunnel/start`, `/api/runtime/tunnel/stop`). The desktop extension includes commands to start/stop tunnel and auto-update `mordecai.maximusUrl`.

**Commissions (agent mode):** Same flow as Cloud Agents — no new keys. Click **⚙️ Settings** and add your Cursor API key + default GitHub repo (the same ones you use for Cloud Agents). Or set `CURSOR_API_KEY` and `CURSOR_COMMISSION_REPO` in `.env` as fallback. Each commission uses **one agent**; followups go to the same agent. Optional repo field per commission.

**Phone/WebView URL for Mordecai itself:** In Commissions → Phase progress, use **Mordecai URL for phone / WebView** to store/copy/open/QR your ngrok/tunnel URL (for example `https://xxxx.ngrok-free.app`). Paste that URL in mobile app Settings → Mordecai URL. This is separate from **Phone preview (LAN / tunnel)**, which is for the generated site (often on port `3001`).

**E2E test checklist (browser + Cursor + ports):** see [docs/COMMISSIONS_E2E_LIVE_RUN.md](docs/COMMISSIONS_E2E_LIVE_RUN.md). Quick health check while the server is running: `npm run commissions:preflight`.

### Commissions: phone tab → PC on D: → debug in browser

1. **Mordecai server** must be running (`npm start`). In **`.env`**, set **`COMMISSIONS_WORKSPACE=D:\MordecaiCommissions`** (or any absolute path on **D:**) so commission folders are **not** created under `C:`.
2. **Flutter app** → **Commissions** → enter your Mordecai URL (HTTPS tunnel on phone, or `http://YOUR_PC_IP:3000` on LAN). The app checks health, then loads the same UI as the browser.
3. In the Commissions UI: reference image, website type, phases — **Cursor Cloud Agent** applies changes on a **GitHub branch**. The server **creates the local folder** at `workspacePath` and shows it after each phase so you can **File → Open Folder** in Cursor on your PC, **pull that branch**, then run the site (e.g. **`npm install`** and **`npm run dev -- -p 3001`**). Use **3001** (or another port) for the site so **Mordecai can keep port 3000**.
4. **Desktop bridge / extension** is for **Launch** tasks from the phone into Cursor Composer; commissions stay in this **WebView + Cloud Agent** flow unless you add a separate automation.
5. In **Phase progress**, use **Phone preview (LAN / tunnel)** to save/open/copy/QR your preview URL (for example `http://192.168.1.20:3001` on Wi‑Fi or a tunnel URL). This is what lets you show the client the site live from your phone.

## Push notifications (true background push)

These are **real push notifications** — they alert you even when the app is closed, the tab is closed, or the browser is in the background. The browser's push service delivers to your device; no need to keep the app open.

1. Open the app over **HTTPS** (or `localhost` for dev; mobile requires HTTPS)
2. Click **Enable notifications** and approve the permission
3. Click **Test push** to verify — then close the app; the test notification should still appear
4. You'll get pushes for: chat errors, desktop agent events, GitHub PRs needing review

**Mobile:** Add the app to your home screen (PWA) for best reliability. Run `npm run gen-icons` once to create icons.

## Desktop bridge (agent done / agent error)

A desktop companion can POST events when Cursor agents finish:

```bash
curl -X POST https://your-server/api/mordecai/events \
  -H "Content-Type: application/json" \
  -H "X-Bridge-Secret: YOUR_MORDECAI_BRIDGE_SECRET" \
  -d '{"type":"agent_complete","message":"Task X finished"}'
```

Types: `agent_complete`, `agent_error`

## PWA icons

Add `public/icon-192.png` and `public/icon-512.png` for home screen icons. Without them, the app still works; add-to-home may show a generic icon.

## Workspace

This folder contains **only** Mordecai's Maximus. Tarot, Chatling Ranch, and stream overlays have been archived to `Desktop/Archive/`. If `streamgame` still exists on Desktop (it was locked during removal), close any apps using it and delete it manually — a backup is in `Archive/streamgame/`.

### Windows drives (C:, D:, E:)

Documentation and scripts mention different drives on purpose:

- **C:** — Default profile layout (e.g. `C:\Users\<you>\flutter`, older clone paths like `C:\Users\<you>\cursor_mobile`). Many `cursor_mobile\*.md` examples still use `C:\Users\cmc\…` as a concrete illustration; substitute your user name and actual folder.
- **D:** — Recommended for **commission project folders** created by this server: set `COMMISSIONS_WORKSPACE=D:\MordecaiCommissions` (or any absolute path) in `.env` so worktrees are not created under `C:` by default.
- **E:** — Common for **Cursor/workspace backups**, e.g. `E:\CursorBackup_2026-03-22\mordecai-maximus`. The Flutter app sources live in `cursor_mobile\` under that tree when you open the backup.

The **phone Flutter app** (`cursor_mobile`) does not require a specific drive letter; drive examples are for **this PC** and the **Mordecai server** workspace variable.

### Important: one Flutter app tree only

GitHub Actions and Drive releases build from **`cursor_mobile/`** only. There is also a **duplicate** `pubspec.yaml` + `lib/` (and matching `android/` / `ios/`) at the **repo root** that is **not** what CI ships — it is easy to run by mistake and will **not** include the latest Commissions/WebView fixes. See [`lib/README.md`](lib/README.md). **Always open and run `cursor_mobile` for the phone app.**
