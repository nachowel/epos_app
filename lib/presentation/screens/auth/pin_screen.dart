import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final String pin = _pinController.text.trim();
    if (pin.isEmpty) {
      _showMessage(AppStrings.enterPin);
      return;
    }

    final user = await ref
        .read(authNotifierProvider.notifier)
        .loginWithPin(pin);
    if (!mounted) {
      return;
    }
    if (user == null) {
      final String error =
          ref.read(authNotifierProvider).errorMessage ?? AppStrings.loginFailed;
      _showMessage(error);
      return;
    }

    context.go('/pos');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(AppSizes.spacingLg),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spacingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    AppStrings.loginTitle,
                    style: const TextStyle(
                      fontSize: AppSizes.fontLg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacingMd),
                  TextField(
                    controller: _pinController,
                    decoration: InputDecoration(
                      labelText: AppStrings.pinLabel,
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: AppSizes.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.minTouch,
                    child: ElevatedButton(
                      onPressed: authState.isLoading || authState.isLocked
                          ? null
                          : _login,
                      child: Text(
                        authState.isLoading
                            ? AppStrings.loading
                            : AppStrings.loginButton,
                        style: const TextStyle(fontSize: AppSizes.fontSm),
                      ),
                    ),
                  ),
                  if (authState.errorMessage != null) ...<Widget>[
                    const SizedBox(height: AppSizes.spacingMd),
                    Text(
                      authState.errorMessage!,
                      style: const TextStyle(
                        fontSize: AppSizes.fontSm,
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
