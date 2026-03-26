/**
 * Desktop bridge task queue — in-memory store for tasks from phone to desktop.
 * Phone submits tasks; desktop extension polls and marks complete.
 */

const tasks = new Map();
const idempotencyIndex = new Map();
const TERMINAL_RETENTION_MS = 24 * 60 * 60 * 1000; // 24 hours
const PENDING_TTL_MS = 2 * 60 * 60 * 1000; // 2 hours
const CLAIM_TIMEOUT_MS = 10 * 60 * 1000; // 10 minutes

function generateTaskId() {
  return "task_" + Date.now() + "_" + Math.random().toString(36).slice(2, 11);
}

function cleanupOldTasks() {
  const terminalCutoff = Date.now() - TERMINAL_RETENTION_MS;
  const pendingCutoff = Date.now() - PENDING_TTL_MS;
  const claimCutoff = Date.now() - CLAIM_TIMEOUT_MS;
  for (const [id, t] of tasks.entries()) {
    if (
      (t.status === "done" || t.status === "error" || t.status === "expired") &&
      t.updatedAt < terminalCutoff
    ) {
      tasks.delete(id);
      if (t.idempotencyKey) idempotencyIndex.delete(t.idempotencyKey);
      continue;
    }
    if (t.status === "pending" && t.updatedAt < pendingCutoff) {
      t.status = "expired";
      t.message = "Task expired before desktop claimed it.";
      t.updatedAt = Date.now();
      continue;
    }
    if (t.status === "claimed" && t.updatedAt < claimCutoff) {
      t.status = "pending";
      t.deviceId = null;
      t.updatedAt = Date.now();
    }
  }
}

/**
 * Create a new task. Returns { taskId, status }.
 */
export function createTask({
  prompt,
  repoUrl,
  branch,
  intent,
  fcmToken,
  idempotencyKey,
}) {
  cleanupOldTasks();
  const key = String(idempotencyKey || "").trim();
  if (key && idempotencyIndex.has(key)) {
    const existingId = idempotencyIndex.get(key);
    const existing = tasks.get(existingId);
    if (existing) {
      return { taskId: existing.taskId, status: existing.status, deduped: true };
    }
    idempotencyIndex.delete(key);
  }
  const taskId = generateTaskId();
  const now = Date.now();
  tasks.set(taskId, {
    taskId,
    prompt: prompt || "",
    repoUrl: repoUrl || "",
    branch: branch || "",
    intent: intent || "normal",
    fcmToken: fcmToken || null,
    status: "pending",
    deviceId: null,
    idempotencyKey: key || null,
    deduped: false,
    createdAt: now,
    updatedAt: now,
  });
  if (key) idempotencyIndex.set(key, taskId);
  cleanupOldTasks();
  return { taskId, status: "pending" };
}

/**
 * Poll for next pending task. Marks it as claimed by deviceId.
 * Returns task object or null if none.
 */
export function pollTask(deviceId) {
  if (!deviceId) return null;
  cleanupOldTasks();
  for (const [id, t] of tasks.entries()) {
    if (t.status === "pending") {
      t.status = "claimed";
      t.deviceId = deviceId;
      t.updatedAt = Date.now();
      return { ...t };
    }
  }
  return null;
}

/**
 * Get task by ID.
 */
export function getTask(taskId) {
  cleanupOldTasks();
  return tasks.get(taskId) || null;
}

/**
 * Mark task complete. Returns the task (with fcmToken for push) or null.
 */
export function completeTask(taskId, { message } = {}) {
  cleanupOldTasks();
  const t = tasks.get(taskId);
  if (!t) return null;
  t.status = "done";
  t.message = message || null;
  t.updatedAt = Date.now();
  return { ...t };
}

/**
 * Mark task error. Returns the task or null.
 */
export function errorTask(taskId, { message } = {}) {
  cleanupOldTasks();
  const t = tasks.get(taskId);
  if (!t) return null;
  t.status = "error";
  t.message = message || null;
  t.updatedAt = Date.now();
  return { ...t };
}

/**
 * Update task state while desktop is actively working.
 */
export function setTaskStatus(taskId, { status, message } = {}) {
  cleanupOldTasks();
  const t = tasks.get(taskId);
  if (!t) return null;
  const allowed = new Set(["pending", "claimed", "running", "done", "error", "expired"]);
  const next = String(status || "").trim().toLowerCase();
  if (!allowed.has(next)) return null;
  t.status = next;
  if (typeof message === "string" && message.trim()) {
    t.message = message.trim();
  }
  t.updatedAt = Date.now();
  return { ...t };
}

export function getTaskStats() {
  cleanupOldTasks();
  const stats = {
    total: 0,
    pending: 0,
    claimed: 0,
    running: 0,
    done: 0,
    error: 0,
    expired: 0,
  };
  for (const task of tasks.values()) {
    stats.total += 1;
    const k = String(task.status || "").toLowerCase();
    if (Object.prototype.hasOwnProperty.call(stats, k)) {
      stats[k] += 1;
    }
  }
  return stats;
}
