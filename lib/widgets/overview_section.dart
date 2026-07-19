import 'package:flutter/material.dart';
import 'package:scyphomote/l10n/app_localizations.dart';

class OverviewSection extends StatefulWidget {
  final String overview;

  const OverviewSection({
    super.key,
    required this.overview,
  });

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(
          text: widget.overview,
          style: Theme.of(context).textTheme.bodyMedium,
        );
        final tp = TextPainter(
          text: textSpan,
          maxLines: 3,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final isTruncated = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.overview,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (isTruncated) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                child: Text(
                  _expanded ? l10n.showLess : l10n.showMore,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
