import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuidedTourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final FutureOr<void> Function()? onStepEnter;

  const GuidedTourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.onStepEnter,
  });
}

typedef FutureOr<T> = dynamic;

class GuidedTourOverlay extends StatefulWidget {
  final List<GuidedTourStep> steps;
  final VoidCallback onFinish;
  final Widget child;
  final bool isActive;

  const GuidedTourOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    required this.child,
    required this.isActive,
  });

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay> {
  int _currentIndex = 0;
  Rect? _targetRect;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _activateStep(0);
    }
  }

  @override
  void didUpdateWidget(covariant GuidedTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _activateStep(0);
    } else if (!widget.isActive && oldWidget.isActive) {
      setState(() {
        _targetRect = null;
        _currentIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _activateStep(int index) async {
    if (index < 0 || index >= widget.steps.length) return;
    setState(() {
      _currentIndex = index;
    });

    final step = widget.steps[index];
    if (step.onStepEnter != null) {
      await step.onStepEnter!();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      _measureTarget();
      _focusNode.requestFocus();
    });
  }

  void _measureTarget() {
    final step = widget.steps[_currentIndex];
    final context = step.targetKey.currentContext;
    if (context == null) {
      setState(() => _targetRect = null);
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    final overlayBox = this.context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || overlayBox == null) {
      setState(() => _targetRect = null);
      return;
    }
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    setState(() {
      _targetRect = (topLeft & renderBox.size).inflate(6);
    });
  }

  void _nextStep() {
    if (_currentIndex + 1 < widget.steps.length) {
      _activateStep(_currentIndex + 1);
    } else {
      widget.onFinish();
    }
  }

  void _prevStep() {
    if (_currentIndex > 0) {
      _activateStep(_currentIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || widget.steps.isEmpty) {
      return widget.child;
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onFinish();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _nextStep();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prevStep();
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          final step = widget.steps[_currentIndex];
          final isLast = _currentIndex == widget.steps.length - 1;

          return Stack(
            children: [
              widget.child,
              // Dimmed Spotlight Cutout Layer
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Block stray clicks outside controls
                  child: CustomPaint(
                    painter: _SpotlightPainter(targetRect: _targetRect),
                  ),
                ),
              ),
              // Floating Tooltip Card
              _buildTooltipCard(screenSize, step, isLast),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTooltipCard(Size screenSize, GuidedTourStep step, bool isLast) {
    const double cardWidth = 420.0;
    const double estimatedCardHeight = 250.0;
    const double margin = 16.0;

    double left = (screenSize.width - cardWidth) / 2;
    double top = (screenSize.height - estimatedCardHeight) / 2;

    if (_targetRect != null) {
      final rect = _targetRect!;
      // Horizontal alignment clamped inside viewport
      left = rect.left.clamp(
        margin,
        math.max(margin, screenSize.width - cardWidth - margin),
      );

      // Prefer placing below target; if insufficient room, place above or inside
      final spaceBelow = screenSize.height - rect.bottom;
      final spaceAbove = rect.top;

      if (spaceBelow >= estimatedCardHeight + margin) {
        top = rect.bottom + 12;
      } else if (spaceAbove >= estimatedCardHeight + margin) {
        top = rect.top - estimatedCardHeight - 12;
      } else {
        // Target is a large full-height panel: place card inside top-right or center
        top = math.max(margin + 60, rect.top + 24);
        left = math.min(
          rect.right - cardWidth - 24,
          screenSize.width - cardWidth - margin,
        ).clamp(margin, screenSize.width - cardWidth - margin);
      }
      top = top.clamp(
        margin,
        math.max(margin, screenSize.height - estimatedCardHeight - margin),
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: cardWidth,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF007ACC), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007ACC).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF007ACC).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'DEMO WALKTHROUGH • STEP ${_currentIndex + 1} OF ${widget.steps.length}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onFinish,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFFD4D4D4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onFinish,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'End Demo',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentIndex > 0) ...[
                        OutlinedButton(
                          onPressed: _prevStep,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Color(0xFF3E3E42)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Back', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      FilledButton.icon(
                        onPressed: _nextStep,
                        style: FilledButton.styleFrom(
                          backgroundColor: isLast
                              ? const Color(0xFF10B981)
                              : const Color(0xFF007ACC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          isLast ? Icons.check_circle_outline : Icons.arrow_forward,
                          size: 14,
                        ),
                        label: Text(
                          isLast ? 'Finish & Clear' : 'Next',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;

  _SpotlightPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawPath(fullPath, dimPaint);
      return;
    }

    final rrect = RRect.fromRectAndRadius(
      targetRect!,
      const Radius.circular(8),
    );
    final cutoutPath = Path()..addRRect(rrect);
    final combinedPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cutoutPath,
    );

    canvas.drawPath(combinedPath, dimPaint);

    // Draw glowing accent border around the spotlight cutout
    final glowPaint = Paint()
      ..color = const Color(0xFF007ACC).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect, glowPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}
