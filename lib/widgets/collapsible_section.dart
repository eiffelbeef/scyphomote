import 'package:flutter/material.dart';

class CollapsibleSection extends StatelessWidget {
  final String title;
  final bool isCollapsible;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.isCollapsible,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final showContent = !isCollapsible || isExpanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isCollapsible ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isCollapsible)
                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
        if (showContent) child,
      ],
    );
  }
}
