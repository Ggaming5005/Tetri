import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_pin.dart';
import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/strings_auth.dart';
import '../../design/components/buttons.dart';
import '../../design/components/content.dart';
import '../../design/components/pin_input.dart';
import '../../design/components/tetri_scaffold.dart';
import '../../design/tokens.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key, this.changing = false});
  final bool changing;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  String? _currentPin;
  String? _newPin;
  String? _error;
  int _step = 0;
  bool _busy = false;
  Timer? _retryTimer;
  DateTime? _retryAt;

  bool get _askingCurrent => widget.changing && _step == 0;
  bool get _confirming => _step == (widget.changing ? 2 : 1);
  bool get _coolingDown =>
      _retryAt != null && DateTime.now().isBefore(_retryAt!);
  bool get _canContinue =>
      !_busy &&
      !_coolingDown &&
      _input.text.length == AppPinController.pinLength;

  @override
  void dispose() {
    _retryTimer?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setCooldown(DateTime? retryAt) {
    _retryTimer?.cancel();
    _retryAt = retryAt;
    if (!_coolingDown) return;
    _retryTimer = Timer(retryAt!.difference(DateTime.now()), () {
      if (mounted) {
        setState(() {
          _retryAt = null;
          _error = null;
        });
      }
    });
  }

  void _back() {
    if (_busy) return;
    if (_step == 0) {
      if (widget.changing) {
        context.canPop() ? context.pop() : context.go('/settings');
      }
      return;
    }
    setState(() {
      _step--;
      _input.clear();
      _newPin = null;
      _error = null;
    });
    _focus.requestFocus();
  }

  Future<void> _continue() async {
    if (!_canContinue) return;
    if (!_confirming) {
      setState(() {
        if (_askingCurrent) {
          _currentPin = _input.text;
        } else {
          _newPin = _input.text;
        }
        _step++;
        _input.clear();
        _error = null;
      });
      _focus.requestFocus();
      return;
    }
    if (_input.text != _newPin) {
      setState(() {
        _input.clear();
        _error = AuthStrings.pinMismatch;
      });
      return;
    }
    _focus.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider).setPin(_newPin!, currentPin: _currentPin);
      if (!mounted) return;
      _input.clear();
      _newPin = null;
      _currentPin = null;
      if (widget.changing) {
        context.canPop() ? context.pop() : context.go('/settings');
      }
    } on PinException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _setCooldown(error.retryAt);
          _step = 0;
          _input.clear();
          _newPin = null;
          _currentPin = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = AuthStrings.pinOperationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _askingCurrent
        ? AuthStrings.currentPinTitle
        : _confirming
        ? AuthStrings.confirmPinTitle
        : AuthStrings.createPinTitle;
    return TetriScaffold(
      bottomAction: PrimaryButton(
        label: _confirming ? AuthStrings.savePin : TetriStrings.continueLabel,
        onPressed: _canContinue ? _continue : null,
        isLoading: _busy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: title,
            subtitle: _askingCurrent
                ? AuthStrings.currentPinHint
                : _confirming
                ? AuthStrings.confirmPinHint
                : AuthStrings.createPinHint,
            onBack: !_busy && (widget.changing || _step > 0) ? _back : null,
          ),
          const SizedBox(height: TetriSpace.x24),
          StepProgress(current: _step + 1, total: widget.changing ? 3 : 2),
          const SizedBox(height: TetriSpace.x32),
          PinInput(
            label: _askingCurrent
                ? AuthStrings.currentPin
                : _confirming
                ? AuthStrings.confirmPin
                : AuthStrings.newPin,
            controller: _input,
            focusNode: _focus,
            enabled: !_busy && !_coolingDown,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
        ],
      ),
    );
  }
}
