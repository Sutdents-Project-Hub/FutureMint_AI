import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../state/session_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _registering = false;
  var _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(SessionController session) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (_registering) {
      await session.register(email: email, password: password);
    } else {
      await session.login(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);
    final shortViewport = MediaQuery.sizeOf(context).height < 700;
    final guestEntry = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: session.busy ? null : session.continueAsGuest,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('以訪客模式繼續'),
        ),
        const SizedBox(height: FutureMintTokens.space3),
        Text(
          '訪客模式可先體驗功能，但離開、重新整理或切換帳號後，資料不會儲存。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(FutureMintTokens.pageGutter(context)),
            child: LayoutBuilder(
              builder: (context, outerConstraints) {
                // Small widths, short browser windows, and enlarged text use
                // a compact composition. The artwork gets its own vertical
                // space instead of covering the heading or guest action.
                final compactViewport =
                    outerConstraints.maxWidth < 600 ||
                    shortViewport ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.3;
                final imageWidth = compactViewport
                    ? (outerConstraints.maxWidth * .52).clamp(160.0, 220.0)
                    : (outerConstraints.maxWidth * .52).clamp(240.0, 420.0);
                // The trio image is 4:3. Reserve its actual rendered height,
                // rather than its width, so the heading stays visually tied to
                // the artwork on wide browser windows.
                final artworkHeight = imageWidth * .75;
                final formTop =
                    artworkHeight +
                    (compactViewport
                        ? FutureMintTokens.space4
                        : FutureMintTokens.space6);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Large mascot trio, NOT constrained by the 460px form width.
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        key: const Key('auth-artwork-slot'),
                        width: imageWidth,
                        height: artworkHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/mascot_trio.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            if (!compactViewport) ...[
                              Positioned(
                                left: imageWidth * 0.08,
                                top: -20,
                                child: IgnorePointer(
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 44,
                                    color: const Color(
                                      0xFF7CFF4D,
                                    ).withValues(alpha: .85),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: imageWidth * 0.06,
                                top: -34,
                                child: IgnorePointer(
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 56,
                                    color: FutureMintTokens.neonPurple
                                        .withValues(alpha: .85),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: imageWidth * 0.42,
                                child: IgnorePointer(
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 34,
                                    color: Colors.white.withValues(alpha: .55),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: imageWidth * 0.48,
                                child: IgnorePointer(
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 36,
                                    color: Colors.white.withValues(alpha: .55),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Form content is capped at 460px and kept close to the
                    // artwork without allowing the two to overlap.
                    Padding(
                      padding: EdgeInsets.only(top: formTop),
                      child: ConstrainedBox(
                        key: const Key('auth-form-content'),
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PageHeading(
                              kicker: '你的金錢節奏',
                              title: _registering ? '建立你的帳號' : '登入 FutureMint',
                              description: _registering
                                  ? '建立帳號後，預算、紀錄與微課只會屬於你。'
                                  : '登入後，繼續查看自己的預算與下一步。',
                              accent: FutureMintTokens.teal,
                            ),
                            const SizedBox(height: FutureMintTokens.space5),
                            if (compactViewport) ...[
                              guestEntry,
                              const SizedBox(height: FutureMintTokens.space5),
                            ],
                            SoftCard(
                              borderWidth: 1,
                              color: theme.brightness == Brightness.dark
                                  ? FutureMintTokens.darkSurfaceRaised
                                  : FutureMintTokens.paper,
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SegmentedButton<bool>(
                                      segments: const [
                                        ButtonSegment(
                                          value: false,
                                          label: Text('登入'),
                                        ),
                                        ButtonSegment(
                                          value: true,
                                          label: Text('建立帳號'),
                                        ),
                                      ],
                                      selected: {_registering},
                                      onSelectionChanged: session.busy
                                          ? null
                                          : (next) => setState(
                                              () => _registering = next.single,
                                            ),
                                    ),
                                    const SizedBox(
                                      height: FutureMintTokens.space5,
                                    ),
                                    TextFormField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: '電子郵件',
                                        hintText: 'name@example.com',
                                      ),
                                      validator: (value) {
                                        final email = value?.trim() ?? '';
                                        if (!email.contains('@') ||
                                            !email.contains('.')) {
                                          return '請輸入有效的電子郵件，例如 name@example.com。';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(
                                      height: FutureMintTokens.space4,
                                    ),
                                    TextFormField(
                                      controller: _password,
                                      obscureText: !_showPassword,
                                      autofillHints: [
                                        _registering
                                            ? AutofillHints.newPassword
                                            : AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: '密碼',
                                        helperText: _registering
                                            ? '至少 12 個字元，並包含英文字母與數字。'
                                            : null,
                                        suffixIcon: IconButton(
                                          tooltip: _showPassword
                                              ? '隱藏密碼'
                                              : '顯示密碼',
                                          onPressed: () => setState(
                                            () =>
                                                _showPassword = !_showPassword,
                                          ),
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        final password = value ?? '';
                                        if (password.length < 12 ||
                                            !RegExp(
                                              r'[A-Za-z]',
                                            ).hasMatch(password) ||
                                            !RegExp(r'\d').hasMatch(password)) {
                                          return '密碼至少 12 個字元，且需包含英文字母與數字。';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (session.message != null) ...[
                                      const SizedBox(
                                        height: FutureMintTokens.space4,
                                      ),
                                      Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          session.message!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: theme.colorScheme.error,
                                              ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(
                                      height: FutureMintTokens.space5,
                                    ),
                                    FilledButton.icon(
                                      onPressed: session.busy
                                          ? null
                                          : () => _submit(session),
                                      icon: Icon(
                                        _registering
                                            ? Icons.person_add_alt_1_outlined
                                            : Icons.login_rounded,
                                      ),
                                      label: Text(
                                        session.busy
                                            ? '正在處理…'
                                            : _registering
                                            ? '建立帳號'
                                            : '登入',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!compactViewport) ...[
                              const SizedBox(height: FutureMintTokens.space5),
                              guestEntry,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
