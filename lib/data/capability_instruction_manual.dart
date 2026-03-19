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
    title: 'Alexa smart home skill',
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
    title: 'Home Assistant (local smart home)',
    steps: [
      'Install Home Assistant on a Pi or PC; create Long-Lived Access Token (Profile).',
      'REST: POST /api/services/light/turn_on with Bearer token; WebSocket for live events.',
      'Phone on same LAN or Tailscale: https://homeassistant.local:8123 or Tailscale IP.',
    ],
  ),
  ManualSection(
    title: 'TikTok LIVE recordings folder',
    steps: [
      'TikTok LIVE replay save path varies (e.g. Videos/TikTok on Windows).',
      'Desktop watcher script can move finished .mp4 to a known folder; Capabilities **Configure** will map path in a future build.',
    ],
  ),
];
