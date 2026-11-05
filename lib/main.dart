import 'package:flutter/material.dart';

import 'app/tilawahku_app.dart';
import 'features/player/data/quran_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuranAudioHandler.initialize();
  runApp(const TilawahkuApp());
}
