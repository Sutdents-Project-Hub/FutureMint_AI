import 'dart:async';

import 'package:flutter/material.dart';

import 'app/future_mint_app.dart';
import 'auth/auth_api.dart';
import 'auth/session_store.dart';
import 'data/api_repository.dart';
import 'data/guest_repository.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/',
  );
  final apiUri = Uri.parse(apiBaseUrl);
  final store = await SessionStore.create();
  final session = SessionController(
    auth: AuthApi(baseUri: apiUri),
    store: store,
    authenticatedRepository: (token) =>
        ApiRepository(baseUri: apiUri, accessToken: token),
    guestRepository: () => GuestRepository.create(marketBaseUri: apiUri),
  );
  runApp(FutureMintApp(session: session));
  unawaited(session.start());
}
