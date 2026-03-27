import {
  PHASE1_DEFAULT_PLATFORMS,
  buildBridgeTaskContract,
  buildPhase1IdempotencyKey,
  normalizeStringArray,
  validatePhase1Event,
} from "./phase1Contracts.js";

const IDEMPOTENCY_TTL_MS = 6 * 60 * 60 * 1000;
const MAX_RUN_HISTORY = 250;
const MAX_DEAD_LETTERS = 150;

function makeRunId() {
  return `run_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

function makeEventId() {
  return `evt_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

function trimHistory(list, max) {
  while (list.length > max) {
    list.shift();
  }
}

export function createPhase1AutomationRuntime({
  createBridgeTask,
  getBridgeStats,
  logEvent,
  dispatchReply,
} = {}) {
  if (typeof createBridgeTask !== "function") {
    throw new Error("createPhase1AutomationRuntime requires createBridgeTask function");
  }

  const idempotencyIndex = new Map();
  const deadLetters = new Map();
  const runHistory = [];
  let acceptedEvents = 0;
  let dedupedEvents = 0;
  let processedEvents = 0;

  const config = {
    autoReplyEnabled: true,
    clipPipelineEnabled: true,
    enabledPlatforms: [...PHASE1_DEFAULT_PLATFORMS],
    autoReplyTemplate:
      "Thanks for reaching out. We saw your message and will follow up shortly.",
  };

  function cleanupIdempotency() {
    const cutoff = Date.now() - IDEMPOTENCY_TTL_MS;
    for (const [k, v] of idempotencyIndex.entries()) {
      if (v < cutoff) idempotencyIndex.delete(k);
    }
  }

  function pushRun(run) {
    runHistory.push(run);
    trimHistory(runHistory, MAX_RUN_HISTORY);
  }

  function pushDeadLetter(letter) {
    deadLetters.set(letter.eventId, letter);
    while (deadLetters.size > MAX_DEAD_LETTERS) {
      const oldest = deadLetters.keys().next().value;
      if (!oldest) break;
      deadLetters.delete(oldest);
    }
  }

  function isPlatformEnabled(platform) {
    return config.enabledPlatforms.includes(String(platform || "").toLowerCase());
  }

  function buildReplyText(event) {
    const actor = event.actorId ? `@${event.actorId}` : "there";
    return `${config.autoReplyTemplate} (${actor})`;
  }

  function toClipTask(event) {
    const source = event.payload || {};
    return buildBridgeTaskContract({
      taskType: "phase1_clip_pipeline",
      idempotencyKey: buildPhase1IdempotencyKey({
        eventType: event.eventType,
        platform: event.platform,
        sourceEventId: event.sourceEventId || source.clipId || "",
        threadId: event.threadId || "",
        actorId: event.actorId || "",
        receivedAt: event.receivedAt,
      }),
      prompt:
        `Phase1 clip pipeline for ${event.platform}: ` +
        `prepare clip, publish, and report result for thread ${event.threadId || "unknown"}.`,
      payload: {
        platform: event.platform,
        eventType: event.eventType,
        sourceEventId: event.sourceEventId,
        threadId: event.threadId,
        actorId: event.actorId,
        channelId: event.channelId,
        ...source,
      },
      metadata: {
        source: "phase1_automation",
        category: "clip_pipeline",
      },
    });
  }

  async function processEvent(event, context = {}) {
    const run = {
      runId: makeRunId(),
      eventId: event.eventId,
      eventType: event.eventType,
      platform: event.platform,
      receivedAt: event.receivedAt,
      startedAt: new Date().toISOString(),
      status: "queued",
      actions: [],
      requestId: context.requestId || null,
    };

    try {
      const platformEnabled = isPlatformEnabled(event.platform);
      if (!platformEnabled) {
        run.status = "skipped";
        run.actions.push({
          kind: "skip",
          reason: `platform_disabled:${event.platform}`,
        });
        pushRun(run);
        return run;
      }

      if (event.eventType === "comment_received" || event.eventType === "dm_received") {
        if (!config.autoReplyEnabled) {
          run.status = "skipped";
          run.actions.push({ kind: "skip", reason: "auto_reply_disabled" });
        } else {
          const replyText = buildReplyText(event);
          if (typeof dispatchReply !== "function") {
            throw new Error("dispatchReply not configured");
          }
          const dispatch = await dispatchReply({
            event,
            replyText,
            requestId: context.requestId || null,
          });
          run.status = "done";
          run.actions.push({
            kind: "auto_reply_dispatch",
            channelId: event.channelId,
            threadId: event.threadId,
            actorId: event.actorId,
            replyText,
            provider: dispatch?.provider || null,
            remoteId: dispatch?.remoteId || null,
          });
        }
      } else if (event.eventType === "live_segment_ready" || event.eventType === "clip_ready") {
        if (!config.clipPipelineEnabled) {
          run.status = "skipped";
          run.actions.push({ kind: "skip", reason: "clip_pipeline_disabled" });
        } else {
          const contract = toClipTask(event);
          const created = createBridgeTask({
            prompt: contract.prompt,
            repoUrl: "",
            branch: "",
            intent: contract.intent,
            idempotencyKey: contract.idempotencyKey,
            taskType: contract.taskType,
            payload: contract.payload,
            metadata: contract.metadata,
          });
          run.status = "done";
          run.actions.push({
            kind: "bridge_task_created",
            taskType: contract.taskType,
            taskId: created.taskId,
            bridgeStatus: created.status,
          });
        }
      } else if (event.eventType === "publish_result") {
        run.status = "done";
        run.actions.push({
          kind: "publish_result_recorded",
          result: event.payload?.result || "unknown",
        });
      }

      run.finishedAt = new Date().toISOString();
      processedEvents += 1;
      pushRun(run);
      return run;
    } catch (err) {
      run.status = "error";
      run.error = err.message || String(err);
      run.finishedAt = new Date().toISOString();
      pushRun(run);
      pushDeadLetter({
        eventId: event.eventId,
        failedAt: run.finishedAt,
        error: run.error,
        event,
      });
      if (typeof logEvent === "function") {
        logEvent("error", "phase1_event_failed", {
          eventId: event.eventId,
          eventType: event.eventType,
          platform: event.platform,
          error: run.error,
        });
      }
      return run;
    }
  }

  async function ingestEvent(rawEvent, context = {}) {
    cleanupIdempotency();
    const checked = validatePhase1Event(rawEvent);
    if (!checked.ok) {
      return { ok: false, error: checked.error };
    }
    const event = checked.value;
    const key = String(event.idempotencyKey || "").trim();
    if (key && idempotencyIndex.has(key)) {
      dedupedEvents += 1;
      return {
        ok: true,
        deduped: true,
        eventId: null,
        run: null,
      };
    }
    if (key) idempotencyIndex.set(key, Date.now());

    const enriched = {
      ...event,
      eventId: makeEventId(),
      queuedAt: new Date().toISOString(),
    };
    acceptedEvents += 1;
    const run = await processEvent(enriched, context);
    return {
      ok: true,
      deduped: false,
      eventId: enriched.eventId,
      run,
    };
  }

  async function retryDeadLetter(eventId, context = {}) {
    const id = String(eventId || "").trim();
    if (!id) return { ok: false, error: "eventId required" };
    const letter = deadLetters.get(id);
    if (!letter) return { ok: false, error: "dead letter not found" };
    deadLetters.delete(id);
    const retriedEvent = {
      ...letter.event,
      eventId: makeEventId(),
      idempotencyKey: `${letter.event.idempotencyKey || id}:retry:${Date.now()}`,
      receivedAt: new Date().toISOString(),
    };
    const run = await processEvent(retriedEvent, context);
    return { ok: true, eventId: retriedEvent.eventId, run };
  }

  function listRuns(limit = 25) {
    const safeLimit = Math.max(1, Math.min(200, Number(limit || 25)));
    return [...runHistory].slice(-safeLimit).reverse();
  }

  function listDeadLetters(limit = 25) {
    const safeLimit = Math.max(1, Math.min(100, Number(limit || 25)));
    return [...deadLetters.values()].slice(-safeLimit).reverse();
  }

  function getStatus() {
    const bridgeStats = typeof getBridgeStats === "function" ? getBridgeStats() : null;
    return {
      acceptedEvents,
      dedupedEvents,
      processedEvents,
      pendingDeadLetters: deadLetters.size,
      runHistoryCount: runHistory.length,
      bridgeQueue: bridgeStats,
      config: getConfig(),
    };
  }

  function getConfig() {
    return {
      autoReplyEnabled: !!config.autoReplyEnabled,
      clipPipelineEnabled: !!config.clipPipelineEnabled,
      enabledPlatforms: [...config.enabledPlatforms],
      autoReplyTemplate: String(config.autoReplyTemplate || "").trim(),
    };
  }

  function updateConfig(next = {}) {
    if (Object.prototype.hasOwnProperty.call(next, "autoReplyEnabled")) {
      config.autoReplyEnabled = !!next.autoReplyEnabled;
    }
    if (Object.prototype.hasOwnProperty.call(next, "clipPipelineEnabled")) {
      config.clipPipelineEnabled = !!next.clipPipelineEnabled;
    }
    if (Object.prototype.hasOwnProperty.call(next, "enabledPlatforms")) {
      config.enabledPlatforms = normalizeStringArray(
        next.enabledPlatforms,
        PHASE1_DEFAULT_PLATFORMS
      );
    }
    if (Object.prototype.hasOwnProperty.call(next, "autoReplyTemplate")) {
      const template = String(next.autoReplyTemplate || "").trim();
      if (template) config.autoReplyTemplate = template.slice(0, 500);
    }
    return getConfig();
  }

  return {
    ingestEvent,
    retryDeadLetter,
    listRuns,
    listDeadLetters,
    getStatus,
    getConfig,
    updateConfig,
  };
}
