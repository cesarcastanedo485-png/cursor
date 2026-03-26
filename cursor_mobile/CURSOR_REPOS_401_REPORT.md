# Report for Cursor: GET /v0/repositories returns 401 while GET /v0/agents works

Use this when contacting Cursor support (e.g. support@cursor.com or in-app/Discord) so they can fix the backend.

---

## Summary

- **Same API key** (Cloud Agents, from Dashboard → Cloud Agents).
- **GET /v0/agents** with Basic auth → **200 OK** (Test connection in app passes).
- **GET /v0/repositories** with the same auth → **401 Unauthorized** (“Invalid API key” in app).
- **GitHub is connected** to Cursor (same account email); streamgame and other repos exist on GitHub.
- **Rate limit respected**: only 1 request per minute to `/v0/repositories`, waited long before retrying.
- **Result**: Repo list in the app stays empty; user cannot see their repos from the API.

## Request details

- **Endpoint:** `GET https://api.cursor.com/v0/repositories`
- **Auth:** Basic, same as for `/v0/agents` (API key as username, empty password).
- **Headers:** `Content-Type: application/json`, `Accept: application/json`.

## Ask for Cursor

1. Why does `/v0/repositories` return 401 for this key when `/v0/agents` returns 200?
2. Is there an extra permission or scope needed for the repos endpoint?
3. Can the backend be fixed or documented so that repos work when GitHub is connected and the key is valid for agents?

## Workaround in the app

The app now supports **Add repo by URL** (manual list) so the user can add e.g. `https://github.com/cesarcastanedo485-png/streamgame` and still launch agents on that repo while the API issue is open.
