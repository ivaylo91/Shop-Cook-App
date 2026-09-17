import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/ui/ui.dart';

/// Listens once and returns what was said, or null if nothing was.
///
/// Uses the phone's own recognizer, in the app's language when the phone
/// has it, so "мляко" is heard as мляко and not as "mlyako".
Future<String?> captureSpeech(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (_) => const _VoiceSheet(),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

enum _Phase { starting, listening, unavailable }

class _VoiceSheetState extends State<_VoiceSheet> {
  final _speech = SpeechToText();
  _Phase _phase = _Phase.starting;
  String _heard = '';
  double _level = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        // "done" arrives after the final result, or on silence.
        if (status == SpeechToText.doneStatus) _finish();
      },
      onError: (_) => _finish(),
    );
    if (!mounted) return;
    if (!available) {
      setState(() => _phase = _Phase.unavailable);
      return;
    }

    final language = Localizations.localeOf(context).languageCode;
    final locales = await _speech.locales();
    final match = locales
        .where((l) => l.localeId.toLowerCase().startsWith(language))
        .firstOrNull;

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _heard = result.recognizedWords);
        if (result.finalResult) _finish();
      },
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _level = level);
      },
      listenOptions: SpeechListenOptions(
        localeId: match?.localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        // A list is said with pauses while people think of the next thing.
        pauseFor: const Duration(seconds: 3),
      ),
    );
    if (mounted) setState(() => _phase = _Phase.listening);
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    final text = _heard.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  Future<void> _stop() async {
    await _speech.stop();
    // Some recognizers deliver no final result after a manual stop.
    Future<void>.delayed(const Duration(milliseconds: 600), _finish);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    if (_phase == _Phase.unavailable) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: InlineNote(message: l10n.voiceUnavailable),
        ),
      );
    }

    // Grows with the voice so it is clear the phone is hearing something.
    final pulse = 1 + (_level.clamp(0, 10) / 25);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.md,
          Insets.xl,
          Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.voiceTitle,
              style: AppText.title.copyWith(color: palette.ink),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              l10n.voiceHint,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: Insets.xl),
            GestureDetector(
              onTap: _phase == _Phase.listening ? _stop : null,
              child: AnimatedScale(
                scale: pulse,
                duration: Motion.fast,
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.microphone,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Insets.xl),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Text(
                _heard.isEmpty ? l10n.voiceListening : _heard,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(
                  fontSize: 18,
                  color: _heard.isEmpty ? palette.inkFaint : palette.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
