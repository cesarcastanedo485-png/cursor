const PHASE1_EVENT_TYPES = new Set([
  "comment_received",
  "dm_received",
  "live_segment_ready",
  "clip_ready",
  "publish_result",
]);

const PHASE1_TASK_TYPES = new Set([
  "phase1_obs_control",
  "phase1_clip_pipeline",
  "phase1_clip_publish",
  "youtube_optimize",
  "vidiq_assist",
]);

const PHASE1_DEFAULT_PLATFORMS = ["facebook", "messenger", "tiktok", "youtube"];

export function normalizePlatform(input) {
  const v = String(input || "").trim().toLowerCase();
  if (!v) return "unknown";
  if (v === "fb") return "facebook";
  if (v === "yt") return "youtube";
  return v;
}

export function normalizeStringArray(input, fallback = []) {
  if (!Array.isArray(input)) return [...fallback];
  const out = input
    .map((v) => String(v || "").trim().toLowerCase())
    .filter(Boolean);
  return out.length > 0 ? [...new Set(out)] : [...fallback];
}

export function buildPhase1IdempotencyKey({
  eventType,
  platform,
  sourceEventId,
  threadId,
  actorId,
  receivedAt,
}) {
  const safeType = String(eventType || "").trim().toLowerCase();
  const safePlatform = normalizePlatform(platform);
  const keySource = String(sourceEventId || "").trim();
  if (keySource) return `${safeType}:${safePlatform}:${keySource}`;
  const minuteBucket = Math.floor(new Date(receivedAt || Date.now()).getTime() / 60000);
  return `${safeType}:${safePlatform}:${threadId || "-"}:${actorId || "-"}:${minuteBucket}`;
}

export function validatePhase1Event(raw = {}) {
  const eventType = String(raw.eventType || "").trim().toLowerCase();
  if (!PHASE1_EVENT_TYPES.has(eventType)) {
    return { ok: false, error: "Invalid eventType" };
  }

  const platform = normalizePlatform(raw.platform);
  const payload = raw.payload && typeof raw.payload === "object" ? raw.payload : {};
  const receivedAt = raw.receivedAt ? new Date(raw.receivedAt).toISOString() : new Date().toISOString();
  const sourceEventId = String(raw.sourceEventId || "").trim();
  const threadId = String(raw.threadId || "").trim();
  const actorId = String(raw.actorId || "").trim();
  const channelId = String(raw.channelId || "").trim();
  const idempotencyKey =
    String(raw.idempotencyKey || "").trim() ||
    buildPhase1IdempotencyKey({
      eventType,
      platform,
      sourceEventId,
      threadId,
      actorId,
      receivedAt,
    });

  return {
    ok: true,
    value: {
      eventType,
      platform,
      payload,
      receivedAt,
      sourceEventId: sourceEventId || null,
      threadId: threadId || null,
      actorId: actorId || null,
      channelId: channelId || null,
      idempotencyKey,
    },
  };
}

export function validatePhase1TaskType(taskType) {
  const type = String(taskType || "").trim().toLowerCase();
  return PHASE1_TASK_TYPES.has(type);
}

export function buildBridgeTaskContract({
  taskType,
  prompt,
  payload,
  metadata,
  idempotencyKey,
  intent = "phase1_automation",
}) {
  const safeTaskType = String(taskType || "").trim().toLowerCase();
  if (!validatePhase1TaskType(safeTaskType)) {
    throw new Error(`Unsupported phase1 task type: ${safeTaskType || "empty"}`);
  }
  return {
    taskType: safeTaskType,
    prompt: String(prompt || "").trim() || `Execute ${safeTaskType} automation task`,
    payload: payload && typeof payload === "object" ? payload : {},
    metadata: metadata && typeof metadata === "object" ? metadata : {},
    idempotencyKey: String(idempotencyKey || "").trim() || null,
    intent,
  };
}

export { PHASE1_EVENT_TYPES, PHASE1_TASK_TYPES, PHASE1_DEFAULT_PLATFORMS };
