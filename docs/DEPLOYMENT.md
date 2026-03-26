# Mordecai's Maximus Deployment

Deploy Mordecai so the mobile app and desktop bridge work from anywhere (cellular, Wi-Fi away from home).

## Cloudflare Tunnel (recommended)

No firewall changes or static IP needed. Provides a public `*.trycloudflare.com` URL.

1. Install [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/):
   - Windows: `winget install Cloudflare.cloudflared` or download from Cloudflare
   - Mac: `brew install cloudflared`
   - Linux: see [Cloudflare docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)

2. Start Mordecai:
   ```bash
   cd mordecai-maximus
   npm start
   ```

3. In another terminal, run the tunnel:
   ```bash
   cloudflared tunnel --url http://localhost:3000
   ```

4. Copy the `*.trycloudflare.com` URL from the output. Example:
   ```
   Your quick Tunnel has been created! Visit it at:
   https://random-words-123.trycloudflare.com
   ```

5. Set that URL in the mobile app: **Settings → Mordecai URL**.

6. Optional: set in `.env` for consistency:
   ```
   MORDECAI_PUBLIC_URL=https://random-words-123.trycloudflare.com
   ```

**Note:** Quick tunnels generate a new URL each time. For a stable URL, use a [named tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/tunnel-guide/).

## Alternatives

### ngrok

```bash
ngrok http 3000
```

Use the HTTPS URL in the app.

### Railway / Fly.io / Render

Deploy the Node app to a PaaS. Set `PORT` from the platform (usually provided). The platform gives you a public URL.

## FCM push for Flutter app

For the Flutter app to receive push when the desktop bridge completes a task:

1. Deploy the Firebase function in `cursor_mobile/firebase`:
   ```bash
   cd cursor_mobile/firebase
   firebase deploy --only functions
   ```

2. Get the function URL from Firebase Console or `firebase functions:list`.

3. Set in Mordecai `.env`:
   ```
   MORDECAI_FCM_WEBHOOK=https://us-central1-YOUR_PROJECT.cloudfunctions.net/sendAgentCompletedPush
   MORDECAI_FCM_WEBHOOK_SECRET=YOUR_RANDOM_SECRET
   ```

4. In Firebase Functions environment, set the same secret:
   - `MORDECAI_FCM_WEBHOOK_SECRET=YOUR_RANDOM_SECRET`

## Bridge secret

For production, set `MORDECAI_BRIDGE_SECRET` in `.env`. The phone app and desktop extension must send this in the `X-Bridge-Secret` header when calling bridge endpoints.

Also set:

```
MORDECAI_ADMIN_TOKEN=YOUR_ADMIN_TOKEN
```

This protects privileged config endpoints in production.

## Runtime automation endpoints

Authenticated endpoints (require `X-Bridge-Secret`):

- `GET /api/runtime/status`
- `POST /api/runtime/tunnel/start`
- `POST /api/runtime/tunnel/stop`

These are used by the desktop extension commands for one-tap tunnel lifecycle.

## Commission workspaces (local folder on D:)

Set in `.env`:

```
COMMISSIONS_WORKSPACE=D:\MordecaiCommissions
```

Restart `npm start`. New commissions get a subfolder under that path (playbook names like `acme-ecommerce-nextjs`). The Commissions UI shows the full path after each phase. Cloud Agents still push to GitHub — open that folder in Cursor, pull the commission branch, then run the dev server on a port **other than 3000** (e.g. `npm run dev -- -p 3001`) while Mordecai stays on 3000.

## Phone live preview

`localhost` on your phone is the phone itself, not your PC. Use one of:

- Same Wi‑Fi: `http://YOUR_PC_LAN_IP:3001`
- Tunnel URL to your web app dev server port

Commissions → Phase progress now includes a **Phone preview (LAN / tunnel)** helper where you can save/open/copy/QR this URL.
