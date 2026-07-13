import 'dart:async';

import 'package:flutter/material.dart';

import 'app/future_mint_app.dart';
import 'core/future_mint_repository.dart';
import 'core/models.dart';
import 'data/api_repository.dart';
import 'data/demo_repository.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const configuredMode = String.fromEnvironment(
    'APP_MODE',
    defaultValue: 'offline-demo',
  );
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  late final AppMode mode;
  late final FutureMintRepository repository;
  if (configuredMode == 'connected') {
    if (apiBaseUrl.trim().isEmpty) {
      throw StateError('APP_MODE=connected 時必須提供 API_BASE_URL。');
    }
    mode = AppMode.connected;
    repository = ApiRepository(baseUri: Uri.parse(apiBaseUrl));
  } else if (configuredMode == 'offline-demo') {
    mode = AppMode.offlineDemo;
    repository = await DemoRepository.create();
  } else {
    throw StateError('APP_MODE 只接受 connected 或 offline-demo。');
  }

  final controller = AppController(repository: repository, mode: mode);
  runApp(FutureMintApp(controller: controller));
  unawaited(controller.initialize());
}
