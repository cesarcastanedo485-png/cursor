#!/usr/bin/env python3
"""
Mordechaius Maximus Smart Home Bridge

Receives webhooks from the mobile app and forwards to Home Assistant or IFTTT.
Run on a PC/Raspberry Pi on your LAN so your phone can reach it.

Setup:
  pip install flask requests

  # Option A: Home Assistant
  export HA_URL=http://192.168.1.10:8123
  export HA_TOKEN=your_long_lived_token
  export HA_LIGHT_ENTITY=light.living_room    # or light.group_all
  export HA_THERMOSTAT_ENTITY=climate.home   # Nest, Ecobee, etc.

  # Option B: IFTTT (Voice Monkey for Alexa routines)
  export IFTTT_KEY=your_ifttt_webhook_key

  python smarthome_bridge.py

Then in the app: Configure → Webhook URL = http://YOUR_PC_IP:8765/webhook

Get your PC IP: Windows: run `ipconfig` → IPv4 Address under your adapter.
  Linux/Mac: run `hostname -I` or `ip addr`.
"""

import os
import smtplib
import subprocess
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from http import HTTPStatus

import requests
from flask import Flask, request, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

HA_URL = os.environ.get("HA_URL", "").rstrip("/")
HA_TOKEN = os.environ.get("HA_TOKEN", "")
HA_LIGHT_ENTITY = os.environ.get("HA_LIGHT_ENTITY", "light.living_room")
HA_THERMOSTAT_ENTITY = os.environ.get("HA_THERMOSTAT_ENTITY", "climate.thermostat")
IFTTT_KEY = os.environ.get("IFTTT_KEY", "")

# Email (SMTP)
EMAIL_SMTP_HOST = os.environ.get("EMAIL_SMTP_HOST", "")
EMAIL_SMTP_PORT = int(os.environ.get("EMAIL_SMTP_PORT", "587"))
EMAIL_FROM = os.environ.get("EMAIL_FROM", "")
EMAIL_PASSWORD = os.environ.get("EMAIL_PASSWORD", "")

# Drive upload: local APK path override, or rclone remote:path
DRIVE_APK_PATH = os.environ.get("DRIVE_APK_PATH", "")
RCLONE_CMD = os.environ.get("RCLONE_CMD", "")  # e.g. "rclone copy C:/apk remote:Mordechaius"


def _ha_headers():
    return {"Authorization": f"Bearer {HA_TOKEN}", "Content-Type": "application/json"}


def _call_ha_service(domain: str, service: str, data: dict) -> tuple[bool, str]:
    if not HA_URL or not HA_TOKEN:
        return False, "HA_URL and HA_TOKEN not configured"
    url = f"{HA_URL}/api/services/{domain}/{service}"
    try:
        r = requests.post(url, headers=_ha_headers(), json=data, timeout=10)
        if r.status_code in (200, 201):
            return True, ""
        return False, f"HA returned {r.status_code}: {r.text[:200]}"
    except requests.RequestException as e:
        return False, str(e)


def _call_ifttt(event: str, value1: str = "", value2: str = "", value3: str = "") -> tuple[bool, str]:
    if not IFTTT_KEY:
        return False, "IFTTT_KEY not configured"
    url = f"https://maker.ifttt.com/trigger/{event}/with/key/{IFTTT_KEY}"
    try:
        r = requests.post(
            url,
            json={"value1": value1, "value2": value2, "value3": value3},
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        if r.status_code == 200:
            return True, ""
        return False, f"IFTTT returned {r.status_code}: {r.text[:200]}"
    except requests.RequestException as e:
        return False, str(e)


def _handle_smart_home_action(action: str, payload: dict) -> tuple[bool, str]:
    """Route smart_home_action to HA or IFTTT."""
    # Try Home Assistant first if configured
    if HA_URL and HA_TOKEN:
        ok, err = _handle_ha_action(action, payload)
        if ok:
            return True, ""
        if "not configured" not in err.lower():
            logger.warning("HA call failed: %s", err)

    # Fallback to IFTTT (works with Voice Monkey for Alexa routines)
    if IFTTT_KEY:
        return _call_ifttt(action, payload.get("capability_title", ""), "", "")

    return False, "Configure HA_URL+HA_TOKEN or IFTTT_KEY. See script docstring."


def _handle_ha_action(action: str, payload: dict) -> tuple[bool, str]:
    """Execute action via Home Assistant REST API."""
    if action == "lights_on":
        return _call_ha_service("light", "turn_on", {"entity_id": HA_LIGHT_ENTITY})
    if action == "lights_off":
        return _call_ha_service("light", "turn_off", {"entity_id": HA_LIGHT_ENTITY})
    if action == "lights_dim_50":
        return _call_ha_service(
            "light", "turn_on", {"entity_id": HA_LIGHT_ENTITY, "brightness_pct": 50}
        )
    if action == "lights_dim_100":
        return _call_ha_service(
            "light", "turn_on", {"entity_id": HA_LIGHT_ENTITY, "brightness_pct": 100}
        )
    if action == "thermostat_70":
        return _call_ha_service(
            "climate", "set_temperature",
            {"entity_id": HA_THERMOSTAT_ENTITY, "temperature": 70},
        )
    if action == "thermostat_72":
        return _call_ha_service(
            "climate", "set_temperature",
            {"entity_id": HA_THERMOSTAT_ENTITY, "temperature": 72},
        )
    if action == "thermostat_74":
        return _call_ha_service(
            "climate", "set_temperature",
            {"entity_id": HA_THERMOSTAT_ENTITY, "temperature": 74},
        )
    if action == "thermostat_heat":
        return _call_ha_service(
            "climate", "set_hvac_mode",
            {"entity_id": HA_THERMOSTAT_ENTITY, "hvac_mode": "heat"},
        )
    if action == "thermostat_cool":
        return _call_ha_service(
            "climate", "set_hvac_mode",
            {"entity_id": HA_THERMOSTAT_ENTITY, "hvac_mode": "cool"},
        )
    # Alexa actions (volume, routine) - IFTTT/Voice Monkey handles these
    if action in ("alexa_routine", "alexa_volume_up", "alexa_volume_down"):
        return False, "Use IFTTT + Voice Monkey for Alexa. Set IFTTT_KEY."
    return False, f"Unknown action: {action}"


def _send_email_smtp(to: str, subject: str, body: str) -> tuple[bool, str]:
    if not all([EMAIL_SMTP_HOST, EMAIL_FROM, EMAIL_PASSWORD]):
        return False, "Set EMAIL_SMTP_HOST, EMAIL_FROM, EMAIL_PASSWORD"
    try:
        msg = MIMEMultipart()
        msg["From"] = EMAIL_FROM
        msg["To"] = to
        msg["Subject"] = subject
        msg.attach(MIMEText(body or "", "plain", "utf-8"))
        with smtplib.SMTP(EMAIL_SMTP_HOST, EMAIL_SMTP_PORT, timeout=30) as s:
            s.starttls()
            s.login(EMAIL_FROM, EMAIL_PASSWORD)
            s.sendmail(EMAIL_FROM, [to], msg.as_string())
        return True, ""
    except Exception as e:
        return False, str(e)


def _handle_drive_upload(payload: dict) -> tuple[bool, str]:
    """Upload APK to Drive via RCLONE_CMD or placeholder instructions."""
    folder_path = (payload.get("folder_path") or "").strip()
    apk = folder_path or DRIVE_APK_PATH
    if RCLONE_CMD:
        try:
            cmd = RCLONE_CMD
            if apk and "{apk}" in cmd:
                cmd = cmd.replace("{apk}", apk)
            subprocess.run(cmd, shell=True, check=True, timeout=120)
            return True, ""
        except Exception as e:
            return False, str(e)
    if not apk:
        return False, "Set folder_path in app Configure or DRIVE_APK_PATH env, and RCLONE_CMD for upload"
    return False, f"Configure RCLONE_CMD e.g. rclone copy \"{apk}\" gdrive:Mordechaius - See scripts README"


@app.route("/webhook", methods=["POST"])
def webhook():
    """Receive webhook from Mordechaius Maximus app."""
    try:
        data = request.get_json(force=True, silent=True) or {}
    except Exception:
        data = {}
    action = (data.get("action") or data.get("smart_home_action") or "run").strip()
    capability = data.get("capability", "")

    # Ping check
    if action == "ping":
        return jsonify({"status": "ok", "message": "Bridge running"}), HTTPStatus.OK

    # Send email
    if capability == "email" and action == "send_email":
        to = (data.get("email_to") or "").strip()
        subject = (data.get("email_subject") or "").strip()
        body = (data.get("email_body") or "").strip()
        if not to:
            return jsonify({"error": "Missing email_to"}), HTTPStatus.BAD_REQUEST
        ok, err = _send_email_smtp(to, subject, body)
        if ok:
            logger.info("Email sent to %s", to)
            return jsonify({"status": "ok"}), HTTPStatus.OK
        return jsonify({"error": err}), HTTPStatus.BAD_REQUEST

    # Upload APK to Drive
    if capability == "drive_upload" and action == "upload_apk":
        ok, err = _handle_drive_upload(data)
        if ok:
            logger.info("Drive upload ok")
            return jsonify({"status": "ok"}), HTTPStatus.OK
        return jsonify({"error": err}), HTTPStatus.BAD_REQUEST

    ok, err = _handle_smart_home_action(action, data)
    if ok:
        logger.info("Executed %s for %s", action, capability)
        return jsonify({"status": "ok"}), HTTPStatus.OK
    logger.error("Failed %s: %s", action, err)
    return jsonify({"error": err}), HTTPStatus.BAD_REQUEST


@app.route("/health")
def health():
    return jsonify({"status": "ok"}), HTTPStatus.OK


def main():
    port = int(os.environ.get("PORT", 8765))
    has_ha = bool(HA_URL and HA_TOKEN)
    has_ifttt = bool(IFTTT_KEY)
    if not has_ha and not has_ifttt:
        logger.warning(
            "Neither HA nor IFTTT configured. Set HA_URL+HA_TOKEN or IFTTT_KEY. "
            "Bridge will accept requests but return errors."
        )
    else:
        logger.info("Bridge ready. HA=%s IFTTT=%s", has_ha, has_ifttt)
    app.run(host="0.0.0.0", port=port, debug=False)


if __name__ == "__main__":
    main()
