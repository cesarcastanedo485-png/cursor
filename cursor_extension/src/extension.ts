import * as vscode from 'vscode';
import { MordecaiTasksProvider } from './tasksProvider';

let pollInterval: NodeJS.Timeout | null = null;

export function activate(context: vscode.ExtensionContext) {
  const config = vscode.workspace.getConfiguration('mordecai');
  const baseUrl = config.get<string>('maximusUrl', '').trim();

  if (!baseUrl) {
    vscode.window.showInformationMessage(
      'Mordecai Maximus: Set mordecai.maximusUrl in Settings to receive tasks from your phone.',
    );
    return;
  }

  // Ensure we have a device ID (persisted)
  let deviceId = context.globalState.get<string>('mordecai.deviceId');
  if (!deviceId) {
    deviceId = 'ext-' + Math.random().toString(36).slice(2, 15);
    context.globalState.update('mordecai.deviceId', deviceId);
  }

  const tasksProvider = new MordecaiTasksProvider(baseUrl, deviceId, context);
  context.subscriptions.push(
    vscode.window.registerTreeDataProvider('mordecaiTasks', tasksProvider),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('mordecai.refreshTasks', () => {
      tasksProvider.refresh();
    }),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('mordecai.copyPrompt', (item: TaskItem) => {
      if (item.task) {
        vscode.env.clipboard.writeText(item.task.prompt);
        vscode.window.showInformationMessage(
          'Prompt copied. Paste in Composer (Ctrl+Shift+I / Cmd+Shift+I) to run.',
        );
      }
    }),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('mordecai.runInComposer', async (item: TaskItem) => {
      if (!item.task) return;
      try {
        const commands = await vscode.commands.getCommands();
        const composerCmd = commands.find(
          (c) =>
            c.includes('composer') ||
            c.includes('aider') ||
            c === 'cursor.chat.new' ||
            c === 'workbench.action.quickOpen',
        );
        vscode.env.clipboard.writeText(item.task.prompt);
        if (composerCmd) {
          await vscode.commands.executeCommand(composerCmd);
        }
        vscode.window.showInformationMessage(
          'Prompt copied. Paste in Composer (Ctrl+Shift+I) to run.',
        );
      } catch {
        vscode.env.clipboard.writeText(item.task.prompt);
        vscode.window.showInformationMessage(
          'Prompt copied. Paste in Composer (Ctrl+Shift+I / Cmd+Shift+I) to run.',
        );
      }
    }),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('mordecai.markDone', async (item: TaskItem) => {
      if (!item.task) return;
      await tasksProvider.markDone(item.task.taskId);
    }),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('mordecai.reportError', async (item: TaskItem) => {
      if (!item.task) return;
      const msg = await vscode.window.showInputBox({
        prompt: 'Error message (optional)',
        placeHolder: 'What went wrong?',
      });
      await tasksProvider.reportError(item.task.taskId, msg || '');
    }),
  );

  const pollSeconds = config.get<number>('pollIntervalSeconds', 20);
  const pollMs = Math.max(10, pollSeconds) * 1000;
  pollInterval = setInterval(() => tasksProvider.poll(), pollMs);
  tasksProvider.poll();
}

export function deactivate() {
  if (pollInterval) {
    clearInterval(pollInterval);
    pollInterval = null;
  }
}

export interface BridgeTask {
  taskId: string;
  prompt: string;
  repoUrl: string;
  branch?: string;
  intent?: string;
}

export interface TaskItem {
  task?: BridgeTask;
  label: string;
}
