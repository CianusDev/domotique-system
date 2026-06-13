import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/auth_notifier.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailCtrl =
      TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .forgotPassword(_emailCtrl.text.trim());
      setState(() => _sent = true);
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
        title: const Text('Mot de passe oublié'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _sent
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
            'Réinitialisation du mot de passe',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entrez votre e-mail et nous vous enverrons un code de réinitialisation.',
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
            textInputAction: TextInputAction.done,
            enabled: !_loading,
            autofocus: true,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champ requis';
              if (!v.contains('@')) return 'Email invalide';
              return null;
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Envoyer le code',
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
          'E-mail envoyé !',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Consultez votre boîte mail et entrez le code à 6 chiffres reçu.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/reset-password', extra: _emailCtrl.text.trim()),
          child: const Text("Entrer le code reçu"),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Retour à la connexion'),
        ),
      ],
    );
  }
}
