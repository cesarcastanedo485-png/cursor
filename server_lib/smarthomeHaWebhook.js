/**
 * Phone → Mordecai → Home Assistant bridge for Capabilities tab (smart home).
 * Expects the JSON body from the Flutter app (CapabilityService): action, capability, api_key, folder_path, …
 */

function trim(s) {
  return String(s ?? "").trim();
}

function unauthorized(res) {
  res.status(401).json({ error: "Invalid api_key (must match MORDECAI_SMARTHOME_WEBHOOK_SECRET)" });
}

function requireWebhookSecret(req, res) {
  const expected = trim(process.env.MORDECAI_SMARTHOME_WEBHOOK_SECRET);
  if (!expected) return true;
  const got = trim(req.body?.api_key);
  if (got !== expected) {
    unauthorized(res);
    return false;
  }
  return true;
}

function haConfig() {
  const haUrl = trim(process.env.MORDECAI_HOME_ASSISTANT_URL).replace(/\/$/, "");
  const haToken = trim(process.env.MORDECAI_HOME_ASSISTANT_TOKEN);
  return { haUrl, haToken, ok: Boolean(haUrl && haToken) };
}

function entityFromBody(body, envKey) {
  const fromApp = trim(body?.folder_path);
  if (fromApp) return fromApp;
  return trim(process.env[envKey]);
}

async function haCallService(haUrl, haToken, domain, service, data) {
  const url = `${haUrl}/api/services/${domain}/${service}`;
  const r = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${haToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });
  if (!r.ok) {
    const t = await r.text();
    throw new Error(`Home Assistant ${r.status}: ${t || r.statusText}`);
  }
  const ct = r.headers.get("content-type") || "";
  if (ct.includes("application/json")) {
    try {
      return await r.json();
    } catch (_) {
      return {};
    }
  }
  return {};
}

/**
 * POST /api/capabilities/smarthome
 */
export async function smarthomeHaWebhookHandler(req, res) {
  if (!requireWebhookSecret(req, res)) return;

  const { haUrl, haToken, ok } = haConfig();
  if (!ok) {
    return res.status(503).json({
      error:
        "Home Assistant not configured. Set MORDECAI_HOME_ASSISTANT_URL and MORDECAI_HOME_ASSISTANT_TOKEN in server .env",
    });
  }

  const action = trim(req.body?.action);
  const capability = trim(req.body?.capability);

  if (action === "ping") {
    try {
      const r = await fetch(`${haUrl}/api/`, {
        headers: { Authorization: `Bearer ${haToken}` },
      });
      if (!r.ok) {
        const t = await r.text();
        return res.status(502).json({ error: `Home Assistant unreachable: ${r.status} ${t}` });
      }
      return res.json({ ok: true, homeAssistant: true });
    } catch (e) {
      return res.status(502).json({ error: e.message || "Home Assistant ping failed" });
    }
  }

  try {
    // —— Lights (capability smarthome_lights or action prefix lights_) ——
    if (capability === "smarthome_lights" || action.startsWith("lights_")) {
      const entity = entityFromBody(req.body, "MORDECAI_HOME_ASSISTANT_LIGHT_ENTITY");
      if (!entity) {
        return res.status(400).json({
          error:
            "No light entity. Set MORDECAI_HOME_ASSISTANT_LIGHT_ENTITY in server .env or enter a HA entity id in Configure (folder path field).",
        });
      }
      switch (action) {
        case "lights_on":
          await haCallService(haUrl, haToken, "light", "turn_on", { entity_id: entity });
          break;
        case "lights_off":
          await haCallService(haUrl, haToken, "light", "turn_off", { entity_id: entity });
          break;
        case "lights_dim_50":
          await haCallService(haUrl, haToken, "light", "turn_on", {
            entity_id: entity,
            brightness_pct: 50,
          });
          break;
        case "lights_dim_100":
          await haCallService(haUrl, haToken, "light", "turn_on", {
            entity_id: entity,
            brightness_pct: 100,
          });
          break;
        default:
          return res.status(400).json({ error: `Unknown light action: ${action}` });
      }
      return res.json({ ok: true, entity });
    }

    // —— Thermostat (optional) ——
    if (capability === "smarthome_thermostat" || action.startsWith("thermostat_")) {
      const entity = entityFromBody(req.body, "MORDECAI_HOME_ASSISTANT_CLIMATE_ENTITY");
      if (!entity) {
        return res.status(400).json({
          error:
            "No climate entity. Set MORDECAI_HOME_ASSISTANT_CLIMATE_ENTITY in server .env or use Configure entity field.",
        });
      }
      switch (action) {
        case "thermostat_70":
          await haCallService(haUrl, haToken, "climate", "set_temperature", {
            entity_id: entity,
            temperature: 70,
          });
          break;
        case "thermostat_72":
          await haCallService(haUrl, haToken, "climate", "set_temperature", {
            entity_id: entity,
            temperature: 72,
          });
          break;
        case "thermostat_74":
          await haCallService(haUrl, haToken, "climate", "set_temperature", {
            entity_id: entity,
            temperature: 74,
          });
          break;
        case "thermostat_heat":
          await haCallService(haUrl, haToken, "climate", "set_hvac_mode", {
            entity_id: entity,
            hvac_mode: "heat",
          });
          break;
        case "thermostat_cool":
          await haCallService(haUrl, haToken, "climate", "set_hvac_mode", {
            entity_id: entity,
            hvac_mode: "cool",
          });
          break;
        default:
          return res.status(400).json({ error: `Unknown thermostat action: ${action}` });
      }
      return res.json({ ok: true, entity });
    }

    if (action.startsWith("alexa_")) {
      return res.status(501).json({
        error: "Alexa actions are not implemented on the Mordecai server. Use an IFTTT/Voice Monkey webhook URL instead.",
      });
    }

    return res.status(400).json({
      error: `No handler for capability "${capability}" and action "${action}". Use Smart lights or Smart thermostat.`,
    });
  } catch (e) {
    return res.status(500).json({ error: e.message || "Home Assistant request failed" });
  }
}
