import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../app/providers.dart';

class _SaveCaptureIntent extends Intent {
  const _SaveCaptureIntent();
}

/// Quick capture: type or dictate, then save to inbox or library.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  String _speechStatus = '';
  bool _saveToInbox = true;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (s) {
        if (mounted) setState(() => _speechStatus = s);
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _speechStatus = e.errorMsg;
            _listening = false;
          });
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    if (_listening) {
      unawaited(_speech.stop());
    }
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (!_speechAvailable) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _bodyController.text = result.recognizedWords;
            _bodyController.selection = TextSelection.collapsed(
              offset: _bodyController.text.length,
            );
          });
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(notesRepositoryProvider);
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty) {
      if (mounted) context.pop();
      return;
    }
    await repo.createNote(
      title: title.isEmpty ? null : title,
      body: body,
      inInbox: _saveToInbox,
    );
    if (mounted) {
      HapticFeedback.lightImpact();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = Platform.isMacOS || Platform.isIOS;
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
        LogicalKeySet(
          meta ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyS,
        ): const _SaveCaptureIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              context.pop();
              return null;
            },
          ),
          _SaveCaptureIntent: CallbackAction<_SaveCaptureIntent>(
            onInvoke: (_) {
              unawaited(_save());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
              title: const Text('New thought'),
              actions: [
                TextButton(
                  onPressed: () => unawaited(_save()),
                  child: Text(
                    Platform.isMacOS || Platform.isIOS
                        ? 'Save  ⌘S'
                        : 'Save  Ctrl+S',
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  title: const Text('Send to inbox'),
                  subtitle: const Text('Off saves directly to library'),
                  value: _saveToInbox,
                  onChanged: (v) => setState(() => _saveToInbox = v),
                ),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Thought', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (!_speechAvailable)
                      Text(
                        Platform.isMacOS ||
                                Platform.isLinux ||
                                Platform.isWindows
                            ? 'Speech may be limited on desktop'
                            : 'Speech unavailable',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    IconButton.filledTonal(
                      tooltip: _listening ? 'Stop dictation' : 'Dictate',
                      onPressed: _speechAvailable ? _toggleListen : null,
                      icon: Icon(_listening ? Icons.stop : Icons.mic),
                    ),
                  ],
                ),
                if (_speechStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _speechStatus,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                TextField(
                  controller: _bodyController,
                  minLines: 8,
                  maxLines: 20,
                  decoration: const InputDecoration(
                    hintText: 'Type or tap the microphone…',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
