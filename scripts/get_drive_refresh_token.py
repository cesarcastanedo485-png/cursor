#!/usr/bin/env python3
"""
One-time script to get a Google Drive OAuth refresh token for Mordechaius Maximus.

Run this once, authorize in the browser, then add the printed refresh token
to GitHub Secrets as GDRIVE_OAUTH_REFRESH_TOKEN.

Usage:
  python scripts/get_drive_refresh_token.py

Or with env vars:
  set GDRIVE_OAUTH_CLIENT_ID=your-client-id
  set GDRIVE_OAUTH_CLIENT_SECRET=your-client-secret
  python scripts/get_drive_refresh_token.py
"""

import json
import os
import sys

try:
    from google_auth_oauthlib.flow import InstalledAppFlow
except ImportError:
    print("Install the package first: pip install google-auth-oauthlib")
    sys.exit(1)

SCOPES = ["https://www.googleapis.com/auth/drive"]
PORT = 8080


def main():
    client_id = os.environ.get("GDRIVE_OAUTH_CLIENT_ID", "").strip()
    client_secret = os.environ.get("GDRIVE_OAUTH_CLIENT_SECRET", "").strip()

    if not client_id or not client_secret:
        print("Set GDRIVE_OAUTH_CLIENT_ID and GDRIVE_OAUTH_CLIENT_SECRET (env vars or paste when prompted).")
        if not client_id:
            client_id = input("Client ID: ").strip()
        if not client_secret:
            client_secret = input("Client secret: ").strip()
        if not client_id or not client_secret:
            print("Both are required.")
            sys.exit(1)

    redirect_uri = f"http://localhost:{PORT}/"
    client_config = {
        "installed": {
            "client_id": client_id,
            "client_secret": client_secret,
            "redirect_uris": [redirect_uri, "http://localhost"],
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
        }
    }

    print(f"Add this redirect URI to your OAuth client if needed: {redirect_uri}")
    print("(Desktop app often has localhost already. Opening browser...)\n")

    flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
    creds = flow.run_local_server(port=PORT)

    if creds.refresh_token:
        print("\n" + "=" * 60)
        print("REFRESH TOKEN (add to GitHub Secrets as GDRIVE_OAUTH_REFRESH_TOKEN):")
        print("=" * 60)
        print(creds.refresh_token)
        print("=" * 60)
    else:
        print("No refresh token returned. Re-run and make sure to grant full access.")
        sys.exit(1)


if __name__ == "__main__":
    main()
