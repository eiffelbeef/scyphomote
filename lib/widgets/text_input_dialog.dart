import 'package:flutter/material.dart';

class TextInputDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String labelText;
  final String? hintText;
  final String? initialText;
  final int maxLines;
  final TextCapitalization textCapitalization;
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
    required this.onSend,
  });

  static void show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String labelText = 'Message',
    String? hintText,
    String? initialText,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    required Function(String message) onSend,
  }) {
    showDialog(
      context: context,
      builder: (context) => TextInputDialog(
        title: title,
        subtitle: subtitle,
        labelText: labelText,
        hintText: hintText,
        initialText: initialText,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _textController.text.trim();
            if (text.isNotEmpty) {
              widget.onSend(text);
              Navigator.pop(context);
            }
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
