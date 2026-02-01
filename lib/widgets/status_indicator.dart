import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/agent_state.dart';

/// Animated status dot + label that reflects the current [AgentState].
///
/// Shows a colored dot that pulses (building) or an icon that rotates
/// (reloading/restarting), matching UI_SPEC.md section 4.1.
class StatusIndicator extends StatefulWidget {
  final AgentState state;

  const StatusIndicator({super.key, required this.state});

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.duration = _animationDuration;
      _updateAnimation();
    }
  }

  Duration get _animationDuration {
    switch (widget.state) {
      case AgentState.building:
        return VcrDurations.pulse;
      case AgentState.hotReloading:
      case AgentState.hotRestarting:
        return VcrDurations.rotate;
      default:
        return VcrDurations.pulse;
    }
  }

  void _updateAnimation() {
    if (widget.state.isAnimating) {
      _controller.repeat(reverse: _isPulse);
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  bool get _isPulse => widget.state == AgentState.building;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForState(widget.state);
    final label = widget.state.label;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIndicator(color),
        const SizedBox(width: Spacing.xs),
        Text(
          label,
          style: VcrTypography.labelMedium.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _buildIndicator(Color color) {
    // Rotating icon for reload/restart states
    if (widget.state == AgentState.hotReloading ||
        widget.state == AgentState.hotRestarting) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * 3.14159265,
            child: Icon(
              Icons.refresh,
              size: 14,
              color: color,
            ),
          );
        },
      );
    }

    // Pulsing dot for building state
    if (widget.state == AgentState.building) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final size = 8.0 + (_controller.value * 4.0); // 8dp -> 12dp
          return AnimatedContainer(
            duration: VcrDurations.statusTransition,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          );
        },
      );
    }

    // Static dot for all other states
    return AnimatedContainer(
      duration: VcrDurations.statusTransition,
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  static Color _colorForState(AgentState state) {
    switch (state) {
      case AgentState.idle:
        return VcrColors.stateIdle;
      case AgentState.running:
        return VcrColors.stateRunning;
      case AgentState.hotReloading:
      case AgentState.hotRestarting:
        return VcrColors.stateReloading;
      case AgentState.building:
        return VcrColors.stateBuilding;
      case AgentState.buildError:
      case AgentState.error:
        return VcrColors.stateError;
      case AgentState.disconnected:
        return VcrColors.stateDisconnected;
    }
  }
}

/// Helper: AnimatedBuilder is just AnimatedWidget, using a builder callback.
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
