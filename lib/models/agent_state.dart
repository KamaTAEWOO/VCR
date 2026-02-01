// TODO: Replace with package:vcr_shared AgentState + extension for
// client-only states (disconnected) and UI helpers (label, isAnimating).

/// Agent state enum matching PROTOCOL.md status values.
///
/// When shared package is ready, replace this with shared's definition.
enum AgentState {
  idle,
  running,
  hotReloading,
  hotRestarting,
  building,
  buildError,
  error,
  disconnected;

  /// Parse from wire-format string (snake_case from server).
  static AgentState fromString(String value) {
    switch (value) {
      case 'idle':
        return AgentState.idle;
      case 'running':
        return AgentState.running;
      case 'hot_reloading':
        return AgentState.hotReloading;
      case 'hot_restarting':
        return AgentState.hotRestarting;
      case 'building':
        return AgentState.building;
      case 'build_error':
        return AgentState.buildError;
      case 'error':
        return AgentState.error;
      default:
        return AgentState.idle;
    }
  }

  /// Convert to wire-format string (snake_case for server).
  String toWireString() {
    switch (this) {
      case AgentState.idle:
        return 'idle';
      case AgentState.running:
        return 'running';
      case AgentState.hotReloading:
        return 'hot_reloading';
      case AgentState.hotRestarting:
        return 'hot_restarting';
      case AgentState.building:
        return 'building';
      case AgentState.buildError:
        return 'build_error';
      case AgentState.error:
        return 'error';
      case AgentState.disconnected:
        return 'disconnected';
    }
  }

  /// Human-readable display label for UI.
  String get label {
    switch (this) {
      case AgentState.idle:
        return 'Idle';
      case AgentState.running:
        return 'Running';
      case AgentState.hotReloading:
        return 'Reloading...';
      case AgentState.hotRestarting:
        return 'Restarting...';
      case AgentState.building:
        return 'Building...';
      case AgentState.buildError:
        return 'Build Error';
      case AgentState.error:
        return 'Error';
      case AgentState.disconnected:
        return 'Disconnected';
    }
  }

  /// Whether this state implies an active animation (pulse or rotate).
  bool get isAnimating {
    switch (this) {
      case AgentState.hotReloading:
      case AgentState.hotRestarting:
      case AgentState.building:
        return true;
      default:
        return false;
    }
  }
}
