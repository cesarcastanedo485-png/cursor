# Mordecai Maximus (Cursor Extension)

Receive agent tasks from your phone and run them in Cursor Composer. Saves Cloud API tokens by using your desktop Cursor instead of Cloud Agents.

## Setup

1. Install the extension (build with `npm run compile`, then install the VSIX or copy to extensions folder).
2. Set **Mordecai URL** in Settings: `mordecai.maximusUrl` — your Mordecai server URL (e.g. from Cloudflare Tunnel).
3. If your server uses a bridge secret, set `mordecai.bridgeSecret` to match `MORDECAI_BRIDGE_SECRET`.

## Usage

1. Open the **Mordecai** view in the Activity Bar (rocket icon).
2. The extension polls for tasks. When you launch from the phone with "Use desktop (saves tokens)", a task appears.
3. Click the task or use the context menu:
   - **Copy prompt** — Copy to clipboard, then paste in Composer.
   - **Run in Composer** — Copy and try to open Composer (clipboard fallback if no command found).
   - **Mark done** — Notify the phone that the task is complete.
   - **Report error** — Notify the phone that the task failed.

## Composer integration

Cursor may expose commands for Composer. The extension uses `vscode.commands.getCommands()` to discover them. If no suitable command is found, it copies the prompt to the clipboard and shows a reminder to paste in Composer (Ctrl+Shift+I / Cmd+Shift+I).

## Building

```bash
cd cursor_extension
npm install
npm run compile
```

Then install via: **Extensions** → **...** → **Install from VSIX** (after running `vsce package` if you have vsce), or copy the folder to your Cursor extensions directory.
