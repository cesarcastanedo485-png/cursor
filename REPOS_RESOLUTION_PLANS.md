# Three actionable plans to fix “My Repos” / Cursor API issues

Use these in order—or pick the one that matches how much time you want to spend.

---

## Plan A — **Stay unblocked in the app (no Cursor fix required)**

**Goal:** Use Mordechaius Maximus daily without relying on `GET /v0/repositories`.

**Actions:**

1. **My Repos → + (Add repo by URL)** and add each project you care about, e.g.  
   `https://github.com/cesarcastanedo485-png/streamgame`
2. Use **Launch Agent on this Repo** from those cards (same as if they came from Cursor).
3. **Anti-loop** in the app now limits repeat API calls so you don’t burn rate limits or sit in error loops; use **⋮ → Force API retry** only when you intentionally want one more try.

**Outcome:** Full control from the phone even if Cursor’s repo list API never works for your account.

---

## Plan B — **Get Cursor to fix the backend (official path)**

**Goal:** `GET /v0/repositories` returns 200 with your GitHub repos like the docs say.

**Actions:**

1. Open **`CURSOR_REPOS_401_REPORT.md`** in this project and copy the summary (or attach the file).
2. Contact Cursor support (email, in-app, or Discord—whatever they list on [cursor.com](https://cursor.com)).
3. Say explicitly: **same API key works for `GET /v0/agents` but `GET /v0/repositories` returns 401**; GitHub is connected; you waited between requests.
4. Ask whether repos need a **separate scope**, **team/enterprise** flag, or if it’s a **known bug**.

**Outcome:** If they fix it, My Repos fills automatically; manual URLs remain as backup.

---

## Plan C — **Edit from the phone without the repo list (hybrid workflow)**

**Goal:** Ship changes even when Cloud Agents + repo list are flaky.

**Actions:**

1. **Desktop Cursor** (or GitHub web) for heavy edits; **phone app** for agents, private AIs, and quick launches using **manually added repo URLs** (Plan A).
2. Optionally **bookmark** the GitHub repo + **Cursor Cloud Agents** web UI on the phone browser as a fallback to start agents from a URL Cursor already knows.
3. Keep **one source of truth** for repo URLs in the app’s manual list so you’re not re-typing them.

**Outcome:** Phone stays useful for orchestration; deep coding stays on PC until Plan B is resolved.

---

## What we implemented in-app (anti-loop)

- **Cooldown:** at least **45 seconds** between normal repo-list API attempts (reduces spam / rate limits).
- **Circuit breaker:** after **2× 401** on repos within **24 hours**, automatic calls pause **30 minutes** (empty list + banner instead of endless errors).
- **Force API retry** (⋮ menu): clears the pause **once** and tries the API again.
- **Dismiss** on the banner clears the message without calling the API.

If nothing here works for your situation, the next step is **Plan B** with Cursor support—your case (agents OK, repos 401) is exactly what they need to see in logs.
