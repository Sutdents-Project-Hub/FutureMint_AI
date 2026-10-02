import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/public_links.dart';
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
  final _passwordConfirmation = TextEditingController();
  final _confirmationKey = GlobalKey<FormFieldState<String>>();
  var _registering = false;
  var _showPassword = false;
  var _showPasswordConfirmation = false;
  String? _ageBand;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> _submit(SessionController session) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (_registering) {
      if (session.servicePolicy?.registrationEnabled == false) {
        session.message = '此服務目前未開放新帳號，請先使用訪客模式。';
        setState(() {});
        return;
      }
      if (_ageBand == null) {
        session.message = '請選擇使用者年齡並確認聲明。';
        setState(() {});
        return;
      }
      await session.register(
        email: email,
        password: password,
        ageBand: _ageBand,
      );
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
                                          : (next) => setState(() {
                                              _registering = next.single;
                                              _passwordConfirmation.clear();
                                              _showPasswordConfirmation = false;
                                            }),
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
                                      onChanged: (_) {
                                        if (_registering &&
                                            _passwordConfirmation
                                                .text
                                                .isNotEmpty) {
                                          _confirmationKey.currentState
                                              ?.validate();
                                        }
                                      },
                                      obscureText: !_showPassword,
                                      autofillHints: [
                                        _registering
                                            ? AutofillHints.newPassword
                                            : AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: '密碼',
                                        helperText: _registering
                                            ? '8–128 個字元，並包含英文字母與數字。'
                                            : null,
                                        helperMaxLines: 2,
                                        errorMaxLines: 2,
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
                                        if (password.isEmpty) {
                                          return '請輸入密碼。';
                                        }
                                        if (!_registering) return null;
                                        if (password.length < 8 ||
                                            !RegExp(
                                              r'[A-Za-z]',
                                            ).hasMatch(password) ||
                                            !RegExp(r'\d').hasMatch(password)) {
                                          return '密碼至少 8 個字元，且需包含英文字母與數字。';
                                        }
                                        if (password.length > 128) {
                                          return '密碼不得超過 128 個字元。';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_registering) ...[
                                      const SizedBox(
                                        height: FutureMintTokens.space4,
                                      ),
                                      TextFormField(
                                        key: _confirmationKey,
                                        controller: _passwordConfirmation,
                                        obscureText: !_showPasswordConfirmation,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        autovalidateMode:
                                            AutovalidateMode.onUserInteraction,
                                        decoration: InputDecoration(
                                          labelText: '確認密碼',
                                          errorMaxLines: 2,
                                          suffixIcon: IconButton(
                                            tooltip: _showPasswordConfirmation
                                                ? '隱藏確認密碼'
                                                : '顯示確認密碼',
                                            onPressed: () => setState(() {
                                              _showPasswordConfirmation =
                                                  !_showPasswordConfirmation;
                                            }),
                                            icon: Icon(
                                              _showPasswordConfirmation
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return '請再次輸入密碼。';
                                          }
                                          if (value != _password.text) {
                                            return '兩次輸入的密碼不一致。';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
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
                                    if (session.notice != null) ...[
                                      const SizedBox(
                                        height: FutureMintTokens.space4,
                                      ),
                                      Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          session.notice!,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(
                                      height: FutureMintTokens.space5,
                                    ),
                                    if (_registering) ...[
                                      const Text(
                                        '台灣服務限 15 歲以上；15–17 歲需取得監護人同意。',
                                      ),
                                      const SizedBox(
                                        height: FutureMintTokens.space3,
                                      ),
                                      Text(
                                        '年齡聲明',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      const SizedBox(
                                        height: FutureMintTokens.space2,
                                      ),
                                      Semantics(
                                        label: '年齡聲明',
                                        child: DropdownButtonFormField<String>(
                                          key: const Key('registration-age'),
                                          initialValue: _ageBand,
                                          hint: const Text('請選擇年齡'),
                                          decoration: const InputDecoration(
                                            floatingLabelBehavior:
                                                FloatingLabelBehavior.never,
                                            errorMaxLines: 2,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'under-15',
                                              child: Text('未滿 15 歲'),
                                            ),
                                            DropdownMenuItem(
                                              value: '15-17',
                                              child: Text('15–17 歲'),
                                            ),
                                            DropdownMenuItem(
                                              value: '18-plus',
                                              child: Text('18 歲以上'),
                                            ),
                                          ],
                                          onChanged: session.busy
                                              ? null
                                              : (v) => setState(
                                                  () => _ageBand = v,
                                                ),
                                          validator: (v) => v == null
                                              ? '請選擇年齡；送出代表確認聲明。'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (session.servicePolicy?.mailEnabled ==
                                          false) ...[
                                        Text(
                                          _ageBand == '15-17'
                                              ? '建立帳號後，請家長或法定代理人在 App 內確認同意，即可繼續設定，不需要寄信。'
                                              : '目前採免寄信註冊，信箱只作登入識別、不驗證所有權。沒有寄信重設密碼功能，請妥善保存密碼。',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(
                                          height: FutureMintTokens.space4,
                                        ),
                                      ],
                                    ],
                                    FilledButton.icon(
                                      onPressed:
                                          session.busy ||
                                              (_registering &&
                                                  session
                                                          .servicePolicy
                                                          ?.registrationEnabled ==
                                                      false)
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
                                    if (!_registering) ...[
                                      const SizedBox(
                                        height: FutureMintTokens.space2,
                                      ),
                                      if (session.servicePolicy?.mailEnabled ==
                                          false)
                                        Text(
                                          '目前沒有寄信重設密碼功能，請妥善保存密碼；需要協助可開啟下方「聯絡支援」。',
                                          style: theme.textTheme.bodySmall,
                                        )
                                      else
                                        TextButton(
                                          onPressed: session.busy
                                              ? null
                                              : () => session
                                                    .requestPasswordReset(
                                                      _email.text,
                                                    ),
                                          child: const Text('忘記密碼？寄送重設說明'),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (!compactViewport) ...[
                              const SizedBox(height: FutureMintTokens.space5),
                              guestEntry,
                            ],
                            const SizedBox(height: FutureMintTokens.space3),
                            const PrivacySupportLinks(centered: true),
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
