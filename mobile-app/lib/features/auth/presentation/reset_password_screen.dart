import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;
  const ResetPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailCtrl =
      TextEditingController(text: widget.initialEmail);
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: _emailCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            newPassword: _passwordCtrl.text,
          );
      setState(() => _done = true);
    } catch (e) {
      setState(() => _error = extractDioError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau mot de passe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: _done
            ? SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: _buildSuccess(),
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: _buildForm(),
              ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Réinitialiser le mot de passe',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entrez le code à 6 chiffres reçu par e-mail, puis choisissez un nouveau mot de passe.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          if (_error != null) ...[
            ErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
          ],

          AppTextField(
            controller: _emailCtrl,
            label: 'Adresse e-mail',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_loading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champ requis';
              if (!v.contains('@')) return 'Email invalide';
              return null;
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _codeCtrl,
            label: 'Code à 6 chiffres',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            enabled: !_loading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champ requis';
              if (v.trim().length != 6) return 'Le code doit contenir 6 chiffres';
              return null;
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _passwordCtrl,
            label: 'Nouveau mot de passe',
            obscureText: !_showPassword,
            textInputAction: TextInputAction.next,
            enabled: !_loading,
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Champ requis';
              if (v.length < 8) return 'Minimum 8 caractères';
              return null;
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _confirmCtrl,
            label: 'Confirmer le mot de passe',
            obscureText: !_showConfirm,
            textInputAction: TextInputAction.done,
            enabled: !_loading,
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirm ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _showConfirm = !_showConfirm),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Champ requis';
              if (v != _passwordCtrl.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'Min. 8 caractères, une majuscule, un chiffre, un caractère spécial.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Réinitialiser',
            onPressed: _loading ? null : _submit,
            loading: _loading,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Mot de passe réinitialisé !',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Se connecter'),
        ),
      ],
    );
  }
}
