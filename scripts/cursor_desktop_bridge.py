#!/usr/bin/env python3
"""
Mordecai Cursor Desktop Bridge

Polls Mordecai for agent tasks when Cursor is closed. When a task arrives:
- Copies prompt to system clipboard
- Shows OS notification: "New Mordecai task – open Cursor to run"

Run on your desktop so you get notified even when Cursor isn't open.
The Cursor extension will pick up tasks when you open Cursor.

Setup:
  pip install requests pyperclip plyer

  export MORDECAI_URL=https://your-tunnel.trycloudflare.com
  export MORDECAI_BRIDGE_SECRET=your-secret  # optional, must match server

  python cursor_desktop_bridge.py

For a stable Mordecai URL, use Cloudflare Tunnel or similar. See mordecai-maximus/docs/DEPLOYMENT.md.
"""

import json
import os
import sys
import time
import uuid
from pathlib import Path

import requests

MORDECAI_URL = os.environ.get("MORDECAI_URL", "").rstrip("/")
BRIDGE_SECRET = os.environ.get("MORDECAI_BRIDGE_SECRET", "").strip()
POLL_INTERVAL = int(os.environ.get("MORDECAI_POLL_INTERVAL", "30"))
PENDING_TASK_PATH = Path.home() / ".mordecai" / "pending_task.json"

_device_id = None


def _get_device_id() -> str:
    global _device_id
    if _device_id:
        return _device_id
    pid_path = Path.home() / ".mordecai" / "device_id.txt"
    pid_path.parent.mkdir(parents=True, exist_ok=True)
    if pid_path.exists():
        _device_id = pid_path.read_text().strip()
    else:
        _device_id = "bridge-" + str(uuid.uuid4())[:12]
        pid_path.write_text(_device_id)
    return _device_id


def _poll() -> dict | None:
    if not MORDECAI_URL:
        return None
    url = f"{MORDECAI_URL}/api/bridge/tasks/poll"
    params = {"deviceId": _get_device_id()}
    headers = {"Accept": "application/json"}
    if BRIDGE_SECRET:
        headers["X-Bridge-Secret"] = BRIDGE_SECRET
    try:
        r = requests.get(url, params=params, headers=headers, timeout=15)
        if r.status_code == 204:
            return None
        if r.status_code == 200:
            return r.json()
    except requests.RequestException:
        pass
    return None


def _copy_to_clipboard(text: str) -> bool:
    try:
        import pyperclip

        pyperclip.copy(text)
        return True
    except Exception:
        return False


def _show_notification(title: str, body: str) -> bool:
    try:
        from plyer import notification

        notification.notify(title=title, message=body, app_name="Mordecai")
        return True
    except Exception:
        return False


def _write_pending_task(task: dict) -> None:
    try:
        PENDING_TASK_PATH.parent.mkdir(parents=True, exist_ok=True)
        PENDING_TASK_PATH.write_text(json.dumps(task, indent=2))
    except Exception:
        pass


def main() -> None:
    if not MORDECAI_URL:
        print("Set MORDECAI_URL to your Mordecai server URL (e.g. from Cloudflare Tunnel)")
        sys.exit(1)

    print(f"Mordecai Cursor bridge polling {MORDECAI_URL} every {POLL_INTERVAL}s")
    print("Device ID:", _get_device_id())
    print("Press Ctrl+C to stop")
    print()

    while True:
        task = _poll()
        if task:
            prompt = task.get("prompt", "")
            task_id = task.get("taskId", "")
            _copy_to_clipboard(prompt)
            _show_notification(
                "New Mordecai task",
                "Open Cursor to run. Prompt copied to clipboard.",
            )
            _write_pending_task(task)
            print(f"Task {task_id[:20]}... received, copied to clipboard")
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
