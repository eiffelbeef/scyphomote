import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../utils/logger.dart';
import '../utils/ui_utils.dart';

class CrashLogScreen extends StatefulWidget {
  static const routeName = '/crash-logs';
  const CrashLogScreen({super.key});

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  String _logContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    final content = await CrashLog.read();
    setState(() {
      _logContent = content.trim();
      _isLoading = false;
    });
  }

  Future<void> _clearLog() async {
    await CrashLog.clear();
    setState(() => _logContent = '');
  }

  void _copyAll() {
    if (_logContent.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _logContent));
    UiUtils.showSnackBar(context, l10n.crashLogsCopied);
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    final isEmpty = _logContent.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.crashLogsTitle),
        actions: [
          if (!isEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: l10n.crashLogsCopy,
              onPressed: _copyAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.crashLogsClear,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.crashLogsClear),
                    content: Text(l10n.crashLogsClearConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.crashLogsClear),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) _clearLog();
              },
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.crashLogsEmpty,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _logContent,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                  ),
                ),
    );
  }
}
