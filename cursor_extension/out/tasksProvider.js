"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MordecaiTasksProvider = void 0;
const fs = require("fs");
const path = require("path");
const vscode = require("vscode");
const PENDING_TASK_PATH = path.join(process.env.HOME || process.env.USERPROFILE || '', '.mordecai', 'pending_task.json');
class MordecaiTasksProvider {
    constructor(baseUrl, deviceId, context) {
        this._onDidChangeTreeData = new vscode.EventEmitter();
        this.onDidChangeTreeData = this._onDidChangeTreeData.event;
        this.currentTask = null;
        this.baseUrl = baseUrl.replace(/\/$/, '');
        this.deviceId = deviceId;
        this.context = context;
    }
    getBridgeSecret() {
        return vscode.workspace.getConfiguration('mordecai').get('bridgeSecret', '')?.trim() || '';
    }
    async fetch(path, options = {}) {
        const url = `${this.baseUrl}${path}`;
        const headers = {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            ...options.headers,
        };
        const secret = this.getBridgeSecret();
        if (secret) {
            headers['X-Bridge-Secret'] = secret;
        }
        return fetch(url, { ...options, headers });
    }
    loadPendingTaskFromFile() {
        try {
            if (fs.existsSync(PENDING_TASK_PATH)) {
                const raw = fs.readFileSync(PENDING_TASK_PATH, 'utf8');
                const task = JSON.parse(raw);
                if (task?.taskId && task?.prompt)
                    return task;
            }
        }
        catch {
            // Ignore
        }
        return null;
    }
    clearPendingTaskFile() {
        try {
            if (fs.existsSync(PENDING_TASK_PATH)) {
                fs.unlinkSync(PENDING_TASK_PATH);
            }
        }
        catch {
            // Ignore
        }
    }
    async poll() {
        // Check file first (from Python bridge when Cursor was closed)
        const fileTask = this.loadPendingTaskFromFile();
        if (fileTask) {
            this.currentTask = fileTask;
            this._onDidChangeTreeData.fire();
            vscode.window.showInformationMessage(`Mordecai: Task from bridge. Prompt copied. Paste in Composer (Ctrl+Shift+I) to run.`);
            vscode.env.clipboard.writeText(fileTask.prompt);
            this.clearPendingTaskFile();
            return;
        }
        if (!this.baseUrl)
            return;
        try {
            const res = await this.fetch(`/api/bridge/tasks/poll?deviceId=${encodeURIComponent(this.deviceId)}`);
            if (res.status === 204) {
                return;
            }
            if (!res.ok) {
                return;
            }
            const task = (await res.json());
            this.currentTask = task;
            this._onDidChangeTreeData.fire();
            vscode.env.clipboard.writeText(task.prompt);
            vscode.window.showInformationMessage(`Mordecai: New task from phone. Prompt copied. Paste in Composer (Ctrl+Shift+I) to run.`);
        }
        catch {
            // Ignore poll errors (network, etc.)
        }
    }
    async markDone(taskId) {
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
        }
        catch (e) {
            vscode.window.showErrorMessage(`Failed to mark done: ${e}`);
        }
    }
    async reportError(taskId, message) {
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
        }
        catch (e) {
            vscode.window.showErrorMessage(`Failed to report error: ${e}`);
        }
    }
    refresh() {
        this._onDidChangeTreeData.fire();
        this.poll();
    }
    getTreeItem(element) {
        const item = new vscode.TreeItem(element.label, element.task ? vscode.TreeItemCollapsibleState.None : vscode.TreeItemCollapsibleState.None);
        if (element.task) {
            item.contextValue = 'task';
            item.tooltip = element.task.prompt.slice(0, 200) + (element.task.prompt.length > 200 ? '...' : '');
            item.command = {
                command: 'mordecai.copyPrompt',
                title: 'Copy',
                arguments: [element],
            };
        }
        else {
            item.contextValue = 'empty';
        }
        return item;
    }
    getChildren() {
        if (this.currentTask) {
            return [
                {
                    task: this.currentTask,
                    label: `${this.currentTask.repoUrl.split('/').pop() || 'Task'} — ${this.currentTask.prompt.slice(0, 50)}...`,
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
exports.MordecaiTasksProvider = MordecaiTasksProvider;
//# sourceMappingURL=tasksProvider.js.map