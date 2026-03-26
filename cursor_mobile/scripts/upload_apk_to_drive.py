#!/usr/bin/env python3
"""
Upload an APK to Google Drive from CI.

Uses OAuth user credentials (refresh token) to upload to your personal Drive.
"""

from __future__ import annotations

import os
import sys
from typing import Tuple

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

DRIVE_SCOPE = "https://www.googleapis.com/auth/drive"
TOKEN_URI = "https://oauth2.googleapis.com/token"


def _env(name: str) -> str:
    return os.environ.get(name, "").strip()


def _fail(message: str) -> None:
    raise SystemExit(message)


def _resolve_inputs() -> Tuple[str, str]:
    folder_id = _env("GDRIVE_FOLDER_ID")
    apk_path = _env("APK_PATH")

    if not folder_id:
        _fail(
            "Missing GDRIVE_FOLDER_ID. Set it in GitHub Secrets to your Drive folder ID "
            "(from the folder URL: https://drive.google.com/drive/folders/<FOLDER_ID>)."
        )
    if not _env("GDRIVE_OAUTH_CLIENT_ID") or not _env("GDRIVE_OAUTH_CLIENT_SECRET") or not _env("GDRIVE_OAUTH_REFRESH_TOKEN"):
        _fail(
            "Missing OAuth secrets. Set GDRIVE_OAUTH_CLIENT_ID, GDRIVE_OAUTH_CLIENT_SECRET, "
            "and GDRIVE_OAUTH_REFRESH_TOKEN in GitHub Secrets. Run scripts/get_drive_refresh_token.py to get the refresh token."
        )
    if not apk_path or not os.path.exists(apk_path):
        _fail(f"APK not found: {apk_path}")

    return folder_id, apk_path


def _escape_drive_query_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "\\'")


def _resolve_target_filename(apk_path: str) -> str:
    return _env("GDRIVE_TARGET_FILENAME") or os.path.basename(apk_path)


def _pick_existing_target_file(service, folder_id: str, target_filename: str):
    safe_name = _escape_drive_query_value(target_filename)
    response = (
        service.files()
        .list(
            q=f"'{folder_id}' in parents and trashed = false and name = '{safe_name}'",
            fields="files(id,name,modifiedTime,webViewLink,webContentLink)",
            orderBy="modifiedTime desc",
            pageSize=10,
        )
        .execute()
    )
    files = response.get("files", [])
    if len(files) > 1:
        print(
            f"Found {len(files)} existing files named {target_filename!r}; "
            "updating the most recently modified one."
        )
    return files[0] if files else None


def main() -> None:
    folder_id, apk_path = _resolve_inputs()

    credentials = Credentials(
        token=None,
        refresh_token=_env("GDRIVE_OAUTH_REFRESH_TOKEN"),
        token_uri=TOKEN_URI,
        client_id=_env("GDRIVE_OAUTH_CLIENT_ID"),
        client_secret=_env("GDRIVE_OAUTH_CLIENT_SECRET"),
        scopes=[DRIVE_SCOPE],
    )
    service = build("drive", "v3", credentials=credentials)

    try:
        folder = service.files().get(
            fileId=folder_id,
            fields="id,name,mimeType",
        ).execute()
    except Exception as exc:
        _fail(
            "Cannot access GDRIVE_FOLDER_ID. Check folder ID and that the folder is in your My Drive. "
            f"Original error: {exc}"
        )

    if folder.get("mimeType") != "application/vnd.google-apps.folder":
        _fail(
            "GDRIVE_FOLDER_ID is not a folder. Use the folder ID from the Drive URL."
        )

    print(f"Drive folder access OK: {folder.get('name')} ({folder.get('id')})")

    target_filename = _resolve_target_filename(apk_path)
    file_metadata = {"name": target_filename, "parents": [folder_id]}
    media = MediaFileUpload(apk_path, mimetype="application/vnd.android.package-archive", resumable=True)
    existing_file = _pick_existing_target_file(service, folder_id, target_filename)

    if existing_file:
        updated = (
            service.files()
            .update(
                fileId=existing_file["id"],
                body={"name": target_filename},
                media_body=media,
                fields="id,name,webViewLink,webContentLink",
            )
            .execute()
        )
        print("Updated existing Google Drive APK:")
        print(f"  id={updated.get('id')}")
        print(f"  name={updated.get('name')}")
        print(f"  webViewLink={updated.get('webViewLink')}")
        return

    created = (
        service.files()
        .create(
            body=file_metadata,
            media_body=media,
            fields="id,name,webViewLink,webContentLink",
        )
        .execute()
    )
    print("Uploaded new APK to Google Drive:")
    print(f"  id={created.get('id')}")
    print(f"  name={created.get('name')}")
    print(f"  webViewLink={created.get('webViewLink')}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
