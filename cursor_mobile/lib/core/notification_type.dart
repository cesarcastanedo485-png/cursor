/// Notification types from FCM data payload.
/// Maps payload "type" string to routes for deep linking.
enum NotificationType {
  agentCreating,
  agentRunning,
  agentFinished,
  agentExpired,
  assistantMessage,
  agentCompleted,
  agentError,
  agentStarted,
  prReviewRequested,
  repoSynced,
  achievementUnlocked,
  achievementMilestone,
  chatError,
  systemUpdate,
  unknown;

  static NotificationType fromString(String? s) {
    if (s == null || s.isEmpty) return NotificationType.unknown;
    switch (s.toLowerCase()) {
      case 'agent_creating':
        return NotificationType.agentCreating;
      case 'agent_running':
        return NotificationType.agentRunning;
      case 'agent_finished':
        return NotificationType.agentFinished;
      case 'agent_expired':
        return NotificationType.agentExpired;
      case 'assistant_message':
        return NotificationType.assistantMessage;
      case 'agent_completed':
        return NotificationType.agentCompleted;
      case 'agent_error':
        return NotificationType.agentError;
      case 'agent_started':
        return NotificationType.agentStarted;
      case 'pr_review_requested':
        return NotificationType.prReviewRequested;
      case 'repo_synced':
        return NotificationType.repoSynced;
      case 'achievement_unlocked':
        return NotificationType.achievementUnlocked;
      case 'achievement_milestone':
        return NotificationType.achievementMilestone;
      case 'chat_error':
        return NotificationType.chatError;
      case 'system_update':
        return NotificationType.systemUpdate;
      default:
        return NotificationType.unknown;
    }
  }

  /// Route path for deep linking (e.g. /agent, /repos, /achievements).
  String get routePath {
    switch (this) {
      case NotificationType.agentCreating:
      case NotificationType.agentRunning:
      case NotificationType.agentFinished:
      case NotificationType.agentExpired:
      case NotificationType.assistantMessage:
      case NotificationType.agentCompleted:
      case NotificationType.agentError:
      case NotificationType.agentStarted:
        return '/agent';
      case NotificationType.prReviewRequested:
      case NotificationType.repoSynced:
        return '/repos';
      case NotificationType.achievementUnlocked:
      case NotificationType.achievementMilestone:
        return '/achievements';
      case NotificationType.chatError:
      case NotificationType.systemUpdate:
      case NotificationType.unknown:
        return '/';
    }
  }
}
