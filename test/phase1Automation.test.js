import test from "node:test";
import assert from "node:assert/strict";
import { createPhase1AutomationRuntime } from "../server_lib/phase1Automation.js";
import { validatePhase1Event } from "../server_lib/phase1Contracts.js";

test("validatePhase1Event accepts supported event shape", () => {
  const validated = validatePhase1Event({
    eventType: "comment_received",
    platform: "facebook",
    payload: { text: "hello" },
    sourceEventId: "abc123",
  });
  assert.equal(validated.ok, true);
  assert.equal(validated.value.eventType, "comment_received");
  assert.equal(validated.value.platform, "facebook");
  assert.equal(validated.value.idempotencyKey, "comment_received:facebook:abc123");
});

test("phase1 runtime dedupes by idempotency key", async () => {
  const tasks = [];
  const runtime = createPhase1AutomationRuntime({
    createBridgeTask: (task) => {
      tasks.push(task);
      return { taskId: "task-dedupe", status: "pending" };
    },
    getBridgeStats: () => ({ pending: 0 }),
    dispatchReply: async () => ({ provider: "test", status: "sent", remoteId: "r1" }),
  });
  const first = await runtime.ingestEvent({
    eventType: "comment_received",
    platform: "youtube",
    payload: { text: "first" },
    idempotencyKey: "same-key",
  });
  const second = await runtime.ingestEvent({
    eventType: "comment_received",
    platform: "youtube",
    payload: { text: "second" },
    idempotencyKey: "same-key",
  });
  assert.equal(first.ok, true);
  assert.equal(first.deduped, false);
  assert.equal(second.ok, true);
  assert.equal(second.deduped, true);
  assert.equal(tasks.length, 0);
});

test("phase1 runtime creates bridge task for clip events", async () => {
  const tasks = [];
  const runtime = createPhase1AutomationRuntime({
    createBridgeTask: (task) => {
      tasks.push(task);
      return { taskId: "task-clip", status: "pending" };
    },
    getBridgeStats: () => ({ pending: 1 }),
    dispatchReply: async () => ({ provider: "test", status: "sent", remoteId: "r1" }),
  });

  const out = await runtime.ingestEvent({
    eventType: "clip_ready",
    platform: "tiktok",
    payload: {
      clipId: "clip_01",
      sourcePath: "C:/clips/raw.mp4",
      publishTargets: ["tiktok", "youtube"],
    },
  });

  assert.equal(out.ok, true);
  assert.equal(tasks.length, 1);
  assert.equal(tasks[0].taskType, "phase1_clip_pipeline");
  assert.equal(tasks[0].intent, "phase1_automation");
  assert.equal(tasks[0].payload.clipId, "clip_01");
});

test("phase1 runtime dispatches provider-specific auto reply", async () => {
  let replyCalls = 0;
  const runtime = createPhase1AutomationRuntime({
    createBridgeTask: () => ({ taskId: "task-none", status: "pending" }),
    getBridgeStats: () => ({ pending: 0 }),
    dispatchReply: async ({ event, replyText }) => {
      replyCalls += 1;
      assert.equal(event.platform, "messenger");
      assert.ok(replyText.includes("Thanks for reaching out"));
      return { provider: "meta_graph", status: "sent", remoteId: "m_123" };
    },
  });

  const result = await runtime.ingestEvent({
    eventType: "dm_received",
    platform: "messenger",
    actorId: "fan_44",
    payload: { pageId: "1", recipientId: "2" },
  });
  assert.equal(result.ok, true);
  assert.equal(result.run.status, "done");
  assert.equal(replyCalls, 1);
});
