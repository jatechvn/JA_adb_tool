import 'dart:async';
import 'package:flutter/material.dart';
import '../logic.dart';
import '../services/helper_ime_session.dart';
import 'localization.dart';

class HelperImeDialog extends StatefulWidget {
  const HelperImeDialog({
    super.key,
    required this.logic,
    required this.session,
  });
  final AppLogic logic;
  final HelperImeSession session;
  @override
  State<HelperImeDialog> createState() => _HelperImeDialogState();
}

class _HelperImeDialogState extends State<HelperImeDialog> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _ack = false,
      _busy = false,
      _closing = false,
      _invalidated = false,
      _allowPop = false;
  int _action = 6;
  String? _status;
  bool get _composing =>
      _text.value.composing.isValid && !_text.value.composing.isCollapsed;
  @override
  void initState() {
    super.initState();
    _text.addListener(_refresh);
    widget.logic.addListener(_deviceChanged);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _deviceChanged() {
    if (widget.logic.selectedDevice != widget.session.device && !_invalidated) {
      _invalidated = true;
      widget.session.invalidate();
      unawaited(_finish());
    }
  }

  Future<void> _perform(
    Future<void> Function() operation, {
    bool sending = false,
  }) async {
    if (_busy || _invalidated) return;
    if (sending && _composing) return;
    final submitted = _text.text;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await operation();
      if (!mounted || _closing) return;
      if (sending && _text.text == submitted) _text.clear();
      setState(() => _status = sending ? 'helper_sent' : null);
      _focus.requestFocus();
    } catch (error) {
      if (error is StateError && error.message == 'helper_restore_failed') {
        _invalidated = true;
      }
      if (mounted && !_closing) {
        setState(
          () => _status = error is StateError
              ? error.message.toString()
              : 'helper_command_failed',
        );
      }
    } finally {
      if (mounted && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _busy = true;
    });
    try {
      await widget.session.close();
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _closing = false;
          _busy = false;
          _invalidated = true;
          _status = 'helper_restore_failed';
        });
      }
    }
  }

  @override
  void dispose() {
    widget.logic.removeListener(_deviceChanged);
    _text.removeListener(_refresh);
    _text.dispose();
    _focus.dispose();
    // Best effort only for forced route/app teardown; ordinary Close awaits restore.
    unawaited(widget.session.close().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_finish());
    },
    child: AlertDialog(
      title: Text('${context.tr('helper_title')} — ${widget.session.device}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('helper_warning')),
              if (!widget.session.active) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('helper_ack')),
                  value: _ack,
                  onChanged: _busy || _invalidated
                      ? null
                      : (value) => setState(() => _ack = value ?? false),
                ),
                FilledButton(
                  onPressed: !_ack || _busy || _invalidated
                      ? null
                      : () => _perform(widget.session.activate),
                  child: Text(context.tr('helper_enable')),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('helper-text'),
                controller: _text,
                focusNode: _focus,
                enabled: widget.session.active && !_busy && !_invalidated,
                minLines: 2,
                maxLines: 4,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.tr('helper_text'),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const ValueKey('helper-send'),
                    onPressed:
                        !widget.session.active ||
                            _busy ||
                            _invalidated ||
                            _composing ||
                            _text.text.isEmpty
                        ? null
                        : () => _perform(
                            () => widget.session.sendText(_text.text),
                            sending: true,
                          ),
                    child: Text(context.tr('helper_send')),
                  ),
                  OutlinedButton(
                    onPressed: !widget.session.active || _busy || _invalidated
                        ? null
                        : () => _perform(widget.session.backspace),
                    child: const Text('⌫'),
                  ),
                  OutlinedButton(
                    onPressed: !widget.session.active || _busy || _invalidated
                        ? null
                        : () => _perform(
                            () => widget.session.editorAction(_action),
                          ),
                    child: const Text('Enter'),
                  ),
                ],
              ),
              DropdownButton<int>(
                value: _action,
                isExpanded: true,
                items: [
                  for (final code in [2, 3, 4, 5, 6])
                    DropdownMenuItem(
                      value: code,
                      child: Text(context.tr('helper_action_$code')),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _action = value ?? 6),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_status != null) Text(context.tr(_status!)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : _finish,
          child: Text(context.tr('helper_close')),
        ),
      ],
    ),
  );
}
