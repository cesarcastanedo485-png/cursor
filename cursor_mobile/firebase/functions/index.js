/**
 * Mordechaius Maximus — Firebase Cloud Functions
 *
 * Deploy: cd firebase && firebase deploy --only functions
 * Test: Send POST to the function URL with { token, agentId?, message? }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const webhookSecret = (process.env.MORDECAI_FCM_WEBHOOK_SECRET || '').trim();

/**
 * Sends an "Agent Completed" push notification to the given FCM token.
 *
 * Call via HTTP:
 *   POST /sendAgentCompletedPush
 *   Body: { "token": "<fcm_token>", "agentId": "agent_xyz", "message": "Task X finished" }
 *
 * Or from Firebase Console → Cloud Messaging → Send test message (use token from app logs).
 */
exports.sendAgentCompletedPush = functions.https.onRequest(async (req, res) => {
  const allowedOrigin = process.env.MORDECAI_FCM_ALLOWED_ORIGIN || '';
  if (allowedOrigin) {
    res.set('Access-Control-Allow-Origin', allowedOrigin);
  }
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, X-Fcm-Webhook-Secret, X-Mordecai-Request-Id');
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (webhookSecret) {
    const header = (req.get('X-Fcm-Webhook-Secret') || '').trim();
    if (!header || header !== webhookSecret) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
  }

  const {
    token,
    agentId,
    message,
    title,
    type,
    id,
    eventId,
    messagePreview,
    threadId,
  } = req.body || {};

  if (!token || typeof token !== 'string') {
    res.status(400).json({ error: 'token required' });
    return;
  }

  const notifType = (type || '').toString().trim().toLowerCase();
  const defaultTitle =
    notifType === 'assistant_message'
      ? 'Agent message'
      : notifType === 'agent_creating'
      ? 'Agent starting'
      : notifType === 'agent_running'
      ? 'Agent running'
      : notifType === 'agent_expired'
      ? 'Agent expired'
      : 'Agent finished';
  const notifTitle = (title && String(title).trim()) || defaultTitle;
  const notifBody =
    message ||
    messagePreview ||
    (notifType === 'assistant_message'
      ? 'Your agent sent a new message.'
      : notifType === 'agent_expired'
      ? 'Your agent is no longer available.'
      : 'Your agent has an update.');

  try {
    await admin.messaging().send({
      token: token.trim(),
      notification: {
        title: notifTitle,
        body: notifBody,
      },
      data: {
        type: notifType || 'agent_finished',
        id: id || agentId || '',
        agentId: agentId || id || '',
        eventId: eventId ? String(eventId) : '',
        messagePreview: messagePreview ? String(messagePreview) : '',
        threadId: threadId ? String(threadId) : '',
      },
      android: {
        priority: 'high',
      },
    });
    res.json({ ok: true });
  } catch (e) {
    console.error('Send push error:', e);
    res.status(500).json({ error: e.message || 'Failed to send' });
  }
});
