/**
 * Alexa-only smart lights: maps app actions to HTTP trigger URLs (Voice Monkey, IFTTT, etc.).
 * Configure one URL per action in .env; point the app webhook to POST /api/capabilities/alexa-lights
 */

function trim(s) {
  return String(s ?? "").trim();
}

function requireWebhookSecret(req, res) {
  const expected = trim(process.env.MORDECAI_SMARTHOME_WEBHOOK_SECRET);
  if (!expected) return true;
  const got = trim(req.body?.api_key);
  if (got !== expected) {
    res.status(401).json({ error: "Invalid api_key (must match MORDECAI_SMARTHOME_WEBHOOK_SECRET)" });
    return false;
  }
  return true;
}

const ACTION_ENV_KEYS = {
  lights_on: "MORDECAI_ALEXA_LIGHTS_ON_URL",
  lights_off: "MORDECAI_ALEXA_LIGHTS_OFF_URL",
  lights_dim_50: "MORDECAI_ALEXA_LIGHTS_DIM50_URL",
  lights_dim_100: "MORDECAI_ALEXA_LIGHTS_DIM100_URL",
};

function urlForAction(action) {
  const key = ACTION_ENV_KEYS[action];
  return key ? trim(process.env[key]) : "";
}

function anyUrlConfigured() {
  return Object.keys(ACTION_ENV_KEYS).some((a) => urlForAction(a));
}

/**
 * POST /api/capabilities/alexa-lights
 */
export async function alexaLightsWebhookHandler(req, res) {
  if (!requireWebhookSecret(req, res)) return;

  const action = trim(req.body?.action);
  const capability = trim(req.body?.capability);

  if (action === "ping") {
    if (!anyUrlConfigured()) {
      return res.status(503).json({
        error:
          "Alexa trigger URLs not set. Add MORDECAI_ALEXA_LIGHTS_ON_URL (and other actions) in server .env.",
      });
    }
    return res.json({ ok: true, alexaWebhookBridge: true });
  }

  if (capability && capability !== "smarthome_lights") {
    return res.status(400).json({
      error: "This endpoint is for Smart lights (smarthome_lights) only.",
    });
  }

  if (!action.startsWith("lights_")) {
    return res.status(400).json({ error: `Unsupported action for Alexa bridge: ${action}` });
  }

  const url = urlForAction(action);
  if (!url) {
    const envKey = ACTION_ENV_KEYS[action] || "";
    return res.status(400).json({
      error: `No URL for "${action}". Set ${envKey} in Mordecai server .env (Voice Monkey / IFTTT trigger URL).`,
    });
  }

  const method = trim(process.env.MORDECAI_ALEXA_TRIGGER_METHOD || "GET").toUpperCase() || "GET";

  try {
    const r = await fetch(url, {
      method: method === "POST" ? "POST" : "GET",
      headers: method === "POST" ? { "Content-Type": "application/json" } : {},
      body: method === "POST" ? JSON.stringify({ action, source: "mordecai" }) : undefined,
      redirect: "follow",
    });
    if (!r.ok) {
      const t = await r.text();
      return res.status(502).json({
        error: `Trigger URL returned ${r.status}: ${t.slice(0, 200)}`,
      });
    }
    return res.json({ ok: true, action });
  } catch (e) {
    return res.status(502).json({ error: e.message || "Failed to call Alexa trigger URL" });
  }
}
