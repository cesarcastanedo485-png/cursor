import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import type { BridgeTask, TaskItem } from './extension';

function getPendingTaskPath(): string {
  const home = process.env.HOME || process.env.USERPROFILE || process.env.HOMEPATH || '';
  return path.join(home, '.mordecai', 'pending_task.json');
}

export class MordecaiTasksProvider implements vscode.TreeDataProvider<TaskItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<TaskItem | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  private currentTask: BridgeTask | null = null;
  private baseUrl: string;
  private deviceId: string;
  private context: vscode.ExtensionContext;

  constructor(baseUrl: string, deviceId: string, context: vscode.ExtensionContext) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.deviceId = deviceId;
    this.context = context;
  }

  private isAutomationTask(task: BridgeTask): boolean {
    const type = String(task.taskType || '').trim().toLowerCase();
    return (
      type === 'phase1_obs_control' ||
      type === 'phase1_clip_pipeline' ||
      type === 'phase1_clip_publish' ||
      type === 'youtube_optimize' ||
      type === 'vidiq_assist'
    );
  }

  private buildTaskPrompt(task: BridgeTask): string {
    if (!this.isAutomationTask(task)) return task.prompt;
    const type = String(task.taskType || 'phase1_clip_pipeline').toLowerCase();
    const payload = task.payload && typeof task.payload === 'object' ? task.payload : {};
    const payloadText = JSON.stringify(payload, null, 2);
    const headers: Record<string, string> = {
      phase1_obs_control: 'Execute OBS desktop control actions from this payload.',
      phase1_clip_pipeline: 'Execute clip pipeline: collect recording, process clip, upload, and report outcome.',
      phase1_clip_publish: 'Publish prepared clip to target platform and report result.',
      youtube_optimize: 'Run YouTube optimization workflow on desktop tooling.',
      vidiq_assist: 'Open vidIQ flow on desktop and apply optimization recommendations.',
    };
    return (
      `${headers[type] || 'Execute automation task from payload.'}\n\n` +
      `Task type: ${type}\n` +
      `Task id: ${task.taskId}\n\n` +
      `Payload:\n${payloadText}`
    );
  }

  private getBridgeSecret(): string {
    return vscode.workspace.getConfiguration('mordecai').get<string>('bridgeSecret', '')?.trim() || '';
  }

  private async fetch(
    path: string,
    options: RequestInit = {},
  ): Promise<Response> {
    const url = `${this.baseUrl}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(options.headers as Record<string, string>),
    };
    const secret = this.getBridgeSecret();
    if (secret) {
      headers['X-Bridge-Secret'] = secret;
    }
    return fetch(url, { ...options, headers });
  }

  private loadPendingTaskFromFile(): BridgeTask | null {
    try {
      const p = getPendingTaskPath();
      if (fs.existsSync(p)) {
        const raw = fs.readFileSync(p, 'utf8');
        const task = JSON.parse(raw) as BridgeTask;
        if (task?.taskId && task?.prompt) return task;
      }
    } catch {
      // Ignore
    }
    return null;
  }

  private clearPendingTaskFile(): void {
    try {
      const p = getPendingTaskPath();
      if (fs.existsSync(p)) {
        fs.unlinkSync(p);
      }
    } catch {
      // Ignore
    }
  }

  async poll(): Promise<void> {
    // Check file first (from Python bridge when Cursor was closed)
    const fileTask = this.loadPendingTaskFromFile();
    if (fileTask) {
      this.currentTask = fileTask;
      this._onDidChangeTreeData.fire();
      vscode.window.showInformationMessage(
        `Mordecai: Task from bridge. Prompt copied. Paste in Composer (Ctrl+Shift+I) to run.`,
      );
      vscode.env.clipboard.writeText(fileTask.prompt);
      this.clearPendingTaskFile();
      return;
    }

    if (!this.baseUrl) return;
    try {
      const res = await this.fetch(`/api/bridge/tasks/poll?deviceId=${encodeURIComponent(this.deviceId)}`);
      if (res.status === 204) {
        return;
      }
      if (!res.ok) {
        return;
      }
      const task = (await res.json()) as BridgeTask;
      this.currentTask = task;
      this._onDidChangeTreeData.fire();
      const prompt = this.buildTaskPrompt(task);
      vscode.env.clipboard.writeText(prompt);
      vscode.window.showInformationMessage(
        this.isAutomationTask(task)
          ? `Mordecai: Automation task received. Instructions copied. Paste in Composer (Ctrl+Shift+I) to run.`
          : `Mordecai: New task from phone. Prompt copied. Paste in Composer (Ctrl+Shift+I) to run.`,
      );
    } catch {
      // Ignore poll errors (network, etc.)
    }
  }

  async markDone(taskId: string): Promise<void> {
    try {
      const res = await this.fetch(`/api/bridge/tasks/${taskId}/complete`, {
        method: 'POST',
        body: JSON.stringify({ message: 'Task completed from Cursor' }),
      });
      if (res.ok) {
        if (this.currentTask?.taskId === taskId) {
          this.currentTask = null;
          this._onDidChangeTreeData.fire();
        }
        this.clearPendingTaskFile();
        vscode.window.showInformationMessage('Task marked done. Phone will get a notification.');
      }
    } catch (e) {
      vscode.window.showErrorMessage(`Failed to mark done: ${e}`);
    }
  }

  async reportError(taskId: string, message: string): Promise<void> {
    try {
      const res = await this.fetch(`/api/bridge/tasks/${taskId}/error`, {
        method: 'POST',
        body: JSON.stringify({ message: message || 'Error reported from Cursor' }),
      });
      if (res.ok) {
        if (this.currentTask?.taskId === taskId) {
          this.currentTask = null;
          this._onDidChangeTreeData.fire();
        }
        this.clearPendingTaskFile();
        vscode.window.showInformationMessage('Error reported. Phone will get a notification.');
      }
    } catch (e) {
      vscode.window.showErrorMessage(`Failed to report error: ${e}`);
    }
  }

  refresh(): void {
    this._onDidChangeTreeData.fire();
    this.poll();
  }

  getTreeItem(element: TaskItem): vscode.TreeItem {
    const item = new vscode.TreeItem(
      element.label,
      element.task ? vscode.TreeItemCollapsibleState.None : vscode.TreeItemCollapsibleState.None,
    );
    if (element.task) {
      item.contextValue = 'task';
      const prompt = this.buildTaskPrompt(element.task);
      item.tooltip = prompt.slice(0, 200) + (prompt.length > 200 ? '...' : '');
      item.command = {
        command: 'mordecai.copyPrompt',
        title: 'Copy',
        arguments: [element],
      };
    } else {
      item.contextValue = 'empty';
    }
    return item;
  }

  getChildren(): TaskItem[] {
    if (this.currentTask) {
      const type = String(this.currentTask.taskType || '').trim();
      const prefix = type ? `[${type}] ` : '';
      return [
        {
          task: this.currentTask,
          label: `${prefix}${this.currentTask.repoUrl.split('/').pop() || 'Task'} — ${this.currentTask.prompt.slice(0, 50)}...`,
        },
      ];
    }
    return [
      {
        label: 'No pending tasks. Tasks appear when you launch from the phone.',
      },
    ];
  }
}
