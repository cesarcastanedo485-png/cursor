/// Automation capability metadata + instruction manual steps.
class CapabilityItem {
  const CapabilityItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.manualSteps,
    this.risk = CapabilityRisk.medium,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> manualSteps;
  final CapabilityRisk risk;
}

enum CapabilityRisk { low, medium, high }

/// IDs that use the Mordecai `/api/capabilities/smarthome` Home Assistant bridge.
const Set<String> kSmartHomeCapabilityIds = {
  'smarthome_lights',
  'smarthome_thermostat',
  'smarthome_alexa',
};

const List<CapabilityItem> kCapabilitiesCatalog = [
  CapabilityItem(
    id: 'sms',
    title: 'Send SMS',
    summary: 'Send text messages from the device or via a trusted relay.',
    risk: CapabilityRisk.high,
    manualSteps: [
      'Android: add SEND_SMS permission; many carriers block automated SMS — use Twilio API from a secure backend instead for production.',
      'Register Twilio, verify numbers, store API keys only in flutter_secure_storage.',
      'Never auto-send without explicit user confirmation in-app.',
    ],
  ),
  CapabilityItem(
    id: 'messenger',
    title: 'Facebook Messenger',
    summary: 'Send and reply via Meta messaging APIs.',
    risk: CapabilityRisk.high,
    manualSteps: [
      'Create a Meta Developer app → Messenger → Webhooks.',
      'Complete Facebook Login / Page subscription; get Page Access Token.',
      'Use Graph API send API; host a verified HTTPS webhook endpoint.',
    ],
  ),
  CapabilityItem(
    id: 'tiktok_live',
    title: 'TikTok Live recordings',
    summary: 'Watch the OS save folder for finished LIVE replays.',
    risk: CapabilityRisk.low,
    manualSteps: [
      'TikTok desktop/mobile save path differs; on Windows often Videos/TikTok.',
      'Grant storage permission; configure folder path in Capabilities → Configure.',
      'This app surfaces hooks — full file watching runs best on desktop agent.',
    ],
  ),
  CapabilityItem(
    id: 'opus',
    title: 'Opus Clip upload',
    summary: 'Upload long videos to Opus Clips and fetch generated shorts.',
    risk: CapabilityRisk.medium,
    manualSteps: [
      'Create Opus Clip / partner API access if available; otherwise use browser automation on PC.',
      'Store API token in secure storage; poll job status endpoint.',
    ],
  ),
  CapabilityItem(
    id: 'obs',
    title: 'OBS Studio control',
    summary: 'Start/stop stream & recording, scenes, sources, overlays.',
    risk: CapabilityRisk.medium,
    manualSteps: [
      'Install OBS WebSocket plugin (obs-websocket v5+).',
      'Tools → WebSocket Server Settings → enable; set password.',
      'From phone: point Mordechaius desktop bridge at ws://PC_IP:4455 (run companion service on PC).',
    ],
  ),
  CapabilityItem(
    id: 'autopost',
    title: 'Auto-post clips',
    summary: 'TikTok, Instagram, YouTube with captions & schedule.',
    risk: CapabilityRisk.high,
    manualSteps: [
      'TikTok: Content Posting API (approved developer).',
      'Instagram: Graph API + Facebook Page linked.',
      'YouTube: OAuth2 YouTube Data API v3; upload with resumable upload.',
      'Each requires OAuth consent — store refresh tokens securely.',
    ],
  ),
  CapabilityItem(
    id: 'autoreply',
    title: 'Auto-reply comments & DMs',
    summary: 'TikTok, Instagram, YouTube, Facebook.',
    risk: CapabilityRisk.high,
    manualSteps: [
      'Same platform tokens as auto-post; subscribe to webhooks where supported.',
      'Rate-limit replies to avoid bans; human-review queue recommended.',
    ],
  ),
  CapabilityItem(
    id: 'smarthome_lights',
    title: 'Smart lights',
    summary: 'Control bulbs via Home Assistant (on/off, dim) from your phone through Mordecai.',
    risk: CapabilityRisk.low,
    manualSteps: [
      'Alexa-only bulbs (Echo as hub): Amazon does not give a simple HTTP API to your lights. Use one bridge: (A) Voice Monkey — create one “monkey” per action (on/off/dim) that triggers an Alexa routine controlling your room lights; copy each trigger URL into Mordecai .env as MORDECAI_ALEXA_LIGHTS_ON_URL, _OFF_, _DIM50_, _DIM100_. App → Configure → Webhook URL = https://YOUR_ORIGIN/api/capabilities/alexa-lights',
      'Or (B) Home Assistant: add lights in HA, long-lived token + MORDECAI_HOME_ASSISTANT_* in .env, webhook path /api/capabilities/smarthome',
      'Optional: set MORDECAI_SMARTHOME_WEBHOOK_SECRET on server and the same value in app Configure (API key field) so only your phone can trigger.',
      'Restart Mordecai after .env changes. Tap Test, then Execute → Turn on lights.',
    ],
  ),
  CapabilityItem(
    id: 'smarthome_thermostat',
    title: 'Thermostat',
    summary: 'Set temperature, mode (heat/cool), and schedules from your phone.',
    risk: CapabilityRisk.low,
    manualSteps: [
      'Option A: Run the Mordechaius bridge — supports Nest, Ecobee, Honeywell via Home Assistant.',
      'Option B: IFTTT + Voice Monkey — create Alexa routine "Set thermostat to 72°", trigger via webhook.',
      'Option C: Home Assistant — add Nest/Ecobee/Honeywell integration, control via REST API.',
      'Configure → Webhook URL: bridge or IFTTT Maker URL.',
    ],
  ),
  CapabilityItem(
    id: 'smarthome_alexa',
    title: 'Alexa & Echo speakers',
    summary: 'Trigger routines, control volume, play music, announce on Echo devices.',
    risk: CapabilityRisk.low,
    manualSteps: [
      'Voice Monkey (voicemonkey.io): Enable skill, create Routine Trigger devices, link Alexa routines.',
      'IFTTT: Create applets — Webhook trigger → Voice Monkey "Trigger Monkey" action.',
      'Get your IFTTT webhook URL at ifttt.com/maker_webhooks (event name = your routine trigger).',
      'Configure → Webhook URL: https://maker.ifttt.com/trigger/YOUR_EVENT/with/key/YOUR_KEY (key at ifttt.com/maker_webhooks).',
    ],
  ),
  CapabilityItem(
    id: 'email',
    title: 'Send email',
    summary: 'Send emails via SMTP, SendGrid, or your bridge — To, Subject, Body.',
    risk: CapabilityRisk.medium,
    manualSteps: [
      'Option A: Run Mordechaius bridge with SMTP or SendGrid config — webhook receives to/subject/body, bridge sends.',
      'Option B: IFTTT — Webhook trigger → Email action (IFTTT sends from your Gmail).',
      'Configure → Webhook URL: your bridge (e.g. http://YOUR_PC_IP:8765/webhook) or IFTTT Maker URL.',
      'Bridge needs SMTP credentials or SendGrid API key (env vars). Never store email passwords in the app.',
    ],
  ),
  CapabilityItem(
    id: 'drive_upload',
    title: 'Upload to Drive',
    summary: 'Tell your desktop to upload the latest APK to Google Drive — one-touch publish.',
    risk: CapabilityRisk.low,
    manualSteps: [
      'Run the Mordechaius bridge with Drive upload script (see Instruction manual → Drive sync).',
      'Bridge script: receives webhook, runs upload (rclone, gdrive, or Google Drive API) from your project build path.',
      'Configure → Webhook URL: http://YOUR_PC_IP:8765/webhook. Set folder path to APK source path if needed.',
    ],
  ),
  CapabilityItem(
    id: 'drive_download',
    title: 'Check for updates',
    summary: 'Download the latest APK from your Google Drive and install — one-touch update.',
    risk: CapabilityRisk.low,
    manualSteps: [
      'Upload APK to Drive → Share → Get link. Use direct download: https://drive.google.com/uc?export=download&id=FILE_ID.',
      'Configure → Folder path: paste the direct download URL (the uc?export=download link).',
      'Tap Execute to download and install. No webhook needed — app fetches from URL directly.',
    ],
  ),
  CapabilityItem(
    id: 'youtube_mgmt',
    title: 'YouTube channel management',
    summary: 'Schedule, descriptions, comments, thumbnails, analytics.',
    risk: CapabilityRisk.medium,
    manualSteps: [
      'Google Cloud Console → enable YouTube Data API v3.',
      'OAuth consent screen + credentials; scopes: youtube, youtube.force-ssl, yt-analytics.readonly.',
      'Thumbnail: uploads.thumbnails.set after video id known.',
    ],
  ),
];
