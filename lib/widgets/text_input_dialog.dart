import 'package:flutter/material.dart';
import 'package:scyphomote/l10n/app_localizations.dart';

class TextInputDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String labelText;
  final String? hintText;
  final String? initialText;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final Function(String message) onSend;

  const TextInputDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.labelText = 'Message',
    this.hintText,
    this.initialText,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
    this.keyboardType,
    required this.onSend,
  });

  static void show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String? labelText,
    String? hintText,
    String? initialText,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    TextInputType? keyboardType,
    required Function(String message) onSend,
  }) {
    showDialog(
      context: context,
      builder: (context) => TextInputDialog(
        title: title,
        subtitle: subtitle,
        labelText: labelText ?? AppLocalizations.of(context)!.message,
        hintText: hintText,
        initialText: initialText,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        keyboardType: keyboardType,
        onSend: onSend,
      ),
    );
  }

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: widget.textCapitalization,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            autofocus: true,
            onSubmitted: widget.maxLines == 1
                ? (val) {
                    final text = val.trim();
                    if (text.isNotEmpty) {
                      widget.onSend(text);
                      Navigator.pop(context);
                    }
                  }
                : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _textController.text.trim();
            if (text.isNotEmpty) {
              widget.onSend(text);
              Navigator.pop(context);
            }
          },
          child: Text(AppLocalizations.of(context)!.send),
        ),
      ],
    );
  }
}
