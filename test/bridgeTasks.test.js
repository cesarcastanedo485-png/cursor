import test from "node:test";
import assert from "node:assert/strict";
import {
  createTask,
  pollTask,
  getTask,
  completeTask,
  setTaskStatus,
  getTaskStats,
} from "../lib/bridgeTasks.js";

test("createTask dedupes by idempotency key", () => {
  const first = createTask({
    prompt: "Build homepage",
    repoUrl: "https://github.com/acme/site",
    branch: "main",
    intent: "normal",
    idempotencyKey: "same-key",
  });
  const second = createTask({
    prompt: "Build homepage",
    repoUrl: "https://github.com/acme/site",
    branch: "main",
    intent: "normal",
    idempotencyKey: "same-key",
  });
  assert.equal(first.taskId, second.taskId);
  completeTask(first.taskId, { message: "cleanup" });
});

test("pollTask claims pending task once", () => {
  const created = createTask({
    prompt: "Fix navbar",
    repoUrl: "https://github.com/acme/site",
    branch: "main",
    intent: "normal",
    idempotencyKey: `claim-key-${Date.now()}`,
  });
  const claim = pollTask("device-1");
  assert.ok(claim);
  assert.equal(claim.taskId, created.taskId);
  const claimAgain = pollTask("device-1");
  assert.equal(claimAgain, null);
});

test("completeTask stores terminal message", () => {
  const created = createTask({
    prompt: "Finish task",
    repoUrl: "",
    branch: "",
    intent: "normal",
    idempotencyKey: `done-key-${Date.now()}`,
  });
  const done = completeTask(created.taskId, { message: "ok" });
  assert.ok(done);
  assert.equal(done.status, "done");
  assert.equal(done.message, "ok");
  const fetched = getTask(created.taskId);
  assert.equal(fetched?.status, "done");
});

test("setTaskStatus updates running heartbeat state", () => {
  const created = createTask({
    prompt: "Run build",
    repoUrl: "https://github.com/acme/site",
    branch: "main",
    intent: "normal",
    idempotencyKey: `status-key-${Date.now()}`,
  });
  const updated = setTaskStatus(created.taskId, {
    status: "running",
    message: "Desktop executing",
  });
  assert.equal(updated?.status, "running");
  assert.equal(updated?.message, "Desktop executing");
  const stats = getTaskStats();
  assert.ok(stats.running >= 1);
});
