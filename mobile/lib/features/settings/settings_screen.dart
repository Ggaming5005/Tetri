import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/preferences.dart';
import '../../core/platform.dart';
import '../../core/providers.dart';
import '../../core/strings_banking.dart';
import '../../design/components/browse_components.dart';
import '../../design/components/buttons.dart';
import '../../design/components/inline_banner.dart';
import '../../design/components/selection_controls.dart';
import '../../design/components/tetri_scaffold.dart';
import '../../design/tokens.dart';
import '../home/banking_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _setBiometrics(bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(sessionProvider);
      if (enabled && !await session.biometricsAvailable()) {
        if (mounted) {
          setState(() => _error = BankingStrings.biometricUnavailable);
        }
        return;
      }
      await session.setBiometrics(enabled);
    } catch (_) {
      if (mounted) setState(() => _error = BankingStrings.biometricUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider).signOut();
    } catch (_) {
      if (mounted) setState(() => _error = BankingStrings.signOutFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final session = ref.watch(sessionProvider);
    final theme = ref.watch(themeModeProvider);
    return TetriScaffold(
      title: BankingStrings.settings,
      bottomNavigationBar: const TetriNavigation(selectedIndex: 2),
      child: profile.when(
        loading: () => const LoadingList(),
        error: (error, stack) => PageMessage(
          message: BankingStrings.cannotLoad,
          actionLabel: BankingStrings.retry,
          onAction: () => ref.invalidate(profileProvider),
        ),
        data: (user) => ListenableBuilder(
          listenable: session,
          builder: (context, child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileSummary(
                userId: user.id,
                name: user.displayName,
                handle: user.handle,
                email: user.email,
              ),
              const SizedBox(height: TetriSpace.x32),
              TetriSwitch(
                label: BankingStrings.biometricUnlock,
                value: session.biometricsEnabled,
                onChanged: _busy ? null : _setBiometrics,
              ),
              const SizedBox(height: TetriSpace.x24),
              const SectionHeading(title: BankingStrings.theme),
              const SizedBox(height: TetriSpace.x12),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: theme,
                builder: (context, value, child) =>
                    TetriSegmentedControl<ThemeMode>(
                      segments: const {
                        ThemeMode.system: BankingStrings.system,
                        ThemeMode.light: BankingStrings.light,
                        ThemeMode.dark: BankingStrings.dark,
                      },
                      value: value,
                      onChanged: (next) => theme.value = next,
                    ),
              ),
              const SizedBox(height: TetriSpace.x32),
              const PageHeading(
                title: BankingStrings.about,
                subtitle:
                    '${BankingStrings.version}\n${BankingStrings.sandbox}',
              ),
              TetriTextButton(
                label: BankingStrings.repository,
                onPressed: () async {
                  try {
                    await TetriPlatform.openRepository();
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _error = BankingStrings.repositoryUnavailable,
                      );
                    }
                  }
                },
              ),
              if (_error != null) ...[
                InlineBanner(message: _error!, kind: BannerKind.warning),
                const SizedBox(height: TetriSpace.x16),
              ],
              const SizedBox(height: TetriSpace.x24),
              SecondaryButton(
                label: BankingStrings.signOut,
                onPressed: _busy ? null : _signOut,
                isLoading: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
