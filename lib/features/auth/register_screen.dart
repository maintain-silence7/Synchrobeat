import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../common/app_buttons.dart';
import '../common/avatar_circle.dart';
import 'auth_bloc.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _emoji = kAvatarEmojis.first;
  int _colorValue = kAvatarColors.first;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    sl<AuthBloc>().add(SignUpSubmitted(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          avatarEmoji: _emoji,
          avatarColorValue: _colorValue,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          bloc: sl<AuthBloc>(),
          listener: (context, state) {
            if (state is AuthAuthenticated) context.go('/home');
          },
          builder: (context, state) {
            final busy = state is AuthUnauthenticated && state.busy;
            final error = state is AuthUnauthenticated ? state.error : null;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar Hero Preview
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(_colorValue).withValues(alpha: 0.4),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: AvatarCircle(
                            emoji: _emoji,
                            colorValue: _colorValue,
                            radius: 46,
                            fontSize: 42,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Pick your vibe & color',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Emoji Selector Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final emoji in kAvatarEmojis)
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setState(() => _emoji = emoji),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: _emoji == emoji
                                      ? AppTheme.primary.withValues(alpha: 0.3)
                                      : AppTheme.surface,
                                  border: Border.all(
                                    color: _emoji == emoji
                                        ? AppTheme.primaryAccent
                                        : AppTheme.surfaceBorder,
                                    width: _emoji == emoji ? 1.8 : 1,
                                  ),
                                ),
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Color Swatches Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final color in kAvatarColors)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () =>
                                    setState(() => _colorValue = color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Color(color),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _colorValue == color
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: _colorValue == color
                                        ? [
                                            BoxShadow(
                                              color: Color(color)
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.error.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error,
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Display name',
                                prefixIcon: Icon(Icons.badge_outlined,
                                    color: AppTheme.textSecondary, size: 20),
                              ),
                              validator: (_) => null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'Email address',
                                prefixIcon: Icon(Icons.alternate_email_rounded,
                                    color: AppTheme.textSecondary, size: 20),
                              ),
                              validator: (_) => null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                hintText: 'Password (any)',
                                prefixIcon: const Icon(Icons.lock_outline_rounded,
                                    color: AppTheme.textSecondary, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (_) => null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryGradientButton(
                        onPressed: busy ? null : _submit,
                        label: 'Create Account',
                        isLoading: busy,
                        icon: const Icon(Icons.check_circle_outline_rounded,
                            size: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Already have an account? Sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
