/// User-selectable intent presets for agent prompts and follow-ups.
enum AgentIntent { ask, plan, debug }

extension AgentIntentX on AgentIntent {
  String get label {
    switch (this) {
      case AgentIntent.ask:
        return 'Ask';
      case AgentIntent.plan:
        return 'Plan';
      case AgentIntent.debug:
        return 'Debug';
    }
  }

  String get shortDescription {
    switch (this) {
      case AgentIntent.ask:
        return 'General request. Best for normal coding or Q&A tasks.';
      case AgentIntent.plan:
        return 'Start with a concise implementation plan, then execute.';
      case AgentIntent.debug:
        return 'Prioritize root-cause analysis, smallest safe fix, and verification.';
    }
  }
}

/// Adds intent instructions without requiring backend schema changes.
String buildPromptForIntent(AgentIntent intent, String userPrompt) {
  switch (intent) {
    case AgentIntent.ask:
      return userPrompt;
    case AgentIntent.plan:
      return [
        'Intent: Plan',
        'First provide a concise implementation plan, then execute the work in ordered steps.',
        userPrompt,
      ].join('\n\n');
    case AgentIntent.debug:
      return [
        'Intent: Debug',
        'Treat this as a debugging task: reproduce the issue, identify root cause, explain findings, and apply the smallest safe fix with verification.',
        userPrompt,
      ].join('\n\n');
  }
}
