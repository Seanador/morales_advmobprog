import 'package:flutter_dotenv/flutter_dotenv.dart';

String get host {
  final configured = dotenv.isInitialized ? dotenv.env['HOST']?.trim() : null;
  return configured == null || configured.isEmpty
      ? 'https://dummyjson.com'
      : configured.replaceFirst(RegExp(r'/+$'), '');
}
