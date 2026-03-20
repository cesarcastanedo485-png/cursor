# Private AIs setup (Ollama, ComfyUI, phone access)

**Automated helper:** after Ollama is installed, run from the project folder:

```powershell
.\scripts\complete_private_ai_setup.ps1          # pulls qwen3.5:72b (huge) + flux attempt
.\scripts\complete_private_ai_setup.ps1 -Skip72b # pulls qwen2.5:7b first (~5 GB) for quick test
```

See **`SETUP_PRIVATE_RUN_LOG.md`** for what was already run on your PC.

---

This app talks to **OpenAI-compatible** HTTP APIs on your PC. Same **base URL + model + optional Bearer token** work here and in other apps or games you build.

---

## 1. Text LLM (Ollama — My LLM)

Install [Ollama](https://ollama.com/download), then in a terminal:

```bash
ollama pull qwen3.5:72b
```

Run the server (usually automatic). Default API:

- Base URL on your PC: `http://127.0.0.1:11434`
- Chat: `POST /v1/chat/completions` (OpenAI-compatible)

In **Mordechaius Maximus → My Private AIs** (LLM preset), set:

- **Server URL:** `http://YOUR_PC_LAN_IP:11434` (e.g. `http://192.168.1.100:11434`). Get your PC IP: run `ipconfig` (Windows) → IPv4 Address.
- **Model:** `qwen3.5:72b`

---

## 2. SFW image (Ollama FLUX-style)

If your Ollama build exposes an image model (names vary by registry):

```bash
ollama pull x/flux2-klein
# or follow current Ollama library names for FLUX / Klein variants
ollama run x/flux2-klein
```

Point **SFW Image Gen** at the same Ollama host if `/v1/images/generations` is available; otherwise use ComfyUI (below) on port **8188**.

---

## 3. ComfyUI (image + video / LTX / WAN)

1. Install **Python 3.10+**, then clone [ComfyUI](https://github.com/comfyanonymous/ComfyUI):

   ```bash
   git clone https://github.com/comfyanonymous/ComfyUI.git
   cd ComfyUI
   pip install -r requirements.txt
   python main.py --listen 0.0.0.0 --port 8188
   ```

2. **LTX-2.3 (SFW video):** add community workflows and checkpoints from ComfyUI Manager or Hugging Face; search for “LTX-2.3” / “LTX Video” workflow packs. Drop models into `ComfyUI/models/` as instructed by each model card.

3. **NSFW image (Pony Diffusion V6 + uncensored Flux merge):** download checkpoints and merged models only from sources you trust; place under `models/checkpoints` / `models/unet` per workflow JSON. Run workflows locally — **never expose ComfyUI to the public internet without authentication.**

4. **NSFW video (LTX uncensored / WAN 2.2 Remix):** same pattern — import workflow JSON + matching models from the pack you use.

ComfyUI’s native API is **not** OpenAI-shaped. Options:

- Use a **small OpenAI-compatible gateway** in front of ComfyUI (community projects exist), **or**
- Use **Mordechaius Maximus → My Private AIs → Studio** to copy a **sample cURL** and adapt it to your workflow endpoint.

---

## 4. Phone → PC networking

| Method | Steps |
|--------|--------|
| **Same Wi‑Fi** | PC firewall: allow inbound **11434** (Ollama) and **8188** (ComfyUI). Use PC’s LAN IP in the app. |
| **Tailscale** | Install Tailscale on PC + phone; use the PC’s **100.x** address: `http://100.x.x.x:11434` |

Ollama: set `OLLAMA_HOST=0.0.0.0:11434` if it only listens on localhost (see [Ollama docs](https://github.com/ollama/ollama/blob/main/docs/faq.md)).

---

## 5. Quick test from phone

In **My Private AIs**, tap **Test connection** after saving URL + model. For chat, open **Chat** on the My LLM card.

---

## 6. Copy-paste for other projects

Use the same values as in the app:

```text
Base URL: http://192.168.1.100:11434
Model:    qwen3.5:72b
Header:   Authorization: Bearer <optional>
```

Standard chat payload:

```json
POST /v1/chat/completions
{ "model": "qwen3.5:72b", "messages": [{"role":"user","content":"Hi"}], "stream": false }
```

---

*Models and workflow names change often; verify exact names on Ollama’s library and ComfyUI community pages.*
