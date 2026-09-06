import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/future_mint_app.dart';
import 'auth/auth_api.dart';
import 'auth/session_store.dart';
import 'core/release_config.dart';
import 'data/api_repository.dart';
import 'data/guest_repository.dart';
import 'design/theme.dart';
import 'state/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FutureMintBootstrap());
}

Future<SessionController> _createSession() async {
  final config = ReleaseConfig.current;
  config.validateForRuntime(isReleaseMode: kReleaseMode);
  final apiUri = config.apiBaseUri;
  final store = await SessionStore.create();
  return SessionController(
    auth: AuthApi(baseUri: apiUri),
    store: store,
    authenticatedRepository: (token) =>
        ApiRepository(baseUri: apiUri, accessToken: token),
    guestRepository: () => GuestRepository.create(marketBaseUri: apiUri),
  );
}

class FutureMintBootstrap extends StatefulWidget {
  const FutureMintBootstrap({super.key, this.sessionFactory = _createSession});

  final Future<SessionController> Function() sessionFactory;

  @override
  State<FutureMintBootstrap> createState() => _FutureMintBootstrapState();
}

class _FutureMintBootstrapState extends State<FutureMintBootstrap> {
  late Future<SessionController> _pending = _load();
  SessionController? _session;

  Future<SessionController> _load() async {
    final session = await widget.sessionFactory();
    if (mounted) {
      _session = session;
      unawaited(session.start());
    } else {
      session.dispose();
    }
    return session;
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SessionController>(
    future: _pending,
    builder: (context, snapshot) {
      if (snapshot.hasData) return FutureMintApp(session: snapshot.data!);
      return MaterialApp(
        title: 'FutureMint AI',
        debugShowCheckedModeBanner: false,
        theme: FutureMintTheme.light(),
        darkTheme: FutureMintTheme.dark(),
        locale: const Locale('zh', 'TW'),
        supportedLocales: const [Locale('zh', 'TW')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child:
                    snapshot.hasError &&
                        snapshot.connectionState == ConnectionState.done
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.restart_alt, size: 48),
                          const SizedBox(height: 16),
                          const Text('目前無法啟動 FutureMint，請再試一次。'),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              final pending = _load();
                              // Listen immediately; the next frame may attach
                              // FutureBuilder after a platform failure arrives.
                              pending.ignore();
                              setState(() {
                                _pending = pending;
                              });
                            },
                            child: const Text('重新嘗試'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    },
  );
}
