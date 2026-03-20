# Automated setup run log

What was executed on your machine (approx. order):

## Done

| Step | Result |
|------|--------|
| **winget install Ollama.Ollama** | Started (if UAC appeared, you had to approve). Ollama CLI found at `%LOCALAPPDATA%\Programs\Ollama\ollama.exe`. |
| **winget install Git.Git** | Started (admin prompt possible). Git adds to PATH after new terminal. |
| **ComfyUI** | Downloaded from GitHub `master.zip` → **`C:\Users\cmc\ComfyUI`** |
| **`pip install -r requirements.txt`** | Run from ComfyUI folder with your **Python 3.14** (large download: torch, etc.). Check terminal for success/errors. |
| **`OLLAMA_HOST=0.0.0.0:11434`** | Set for the session when you run `scripts\complete_private_ai_setup.ps1` (phone/LAN access). Add **User** env var `OLLAMA_HOST` = `0.0.0.0:11434` to keep it. |
| **`ollama pull qwen2.5:7b`** | Run via script with **`-Skip72b`** (~4.7 GB). **In the app, set model to `qwen2.5:7b`** until you pull the 72B model. |
| **`ollama pull x/flux2-klein`** | Script runs this after; may fail if the name changed on Ollama’s library. |

## Run yourself next

1. **Full 72B LLM** (doc target — long download):

   ```powershell
   cd C:\Users\cmc\cursor_mobile
   .\scripts\complete_private_ai_setup.ps1
   ```

   (No `-Skip72b` — pulls `qwen3.5:72b`, falls back to `qwen2.5:72b` if needed.)

2. **ComfyUI server** (after pip finishes OK):

   ```powershell
   cd C:\Users\cmc\ComfyUI
   python main.py --listen 0.0.0.0 --port 8188
   ```

3. **Windows Firewall**: allow **11434** (Ollama) and **8188** (ComfyUI) inbound on Private network.

4. **Mordechaius Maximus**: Settings → set PC LAN IP (run `ipconfig` for IPv4); My Private AIs → URL `http://YOUR_IP:11434`, model **`qwen2.5:7b`** (or your 72B name after pull).

## Script location

`cursor_mobile\scripts\complete_private_ai_setup.ps1`
