import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../state/app_controller.dart';
import 'app_router.dart';

class FutureMintApp extends StatefulWidget {
  const FutureMintApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<FutureMintApp> createState() => _FutureMintAppState();
}

class _FutureMintAppState extends State<FutureMintApp> {
  late final router = createAppRouter();

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: widget.controller,
    child: Consumer<AppController>(
      builder: (context, controller, _) => MaterialApp.router(
        title: 'FutureMint AI',
        debugShowCheckedModeBanner: false,
        theme: FutureMintTheme.light(),
        darkTheme: FutureMintTheme.dark(),
        themeMode: controller.themeMode,
        routerConfig: router,
      ),
    ),
  );
}
