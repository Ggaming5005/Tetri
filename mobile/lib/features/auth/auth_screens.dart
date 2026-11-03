import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error.dart';
import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/strings_auth.dart';
import '../../design/components/components.dart';
import '../../design/components/content.dart';
import '../../design/tokens.dart';

String authError(Object error) => switch (error) {
  ApiError(code: 'handle_taken') => AuthStrings.handleTaken,
  ApiError(code: 'email_taken') => AuthStrings.emailTaken,
  ApiError(code: 'invalid_credentials') => AuthStrings.invalidCredentials,
  ApiError(status: 429) => AuthStrings.tooManyRequests,
  ApiError(:final message) => message,
  _ => TetriStrings.offline,
};

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => TetriScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TetriSpace.x48),
        GestureDetector(
          onLongPress: kDebugMode ? () => context.push('/__gallery') : null,
          child: const TetriWordmark(),
        ),
        const SizedBox(height: TetriSpace.x24),
        const TetriText(TetriStrings.tagline, style: TetriTextStyle.headline),
        const SizedBox(height: TetriSpace.x32),
        const TetriCurrencies(),
        const SizedBox(height: TetriSpace.x32),
        PrimaryButton(
          label: AuthStrings.createAccount,
          onPressed: () => context.push('/sign-up'),
        ),
        const SizedBox(height: TetriSpace.x12),
        SecondaryButton(
          label: AuthStrings.signIn,
          onPressed: () => context.push('/sign-in'),
        ),
        const SizedBox(height: TetriSpace.x24),
        const TetriText(
          TetriStrings.sandbox,
          style: TetriTextStyle.label,
          secondary: true,
        ),
      ],
    ),
  );
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!AuthValidation.email(_email.text) || _password.text.isEmpty) {
      setState(() => _error = AuthStrings.invalidCredentials);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider)
          .signIn(email: _email.text.trim(), password: _password.text);
      services.TextInput.finishAutofillContext();
    } catch (error) {
      if (mounted) setState(() => _error = authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TetriScaffold(
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: AuthStrings.welcomeBack,
            subtitle: AuthStrings.signInHint,
            onBack: _busy ? null : () => context.go('/'),
          ),
          const SizedBox(height: TetriSpace.x32),
          TextInput(
            label: TetriStrings.email,
            hint: TetriStrings.emailHint,
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: TetriSpace.x24),
          TextInput(
            label: TetriStrings.password,
            controller: _password,
            enabled: !_busy,
            variant: TextInputVariant.password,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: TetriSpace.x24),
            InlineBanner(message: _error!, kind: BannerKind.warning),
          ],
          const SizedBox(height: TetriSpace.x32),
          PrimaryButton(
            label: _error == null ? AuthStrings.signIn : TetriStrings.retry,
            isLoading: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: TetriSpace.x12),
          TetriTextButton(
            label: AuthStrings.createAccount,
            onPressed: _busy ? null : () => context.go('/sign-up'),
          ),
        ],
      ),
    ),
  );
}

abstract final class AuthValidation {
  static bool email(String text) =>
      text.trim().length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text.trim());
  static bool handle(String text) =>
      RegExp(r'^@?[a-zA-Z0-9_]{3,24}$').hasMatch(text.trim());
  static bool name(String text) =>
      text.trim().isNotEmpty &&
      text.trim().length <= 80 &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(text);
  static bool password(String text) => text.length >= 10 && text.length <= 128;
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _fields = List.generate(4, (_) => TextEditingController());
  static const _handleDebounce = Duration(milliseconds: 400);
  Timer? _debounce;
  int _handleGeneration = 0;
  int _step = 0;
  bool _busy = false;
  bool _checking = false;
  bool? _available;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _onChange(String value) {
    setState(() => _error = null);
    if (_step != 2) return;
    _debounce?.cancel();
    final generation = ++_handleGeneration;
    setState(() {
      _available = null;
      _checking = AuthValidation.handle(value);
    });
    if (_checking) {
      _debounce = Timer(_handleDebounce, () => _checkHandle(value, generation));
    }
  }

  Future<void> _checkHandle(String value, int generation) async {
    try {
      final available = await ref
          .read(bankApiProvider)
          .handleAvailable(value.trim());
      if (!mounted || generation != _handleGeneration) return;
      setState(() {
        _available = available;
        _checking = false;
        _error = available ? null : AuthStrings.handleTaken;
      });
    } catch (error) {
      if (!mounted || generation != _handleGeneration) return;
      setState(() {
        _checking = false;
        _error = authError(error);
      });
    }
  }

  void _back() {
    if (_step == 0) {
      context.go('/');
      return;
    }
    _debounce?.cancel();
    _handleGeneration++;
    setState(() {
      _step--;
      _error = null;
      _checking = false;
    });
    if (_step == 2) _onChange(_fields[2].text);
  }

  Future<void> _continue() async {
    if (_busy || _checking) return;
    final valid = switch (_step) {
      0 => AuthValidation.email(_fields[0].text),
      1 => AuthValidation.name(_fields[1].text),
      2 => AuthValidation.handle(_fields[2].text),
      _ => AuthValidation.password(_fields[3].text),
    };
    if (!valid) {
      setState(
        () => _error = switch (_step) {
          0 => TetriStrings.invalidEmail,
          1 => AuthStrings.nameRequired,
          2 => AuthStrings.handleInvalid,
          _ => AuthStrings.passwordHelp,
        },
      );
      return;
    }
    if (_step == 2 && _available != true) {
      setState(() => _checking = true);
      await _checkHandle(_fields[2].text, ++_handleGeneration);
      return;
    }
    if (_step < 3) {
      setState(() {
        _step++;
        _error = null;
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider)
          .register(
            email: _fields[0].text.trim(),
            displayName: _fields[1].text.trim(),
            handle: _fields[2].text.trim(),
            password: _fields[3].text,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authError(error);
        if (error is ApiError && error.code == 'handle_taken') {
          _step = 2;
          _available = false;
        }
        if (error is ApiError && error.code == 'email_taken') _step = 0;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      AuthStrings.emailTitle,
      AuthStrings.nameTitle,
      AuthStrings.handleTitle,
      AuthStrings.passwordTitle,
    ];
    final labels = [
      TetriStrings.email,
      AuthStrings.name,
      AuthStrings.handle,
      TetriStrings.password,
    ];
    final hints = [
      TetriStrings.emailHint,
      AuthStrings.nameHint,
      TetriStrings.handleHint,
      TetriStrings.passwordHint,
    ];
    return TetriScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(title: titles[_step], onBack: _busy ? null : _back),
          const SizedBox(height: TetriSpace.x24),
          StepProgress(current: _step + 1, total: _fields.length),
          const SizedBox(height: TetriSpace.x32),
          TextInput(
            key: ValueKey(_step),
            label: labels[_step],
            hint: hints[_step],
            controller: _fields[_step],
            enabled: !_busy,
            variant: _step == 3
                ? TextInputVariant.password
                : TextInputVariant.plain,
            keyboardType: _step == 0
                ? TextInputType.emailAddress
                : TextInputType.text,
            textInputAction: TextInputAction.done,
            onChanged: _onChange,
            onSubmitted: (_) => _continue(),
          ),
          const SizedBox(height: TetriSpace.x16),
          if (_step == 2) ...[
            const TetriText(
              AuthStrings.handleHelp,
              style: TetriTextStyle.label,
              secondary: true,
            ),
            const SizedBox(height: TetriSpace.x12),
            if (_checking)
              const Skeleton(
                height: TetriSpace.x16,
                semanticLabel: AuthStrings.checkingHandle,
              )
            else if (_available == true)
              const TetriText(
                AuthStrings.handleAvailable,
                style: TetriTextStyle.label,
                secondary: true,
              ),
          ],
          if (_step == 3)
            const TetriText(
              AuthStrings.passwordHelp,
              style: TetriTextStyle.label,
              secondary: true,
            ),
          if (_error != null) ...[
            const SizedBox(height: TetriSpace.x16),
            InlineBanner(message: _error!, kind: BannerKind.warning),
          ],
          const SizedBox(height: TetriSpace.x32),
          PrimaryButton(
            label: _step == 3
                ? AuthStrings.createAccount
                : TetriStrings.continueLabel,
            onPressed: _checking ? null : _continue,
            isLoading: _busy,
          ),
          const SizedBox(height: TetriSpace.x12),
          TetriTextButton(
            label: AuthStrings.signIn,
            onPressed: _busy ? null : () => context.go('/sign-in'),
          ),
        ],
      ),
    );
  }
}

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: ref.watch(sessionProvider),
    builder: (context, _) {
      final session = ref.read(sessionProvider);
      return TetriScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: TetriSpace.x64),
            const TetriWordmark(),
            const SizedBox(height: TetriSpace.x48),
            if (session.error != null) ...[
              InlineBanner(
                message: authError(session.error!),
                kind: BannerKind.warning,
              ),
              const SizedBox(height: TetriSpace.x24),
              PrimaryButton(
                label: TetriStrings.retry,
                onPressed: session.initialize,
              ),
            ] else ...[
              const Skeleton(
                height: TetriSizes.button56,
                semanticLabel: AuthStrings.restoring,
              ),
              const SizedBox(height: TetriSpace.x24),
              const Skeleton(height: TetriSizes.scaffoldExpandedHeight),
            ],
          ],
        ),
      );
    },
  );
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final unlocked = await ref.read(sessionProvider).unlock();
      if (mounted && !unlocked) {
        setState(() => _error = AuthStrings.unlockCancelled);
      }
    } catch (error) {
      if (mounted) setState(() => _error = authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TetriScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TetriSpace.x64),
        const TetriWordmark(),
        const SizedBox(height: TetriSpace.x48),
        const AuthHeader(
          title: AuthStrings.unlockTitle,
          subtitle: AuthStrings.unlockHint,
        ),
        const SizedBox(height: TetriSpace.x48),
        if (_error != null) ...[
          InlineBanner(message: _error!, kind: BannerKind.warning),
          const SizedBox(height: TetriSpace.x24),
        ],
        PrimaryButton(
          label: AuthStrings.unlock,
          onPressed: _unlock,
          isLoading: _busy,
        ),
      ],
    ),
  );
}

class BiometricsOfferScreen extends ConsumerStatefulWidget {
  const BiometricsOfferScreen({super.key});
  @override
  ConsumerState<BiometricsOfferScreen> createState() =>
      _BiometricsOfferScreenState();
}

class _BiometricsOfferScreenState extends ConsumerState<BiometricsOfferScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider).setBiometrics(true);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) setState(() => _error = authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider).dismissBiometricsOffer();
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) setState(() => _error = authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TetriScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TetriSpace.x48),
        const AuthHeader(
          title: AuthStrings.biometricTitle,
          subtitle: AuthStrings.biometricHint,
        ),
        const SizedBox(height: TetriSpace.x48),
        const TetriCurrencies(),
        const SizedBox(height: TetriSpace.x32),
        if (_error != null) ...[
          InlineBanner(message: _error!, kind: BannerKind.warning),
          const SizedBox(height: TetriSpace.x24),
        ],
        PrimaryButton(
          label: AuthStrings.enableBiometrics,
          onPressed: _busy ? null : _enable,
          isLoading: _busy,
        ),
        const SizedBox(height: TetriSpace.x12),
        TetriTextButton(
          label: AuthStrings.notNow,
          onPressed: _busy ? null : _skip,
        ),
      ],
    ),
  );
}
