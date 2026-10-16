import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_role.dart';
import '../providers/providers.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/feedback.dart';
import '../widgets/phosphor.dart';
import '../widgets/uni/uni_mascot.dart';

/// Inscription native, miroir de la page `/register` du web.
///
/// Inscription 100% autonome pour les étudiants, délégués et enseignants indépendants.
class RegisterScreen extends ConsumerStatefulWidget {
  final UniFlowAccountType initialType;

  const RegisterScreen({super.key, this.initialType = UniFlowAccountType.personal});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _matricule = TextEditingController();
  final UniFlowAccountType _type = UniFlowAccountType.personal;
  UniFlowRole _role = UniFlowRole.student;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _matricule.dispose();
    super.dispose();
  }

  RegistrationInput _input() => RegistrationInput(
        email: _email.text,
        password: _password.text,
        name: _name.text,
        accountType: _type,
        role: _role,
        matricule: _matricule.text,
      );

  Future<void> _submit() async {
    final input = _input();
    final invalid = validateRegistration(input) ?? passwordConfirmationError(_password.text, _confirm.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      final user = await auth.register(input);
      if (!mounted) return;
      // Le compte est créé et la session ouverte : on entre directement dans
      // l'application (le routeur mène au tableau de bord du rôle), sans écran
      // intermédiaire à valider. Le mot de bienvenue s'affiche par-dessus.
      setState(() => _busy = false);
      ref.read(currentUserProvider.notifier).state = user;
      ref.read(authStatusProvider.notifier).state = AuthStatus.signedIn;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(welcomeMessage(user, pendingCourses: auth.academicProvisioningPending)),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = loginErrorMessage(error);
      });
    }
  }

  Future<void> _openWeb() async {
    final uri = Uri.parse(webRegisterUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      setState(() => _error = 'Impossible d\'ouvrir $webRegisterUrl sur cet appareil.');
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go('/login');

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      pose: _error != null ? UniPose.sorry : UniPose.pointing,
      headline: const AuthHeadline('Créez votre compte et ', 'simplifiez', ' votre vie étudiante.'),
      onBack: _busy ? null : _back,
      child: AuthCard(
        children: [
          AuthSheetTitle(
            title: 'Créer un compte',
            prompt: 'Déjà un compte ?',
            actionLabel: 'Se connecter',
            onAction: _busy ? null : _back,
          ),
          const SizedBox(height: 14),
          IndependentRoleSelector(
            value: _role,
            onChanged: _busy ? null : (role) => setState(() => _role = role),
          ),
          const SizedBox(height: 8),
          Text(
            switch (_role) {
              UniFlowRole.student => 'Étudiant indépendant : gérez vos cours, vos notes et votre planning.',
              UniFlowRole.delegate => 'Délégué indépendant : coordonnez vos groupes d\'étude et présences.',
              UniFlowRole.teacher => 'Enseignant indépendant : organisez vos cours, vos devoirs et évaluations.',
              _ => 'Espace personnel autonome.',
            },
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: PhosphorIcon(PhosphorIconsBold.identificationBadge, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: PhosphorIcon(PhosphorIconsBold.envelope, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Mot de passe (8 caractères minimum)',
              prefixIcon: const PhosphorIcon(PhosphorIconsBold.lock, size: 20),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                icon: PhosphorIcon(_obscure ? PhosphorIconsBold.eye : PhosphorIconsBold.eyeSlash, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Confirmation, comme sur la maquette : une faute de frappe dans un
          // mot de passe masqué se découvre sinon à la première reconnexion.
          TextField(
            controller: _confirm,
            enabled: !_busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: PhosphorIcon(PhosphorIconsBold.lockKey, size: 20),
            ),
          ),
          const SizedBox(height: 22),
          GradientButton(
            label: 'Créer mon compte ${_role.label.toLowerCase()}',
            isLoading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _busy ? null : _openWeb,
            icon: const PhosphorIcon(PhosphorIconsBold.arrowSquareOut, size: 16),
            label: const Text('S\'inscrire depuis le site web', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
