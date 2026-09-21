import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/feedback.dart';
import '../widgets/uni/uni_mascot.dart';

/// Récupération de mot de passe : Appwrite envoie un e-mail dont le lien mène
/// à la page `reset-password` du web, la seule plateforme d'où un mot de passe
/// peut être changé sans session.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Adresse e-mail invalide.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordRecovery(email);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = loginErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go('/login');

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      pose: _sent
          ? UniPose.celebrate
          : _error != null
              ? UniPose.sorry
              : UniPose.search,
      headline: const AuthHeadline('Un ', 'lien', ' suffit pour retrouver l\'accès à votre espace.'),
      onBack: _busy ? null : _back,
      child: AuthCard(
        children: [
          if (_sent)
            FeedbackView(
              kind: FeedbackKind.success,
              title: 'E-mail envoyé',
              message: 'Si un compte existe pour ${_email.text.trim()}, un lien de '
                  'réinitialisation vient de lui être envoyé. Il ouvre la page de '
                  'changement de mot de passe du site UniFlow.',
              actionLabel: 'Retour à la connexion',
              onAction: _back,
            )
          else ...[
            AuthSheetTitle(
              title: 'Mot de passe oublié',
              prompt: 'Vous vous en souvenez ?',
              actionLabel: 'Se connecter',
              onAction: _busy ? null : _back,
            ),
            const SizedBox(height: 10),
            const Text(
              'Indiquez l\'adresse de votre compte : vous recevrez un lien pour choisir un nouveau mot de passe.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _submit(),
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline, size: 20)),
            ),
            const SizedBox(height: 20),
            GradientButton(label: 'Envoyer le lien', isLoading: _busy, onPressed: _busy ? null : _submit),
          ],
        ],
      ),
    );
  }
}
