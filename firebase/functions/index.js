/**
 * Mordechaius Maximus — Firebase Cloud Functions
 *
 * Deploy: cd firebase && firebase deploy --only functions
 * Test: Send POST to the function URL with { token, agentId?, message? }
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

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
  // CORS for web clients
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const { token, agentId, message, type } = req.body || {};

  if (!token || typeof token !== 'string') {
    res.status(400).json({ error: 'token required' });
    return;
  }

  const isError = type === 'agent_error';
  const notifTitle = isError ? 'Agent Error' : 'Agent Completed';

  try {
    await admin.messaging().send({
      token: token.trim(),
      notification: {
        title: notifTitle,
        body: message || (isError ? 'Desktop agent encountered an error.' : 'Your agent finished.'),
      },
      data: {
        type: isError ? 'agent_error' : 'agent_completed',
        id: agentId || '',
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
