import 'package:flutter/material.dart';

class LeftTooltipFab extends StatefulWidget {
  const LeftTooltipFab({required this.message, required this.child, super.key});

  final String message;
  final Widget child;

  @override
  State<LeftTooltipFab> createState() => _LeftTooltipFabState();
}

class _LeftTooltipFabState extends State<LeftTooltipFab> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _visible = true),
      onExit: (_) => setState(() => _visible = false),
      child: Semantics(
        label: widget.message,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: [
            widget.child,
            Positioned(
              right: 48,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
