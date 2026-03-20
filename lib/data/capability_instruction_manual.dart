/// Step-by-step setup guides for Capabilities tab (Instruction Manual).
class ManualSection {
  const ManualSection({required this.title, required this.steps});

  final String title;
  final List<String> steps;
}

const List<ManualSection> kCapabilityInstructionManual = [
  ManualSection(
    title: 'Google OAuth & YouTube Data API v3',
    steps: [
      'Open Google Cloud Console → create or select a project.',
      'APIs & Services → Enable APIs → enable **YouTube Data API v3** (and **YouTube Analytics** if needed).',
      'Credentials → Create credentials → **OAuth client ID** (Desktop or Web, depending on your bridge).',
      'Configure OAuth consent screen (External or Internal); add scopes: youtube, youtube.force-ssl, yt-analytics.readonly.',
      'Download client JSON; your desktop bridge exchanges the auth code for refresh_token (never ship client_secret in the mobile app for production).',
      'Use refresh_token on a secure server to call upload, comment, thumbnail, and analytics endpoints.',
    ],
  ),
  ManualSection(
    title: 'Smart home bridge (Lights, Thermostat, Alexa)',
    steps: [
      'Run the bridge script: **python smarthome_bridge.py** (in cursor_mobile/scripts/).',
      'Set env vars: **HA_URL** (e.g. http://192.168.1.10:8123), **HA_TOKEN** (Long-Lived Access Token from HA Profile).',
      'Or use **IFTTT**: set IFTTT_KEY; create applets at ifttt.com — Webhook event names: lights_on, lights_off, thermostat_72, etc.',
      'Bridge listens on port 8765. In app Configure → Webhook URL: **http://YOUR_PC_IP:8765/webhook** (run `ipconfig` for your PC IP; same LAN or Tailscale).',
      'Add your bulbs/thermostat to Home Assistant (Hue, Nest, Ecobee, Zigbee) — HA controls them; bridge forwards app requests to HA.',
    ],
  ),
  ManualSection(
    title: 'Voice Monkey + IFTTT (Alexa routines from phone)',
    steps: [
      'Go to **voicemonkey.io** → sign in with Amazon → create Routine Trigger devices (e.g. "Lights On", "Thermostat 72").',
      'Enable **Voice Monkey** skill in Alexa app; devices appear under Smart Home.',
      'Alexa app → Routines → create routine: When Smart Home "Lights On" → add action (turn on lights, set thermostat, etc.).',
      'IFTTT → Create applet: If Webhooks "Receive a web request" (event: lights_on) → Then Alexa Voice Monkey "Trigger Monkey" → select device.',
      'Get webhook URL: **https://maker.ifttt.com/trigger/lights_on/with/key/YOUR_KEY** (key at ifttt.com/maker_webhooks → Settings).',
      'In app Configure for Smart lights → paste that URL. Create one applet per action (lights_off, thermostat_72, etc.).',
    ],
  ),
  ManualSection(
    title: 'Home Assistant REST API (direct control)',
    steps: [
      'Install Home Assistant (Pi, PC, or NAS); add integrations for your bulbs (Philips Hue, Zigbee) and thermostat (Nest, Ecobee).',
      'Profile → Long-Lived Access Tokens → Create token; copy it.',
      'REST: **POST /api/services/light/turn_on** with body {"entity_id":"light.living_room"}, header **Authorization: Bearer TOKEN**.',
      'Thermostat: **POST /api/services/climate/set_temperature** with {"entity_id":"climate.home","temperature":72}.',
      'Use the Mordechaius bridge script to forward app webhooks to these HA endpoints, or call HA directly if your app can reach it.',
    ],
  ),
  ManualSection(
    title: 'Alexa smart home skill (advanced)',
    steps: [
      'Amazon Developer Console → Alexa → Create Skill → Smart Home or Custom.',
      'Link AWS Lambda (or your HTTPS endpoint) as the skill backend.',
      'Account linking: OAuth2 or Login with Amazon so users connect their Amazon account to your service.',
      'Discovery + control directives for lights, plugs, thermostats; test in Alexa app before certification.',
      'For music/volume on Echo devices, use Alexa Music/APIs where licensed; many flows require partner approval.',
    ],
  ),
  ManualSection(
    title: 'OBS Studio WebSocket (v5+)',
    steps: [
      'OBS → Tools → WebSocket Server Settings → Enable server, set port (default 4455) and password.',
      'Install obs-websocket plugin if using older OBS; v30+ often bundles it.',
      'From a PC bridge: connect to ws://127.0.0.1:4455 with JSON auth; call SetCurrentProgramScene, StartStreaming, etc.',
      'Phone cannot reach OBS directly unless PC exposes LAN/Tailscale IP — run **Mordechaius bridge** on desktop that proxies commands.',
    ],
  ),
  ManualSection(
    title: 'TikTok Content Posting & webhooks',
    steps: [
      'Apply for TikTok for Developers / Content Posting API access (approval required).',
      'Register app, complete OAuth, store access_token + refresh_token server-side.',
      'Video upload: initiate → chunk upload → publish; respect rate limits and content policies.',
      'Webhooks for comments/DMs where available; verify signatures on your endpoint.',
    ],
  ),
  ManualSection(
    title: 'Meta (Facebook) Messenger',
    steps: [
      'developers.facebook.com → Create App → Messenger product.',
      'Connect Facebook Page, generate Page Access Token, subscribe to webhooks (verify token challenge).',
      'HTTPS webhook URL must be publicly reachable; handle messaging_postbacks and messages.',
      'App Review for pages_messaging and related permissions before public use.',
    ],
  ),
  ManualSection(
    title: 'Instagram Graph API',
    steps: [
      'Business/Creator Instagram account linked to a Facebook Page.',
      'Graph API Explorer with Page token; permissions: instagram_basic, instagram_content_publish, etc.',
      'Media container → publish flow for feed/Reels; scheduling via your backend cron.',
    ],
  ),
  ManualSection(
    title: 'Twilio SMS',
    steps: [
      'Sign up at twilio.com, get Account SID + Auth Token.',
      'Buy a phone number with SMS capability.',
      'POST https://api.twilio.com/2010-04-01/Accounts/{Sid}/Messages.json with Basic auth.',
      'Compliance: opt-in, STOP handling, never auto-send marketing without consent.',
    ],
  ),
  ManualSection(
    title: 'Opus Clip / video AI APIs',
    steps: [
      'Check Opus (or partner) for official API access; many flows are web-only.',
      'Alternative: desktop automation (Playwright) with user login — fragile; prefer official API when available.',
      'Store API keys in flutter_secure_storage or server-only vault.',
    ],
  ),
  ManualSection(
    title: 'TikTok LIVE recordings folder',
    steps: [
      'TikTok LIVE replay save path varies (e.g. Videos/TikTok on Windows).',
      'Desktop watcher script can move finished .mp4 to a known folder; Capabilities **Configure** will map path in a future build.',
    ],
  ),
  ManualSection(
    title: 'Send Email (SMTP / SendGrid / Resend)',
    steps: [
      'Option A: Run the Mordechaius bridge with **EMAIL_SMTP_HOST**, **EMAIL_SMTP_PORT**, **EMAIL_FROM**, **EMAIL_PASSWORD** (or app password).',
      'Option B: Use SendGrid/Resend API — webhook → your server sends via their REST API; store API key in Configure.',
      'Bridge receives webhook with **to**, **subject**, **body** in payload; forwards to SMTP or email API.',
      'Configure → Webhook URL: your bridge (e.g. http://YOUR_PC_IP:8765/webhook).',
    ],
  ),
  ManualSection(
    title: 'Drive sync (Upload to Drive + Check for updates)',
    steps: [
      '**Upload**: Run the Mordechaius bridge with **DRIVE_FOLDER_ID**, **DRIVE_CREDENTIALS_JSON** (or OAuth tokens). Bridge script uploads APK from desktop path to that folder.',
      'Configure Upload to Drive → Webhook URL: bridge address. Execute sends action **upload_apk**; bridge runs: copy APK from build output → upload to Drive.',
      '**Download**: Get a direct link for your APK. In Google Drive: right-click file → Get link → set "Anyone with the link" → copy. Use export link: **https://drive.google.com/uc?export=download&id=FILE_ID** (replace FILE_ID from the share link).',
      'Configure Check for updates → Folder path / Download URL: paste that direct link. Execute downloads the APK and opens it for install.',
    ],
  ),
];
