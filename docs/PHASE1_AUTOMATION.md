# Phase 1 Automation Runbook

This runbook covers the first production slice:

- auto-reply comments/DMs
- clip pipeline orchestration (`record -> clip -> publish`)
- desktop bridge handoff for OBS and upload actions

## Endpoints

- `POST /api/phase1/events` - ingest normalized social events
- `GET /api/phase1/status` - counters + bridge queue snapshot
- `GET /api/phase1/runs?limit=25` - recent run history
- `GET /api/phase1/dead-letter?limit=25` - dead-letter queue
- `POST /api/phase1/dead-letter/:eventId/retry` - manual retry
- `GET /api/phase1/config` / `POST /api/phase1/config` - runtime toggles
- `POST /api/phase1/youtube/optimize` - forward-compatible hook (`youtube_optimize` / `vidiq_assist`)

## Security

- Prefer setting `MORDECAI_PHASE1_INGEST_TOKEN` for `/api/phase1/events`.
- Keep `MORDECAI_BRIDGE_SECRET` enabled for bridge task APIs.
- Keep all tokens in local `.env` or host secret manager (never commit).

### Connector secrets

- Meta direct API: `MORDECAI_META_PAGE_ACCESS_TOKEN`, `MORDECAI_META_PAGE_ID`
- TikTok relay: `MORDECAI_TIKTOK_REPLY_WEBHOOK`
- YouTube direct API: `MORDECAI_YOUTUBE_ACCESS_TOKEN`
- Optional relays: `MORDECAI_META_REPLY_WEBHOOK`, `MORDECAI_YOUTUBE_REPLY_WEBHOOK`, `MORDECAI_SOCIAL_REPLY_WEBHOOK`

## Event Contract

Incoming JSON should include:

- `eventType`: `comment_received | dm_received | live_segment_ready | clip_ready | publish_result`
- `platform`: e.g. `facebook`, `messenger`, `tiktok`, `youtube`
- `payload`: provider-specific event details
- Optional: `sourceEventId`, `threadId`, `actorId`, `channelId`, `idempotencyKey`

Idempotency key is auto-generated if omitted, but explicit keys are recommended for webhooks.

### Example webhook event (ingest)

```bash
curl -X POST "https://YOUR_PUBLIC_URL/api/phase1/events" \
  -H "Content-Type: application/json" \
  -H "X-Phase1-Ingest-Token: YOUR_INGEST_TOKEN" \
  -d '{
    "eventType":"comment_received",
    "platform":"youtube",
    "sourceEventId":"yt-comment-123",
    "threadId":"yt-thread-123",
    "actorId":"subscriber_55",
    "payload":{
      "commentId":"UgzAbc123"
    }
  }'
```

### Test status quickly

```bash
curl -H "X-Bridge-Secret: YOUR_BRIDGE_SECRET" "https://YOUR_PUBLIC_URL/api/phase1/status"
```

## Operations Checklist

- Set config in app `Capabilities -> Phase 1 automation`.
- Verify status shows increasing `acceptedEvents` and low `pendingDeadLetters`.
- Watch run history for `error`/`skipped` patterns.
- Retry dead letters after fixing root cause.

## Bridge Task Types

- `phase1_obs_control`
- `phase1_clip_pipeline`
- `phase1_clip_publish`
- `youtube_optimize` (phase 2 hook)
- `vidiq_assist` (phase 2 hook)
