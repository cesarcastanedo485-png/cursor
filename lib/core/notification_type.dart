/// Notification types from FCM data payload.
/// Maps payload "type" string to routes for deep linking.
enum NotificationType {
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
