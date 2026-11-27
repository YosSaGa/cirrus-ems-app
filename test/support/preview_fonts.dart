import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Use the SDK's actual Material fonts for viewport/visual assertions instead
/// of Flutter test's square Ahem glyphs. Resolve the SDK from package_config.
Future<void> loadPreviewFonts() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final data = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final flutter = (data['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((e) => e['name'] == 'flutter');
  final package = Directory.fromUri(
    config.uri.resolve(flutter['rootUri'] as String),
  );
  final sdk = package.parent.parent;
  for (final spec in [
    ('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']),
    ('MaterialIcons', ['materialicons-regular.otf']),
  ]) {
    final loader = FontLoader(spec.$1);
    for (final name in spec.$2) {
      final bytes = await File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/$name',
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  for (final spec in [
    ('BebasNeue', 'assets/fonts/BebasNeue-Regular.ttf'),
    ('Sarabun', 'assets/fonts/Sarabun-Regular.ttf'),
  ]) {
    final loader = FontLoader(spec.$1);
    loader.addFont(File(spec.$2).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}
