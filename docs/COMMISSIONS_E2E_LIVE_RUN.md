# End-to-end Commissions test and live run (web + Cursor)

Use this checklist for a full **browser** run (e-commerce, reference image, all phases), then open the same project in **Cursor** and run the generated site on a port **other than** Mordecai’s.

**Automated preflight (optional):** from `mordecai-maximus`, with the server running:

```bash
npm run commissions:preflight
```

With the server stopped, env hints only + port probe:

```bash
npm run commissions:preflight -- --skip-health
```

Override URL if Mordecai uses a different port:

```bash
MORDECAI_PREFLIGHT_URL=http://127.0.0.1:3001 npm run commissions:preflight
```

---

## What you are validating

- One **e-commerce** commission: reference image, form fields, **Phase 1 through completion**.
- **Mordecai** at `http://localhost:3000` (or your `PORT`).
- **Cursor** on your PC: **one workspace** (local folder + GitHub branch) where the Cloud Agent worked.

**Note:** Double-clicking Cursor does **not** auto-open the commission folder. Use **File → Open Folder** on the path Mordecai shows, then **git** checkout/pull the commission branch.

---

## Phase A — Preflight

- [ ] **Port 3000 (or `PORT`)** is free for **Mordecai only** — stop other apps using that port.
- [ ] You will **not** run the generated site’s dev server on the **same** port as Mordecai; use **3001+** for the site.
- [ ] `npm install` in `mordecai-maximus` (once).
- [ ] `.env` configured: optional `COMMISSIONS_WORKSPACE` (absolute path for commission folders).
- [ ] **Cursor API key** + **default GitHub repo** in Mordecai **Settings** UI, **or** `CURSOR_API_KEY` + `CURSOR_COMMISSION_REPO` in `.env`.
- [ ] `npm start` → open `http://localhost:3000` → **Commissions** tab loads.
- [ ] Run `npm run commissions:preflight` → `{"ok":true}` from health (or curl `GET /api/commissions/health`).

---

## Phase B — Full browser test (e-commerce, reference image, all phases)

- [ ] **Commissions** → website type **E-commerce** (or your target type).
- [ ] Upload **reference image**; fill **all required** fields.
- [ ] **Phase 1 — Start** → phase shows **running** while the agent works (not instantly “done”).
- [ ] Wait for **polling** to finish → **Review Checklist** / **Continue** as the UI indicates.
- [ ] Copy or note **workspace path** from the result panel.
- [ ] Repeat for **Phase 2** … through **last phase**.
- [ ] On failure: **Retry** or **Mark complete anyway** only if you accept partial work.
- [ ] If **“Agent not found”** during polling: fix API/settings or restart phase.
- [ ] Optional: web push + phase-complete notify (if you use push).
- [ ] **Success:** every phase completed via agent + checklist; folder exists at `workspacePath`; **GitHub** shows commits on the **commission branch**.

---

## Phase C — Live run: site + Cursor

- [ ] Open **Cursor** → **File → Open Folder** → folder from Commissions (**workspace path**).
- [ ] In terminal: `git fetch`, checkout **commission branch**, `git pull`.
- [ ] `npm install` (or pnpm/yarn per project).
- [ ] `npm run dev -- -p 3001` (or stack-specific; **not** Mordecai’s port).
- [ ] PC browser: `http://localhost:3001`.
- [ ] **Bonus phone preview:** same Wi‑Fi → `http://<PC_LAN_IP>:3001`, or tunnel; use **Phone preview (LAN / tunnel)** in Commissions. See [DEPLOYMENT.md](./DEPLOYMENT.md).

---

## If something fails

| Symptom | Check |
|--------|--------|
| Execute errors | Settings: API key + repo; server logs |
| Phase stuck “running” | Cursor API `status` vs `readAgentState` in `public/js/mordecai.js` — capture one real JSON response |
| No folder on disk | `COMMISSIONS_WORKSPACE` writable; execute logs |
| Local folder vs GitHub mismatch | Wrong branch; `git pull` on commission branch |

---

## References

- Server: `server.js` — execute, `GET /api/commissions/agent-status/:id`, health.
- UI: `public/js/mordecai.js` — polling, checklist, phases.
- Workspace: `server_lib/commissionRunner.js` — `COMMISSIONS_WORKSPACE`.
- Agents: `lib/cursorAgents.js` — branch naming, followups.
