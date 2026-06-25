import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  String? currentlySpeakingId;
  Function(String?)? onSpeakStateChanged;

  Future<void> init() async {
    if (_isInitialized) return;
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      // Started handler
    });

    _flutterTts.setCompletionHandler(() {
      currentlySpeakingId = null;
      onSpeakStateChanged?.call(null);
    });

    _flutterTts.setCancelHandler(() {
      currentlySpeakingId = null;
      onSpeakStateChanged?.call(null);
    });

    _flutterTts.setErrorHandler((msg) {
      currentlySpeakingId = null;
      onSpeakStateChanged?.call(null);
    });

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await init();
    await _flutterTts.stop();
    if (text.isNotEmpty) {
      final cleanText = _cleanupMarkdown(text);
      await _flutterTts.speak(cleanText);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    currentlySpeakingId = null;
    onSpeakStateChanged?.call(null);
  }

  String _cleanupMarkdown(String markdown) {
    // Remove code blocks
    var text = markdown.replaceAll(RegExp(r'```[\s\S]*?```'), '[code block]');
    // Remove inline code
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // Remove asterisks & underscores for bold/italic
    text = text.replaceAll(RegExp(r'[\*_]+'), '');
    // Remove headings markers
    text = text.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
    // Remove link markups [Label](URL) -> Label
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    return text;
  }
}
