#!/usr/bin/env python3
"""
Upload an APK to Google Drive from CI.

Supported auth modes:
1) Service account (recommended with Shared Drives)
2) OAuth user refresh token (uploads into a real user account with quota)

Optional:
- Domain-wide delegation via GDRIVE_IMPERSONATED_USER when using service account.
"""

from __future__ import annotations

import json
import os
import sys
from typing import Tuple

from google.oauth2 import service_account
from google.oauth2.credentials import Credentials as UserCredentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

DRIVE_SCOPE = "https://www.googleapis.com/auth/drive"
TOKEN_URI_DEFAULT = "https://oauth2.googleapis.com/token"


def _env(name: str) -> str:
    return os.environ.get(name, "").strip()


def _fail(message: str) -> None:
    raise SystemExit(message)


def _detect_auth_mode() -> str:
    auth_mode = _env("GDRIVE_AUTH_MODE").lower()
    has_oauth = all(
        [_env("GDRIVE_OAUTH_CLIENT_ID"), _env("GDRIVE_OAUTH_CLIENT_SECRET"), _env("GDRIVE_OAUTH_REFRESH_TOKEN")]
    )
    has_service_account = bool(_env("GDRIVE_SERVICE_ACCOUNT_JSON"))

    if auth_mode:
        valid = {"oauth_user", "service_account"}
        if auth_mode not in valid:
            _fail(f"Invalid GDRIVE_AUTH_MODE={auth_mode!r}. Use one of: {sorted(valid)}")
        if auth_mode == "oauth_user" and not has_oauth:
            _fail(
                "GDRIVE_AUTH_MODE=oauth_user requires "
                "GDRIVE_OAUTH_CLIENT_ID, GDRIVE_OAUTH_CLIENT_SECRET, and GDRIVE_OAUTH_REFRESH_TOKEN."
            )
        if auth_mode == "service_account" and not has_service_account:
            _fail("GDRIVE_AUTH_MODE=service_account requires GDRIVE_SERVICE_ACCOUNT_JSON.")
        return auth_mode

    if has_oauth:
        return "oauth_user"
    if has_service_account:
        return "service_account"

    _fail(
        "No Google Drive auth credentials configured. Set either:\n"
        "- OAuth user secrets: GDRIVE_OAUTH_CLIENT_ID, GDRIVE_OAUTH_CLIENT_SECRET, GDRIVE_OAUTH_REFRESH_TOKEN\n"
        "- or service account secret: GDRIVE_SERVICE_ACCOUNT_JSON"
    )
    return ""


def _build_credentials(auth_mode: str):
    if auth_mode == "oauth_user":
        return UserCredentials(
            token=None,
            refresh_token=_env("GDRIVE_OAUTH_REFRESH_TOKEN"),
            token_uri=_env("GDRIVE_OAUTH_TOKEN_URI") or TOKEN_URI_DEFAULT,
            client_id=_env("GDRIVE_OAUTH_CLIENT_ID"),
            client_secret=_env("GDRIVE_OAUTH_CLIENT_SECRET"),
            scopes=[DRIVE_SCOPE],
        )

    info = json.loads(_env("GDRIVE_SERVICE_ACCOUNT_JSON"))
    subject = _env("GDRIVE_IMPERSONATED_USER") or None
    return service_account.Credentials.from_service_account_info(info, scopes=[DRIVE_SCOPE], subject=subject)


def _resolve_inputs() -> Tuple[str, str, str]:
    folder_id = _env("GDRIVE_FOLDER_ID")
    apk_path = _env("APK_PATH")
    shared_drive_id = _env("GDRIVE_SHARED_DRIVE_ID")

    if not folder_id:
        _fail("Missing GDRIVE_FOLDER_ID (must be target Drive folder ID).")
    if not apk_path or not os.path.exists(apk_path):
        _fail(f"APK not found: {apk_path}")

    return folder_id, apk_path, shared_drive_id


def _escape_drive_query_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "\\'")


def _resolve_target_filename(apk_path: str) -> str:
    return _env("GDRIVE_TARGET_FILENAME") or os.path.basename(apk_path)


def _pick_existing_target_file(service, folder_id: str, target_filename: str):
    target_file_id = _env("GDRIVE_TARGET_FILE_ID")
    if target_file_id:
        selected = (
            service.files()
            .get(
                fileId=target_file_id,
                fields="id,name,parents,webViewLink,webContentLink",
                supportsAllDrives=True,
            )
            .execute()
        )
        parents = selected.get("parents") or []
        if folder_id not in parents:
            _fail(
                "GDRIVE_TARGET_FILE_ID is not inside GDRIVE_FOLDER_ID. "
                "Use a file in the target folder, or unset GDRIVE_TARGET_FILE_ID."
            )
        return selected

    safe_name = _escape_drive_query_value(target_filename)
    response = (
        service.files()
        .list(
            q=f"'{folder_id}' in parents and trashed = false and name = '{safe_name}'",
            fields="files(id,name,modifiedTime,webViewLink,webContentLink)",
            includeItemsFromAllDrives=True,
            supportsAllDrives=True,
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


def _validate_folder_context(folder: dict, auth_mode: str, shared_drive_id: str) -> None:
    folder_mime = folder.get("mimeType")
    folder_drive_id = folder.get("driveId") or ""

    if folder_mime != "application/vnd.google-apps.folder":
        _fail(
            f"GDRIVE_FOLDER_ID is not a folder (mimeType={folder_mime}). "
            "Use the folder ID from the Drive URL."
        )

    if shared_drive_id:
        if not folder_drive_id:
            _fail(
                "GDRIVE_SHARED_DRIVE_ID is set, but target folder is not in a Shared Drive. "
                "Use a Shared Drive folder, or remove GDRIVE_SHARED_DRIVE_ID."
            )
        if folder_drive_id != shared_drive_id:
            _fail(
                "Shared Drive mismatch: folder.driveId does not equal GDRIVE_SHARED_DRIVE_ID. "
                f"folder.driveId={folder_drive_id}, expected={shared_drive_id}"
            )

    impersonated_user = _env("GDRIVE_IMPERSONATED_USER")
    if auth_mode == "service_account" and not folder_drive_id and not impersonated_user:
        _fail(
            "Service account cannot write to My Drive (personal storage).\n"
            "Your GDRIVE_FOLDER_ID points to a folder in My Drive.\n\n"
            "Use one of:\n"
            "1) SHARED DRIVE: Create a Shared Drive, add the service account as member (Writer/Content manager), "
            "create APKS folder inside it, and use that folder ID. See docs/SETUP_DRIVE_APK.md.\n"
            "2) OAUTH: Use GDRIVE_OAUTH_* secrets (refresh token) to upload to your personal Drive.\n"
            "3) DOMAIN DELEGATION: Set GDRIVE_IMPERSONATED_USER (Google Workspace admin only)."
        )


def main() -> None:
    auth_mode = _detect_auth_mode()
    folder_id, apk_path, shared_drive_id = _resolve_inputs()
    credentials = _build_credentials(auth_mode)
    service = build("drive", "v3", credentials=credentials)

    try:
        folder = service.files().get(
            fileId=folder_id,
            fields="id,name,mimeType,driveId,parents",
            supportsAllDrives=True,
        ).execute()
    except Exception as exc:
        _fail(
            "Cannot access GDRIVE_FOLDER_ID. Check folder ID and permissions for selected auth mode. "
            f"Original error: {exc}"
        )

    _validate_folder_context(folder, auth_mode, shared_drive_id)
    folder_drive_id = folder.get("driveId") or "My Drive"
    print(f"Drive folder access OK: {folder.get('name')} ({folder.get('id')}) in {folder_drive_id}")
    print(f"Auth mode: {auth_mode}")

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
                fields="id,name,webViewLink,webContentLink,parents,driveId",
                supportsAllDrives=True,
            )
            .execute()
        )
        print("Updated existing Google Drive APK:")
        print(f"id={updated.get('id')}")
        print(f"name={updated.get('name')}")
        print(f"webViewLink={updated.get('webViewLink')}")
        print(f"webContentLink={updated.get('webContentLink')}")
        return

    created = (
        service.files()
        .create(
            body=file_metadata,
            media_body=media,
            fields="id,name,webViewLink,webContentLink,parents,driveId",
            supportsAllDrives=True,
        )
        .execute()
    )
    print("Uploaded new APK to Google Drive:")
    print(f"id={created.get('id')}")
    print(f"name={created.get('name')}")
    print(f"webViewLink={created.get('webViewLink')}")
    print(f"webContentLink={created.get('webContentLink')}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
