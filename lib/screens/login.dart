import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/uni/uni_mascot.dart';
import '../widgets/feedback.dart';

/// Écran de connexion Appwrite.
///
/// Sans lui, l'application démarrait sur le tableau de bord sans jamais créer
/// de session : toutes les lectures partaient en anonyme et Appwrite les
/// refusait, laissant des écrans vides sans explication.
///
/// Le choix « compte universitaire / compte indépendant » reprend celui du web :
/// il sert d'indication quand le compte n'a pas encore de type enregistré, et
/// il annonce à l'utilisateur l'espace qu'il va trouver derrière.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  UniFlowAccountType _type = UniFlowAccountType.university;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Traduit une exception Appwrite en message lisible plutôt que de laisser
  /// remonter un « Unauthorized » brut.
  String _readable(Object error) {
    if (error is AuthException) return error.message;
    if (error is AppwriteException) return loginErrorMessage(error);
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused') ||
        text.contains('HandshakeException')) {
      return 'Appwrite est injoignable depuis cet appareil. Vérifiez la connexion réseau.';
    }
    return text;
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Renseignez votre email et votre mot de passe.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.login(email, password, accountTypeHint: _type);
      final user = await auth.getCurrentUser();
      if (user == null) {
        throw AuthException(
          'Session créée, mais aucun profil UniFlow n\'est associé à ce compte. '
          'Contactez l\'administration de votre université.',
        );
      }
      ref.read(currentUserProvider.notifier).state = user;
      ref.read(authStatusProvider.notifier).state = AuthStatus.signedIn;
      // Le redirect du routeur bascule alors automatiquement sur /accueil.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _readable(e);
      });
      return;
    }

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final university = _type == UniFlowAccountType.university;
    return AuthScaffold(
      child: AuthCard(
        children: [
          // Uni accueille, réfléchit pendant la connexion et s'excuse sur une
          // erreur : l'état se lit avant même le message.
          Center(
            child: UniMascot(
              pose: _error != null ? UniPose.sorry : _busy ? UniPose.thinking : UniPose.wave,
              size: 96,
              effects: false,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Se connecter',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h1,
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              university ? 'Connectez-vous à votre espace académique' : 'Connectez-vous à votre espace personnel',
              key: ValueKey(university),
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ),
          const SizedBox(height: 18),
          AccountTypeSelector(
            value: _type,
            onChanged: _busy ? null : (type) => setState(() => _type = type),
          ),
          if (_error != null) ...[
            const SizedBox(height: 18),
            FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: university ? 'prenom.nom@universite.cm' : 'vous@exemple.com',
              prefixIcon: const Icon(Icons.mail_outline, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              // Œil pour révéler le mot de passe : sur un clavier tactile, la
              // saisie masquée est la première source d'échec de connexion.
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => context.push('/mot-de-passe-oublie'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Mot de passe oublié ?', style: AppTextStyles.link),
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(label: 'Se connecter', isLoading: _busy, onPressed: _busy ? null : _submit),
          const SizedBox(height: 18),
          // `Wrap` plutôt que `Row` : aux grandes échelles de texte les deux
          // segments ne tiennent pas côte à côte et déborderaient.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Pas encore de compte ? ', style: AppTextStyles.bodySmall),
              TextButton(
                onPressed: _busy ? null : () => context.push('/register?type=${_type.wireValue}'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Créer un compte', style: AppTextStyles.link),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
