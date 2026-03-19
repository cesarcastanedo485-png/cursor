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
    id: 'smarthome',
    title: 'Smart home & Alexa',
    summary: 'Lights, music, volume, groups (Alexa + others).',
    risk: CapabilityRisk.medium,
    manualSteps: [
      'Alexa: create Alexa Smart Home Skill + Lambda; link account in Alexa app.',
      'Google Home: Device Access / Home Graph API.',
      'Home Assistant: local REST + long-lived token for LAN control.',
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
