import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/phosphor.dart';
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
  void initState() {
    super.initState();
    _email.text = 'etudiant.ict4d.l1@uniflow.test';
    _password.text = 'password123';
  }

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
      setState(() => _error = 'Renseignez votre e-mail et votre mot de passe.');
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
      // Un étudiant inscrit avant la publication des cours de sa filière est
      // raccordé ici, en arrière-plan, sans retarder l'entrée.
      unawaited(auth.retryAcademicProvisioning(user));
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
      // Uni accueille, réfléchit pendant la connexion et s'excuse sur une
      // erreur : l'état se lit avant même le message.
      pose: _error != null
          ? UniPose.sorry
          : _busy
              ? UniPose.thinking
              : UniPose.wave,
      headline: const AuthHeadline('Connectez-vous pour rester ', 'au fil', ' de vos cours, devoirs et notes.'),
      child: AuthCard(
        children: [
          AuthSheetTitle(
            title: 'Connexion',
            prompt: 'Pas encore de compte ?',
            actionLabel: 'S\'inscrire',
            onAction: _busy ? null : () => context.push('/register?type=${_type.wireValue}'),
          ),
          const SizedBox(height: 18),
          AccountTypeSelector(
            value: _type,
            onChanged: _busy ? null : (type) => setState(() => _type = type),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              university
                  ? 'Votre espace académique : cours, notes, présences.'
                  : 'Votre espace personnel : matières, tâches, agenda.',
              key: ValueKey(university),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: university ? 'prenom.nom@universite.cm' : 'vous@exemple.com',
              prefixIcon: const PhosphorIcon(PhosphorIconsBold.envelope, size: 20),
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
              prefixIcon: const PhosphorIcon(PhosphorIconsBold.lock, size: 20),
              // Œil pour révéler le mot de passe : sur un clavier tactile, la
              // saisie masquée est la première source d'échec de connexion.
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                icon: PhosphorIcon(_obscure ? PhosphorIconsBold.eye : PhosphorIconsBold.eyeSlash, size: 20),
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
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: AppTextStyles.bodySmall),
            ),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 12),
          _GoogleSignInButton(busy: _busy, onPressed: _signInWithGoogle),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.loginWithGoogle();
      // Le deep link redirige le navigateur vers l'app ; Appwrite crée la
      // session côté serveur. On relit l'utilisateur après le retour.
      final user = await auth.getCurrentUser();
      if (user == null) {
        throw AuthException('Connexion Google réussie, mais aucun profil UniFlow trouvé.');
      }
      // Choix de filière pour les comptes universitaires sans programme.
      if (user.accountType.toUpperCase() == UniFlowAccountType.university.wireValue &&
          (user.program == null || user.program!.isEmpty)) {
        if (mounted) {
          // Redirige vers l'écran de sélection de filière.
          context.push('/register/academic-setup');
          return;
        }
      }
      ref.read(currentUserProvider.notifier).state = user;
      ref.read(authStatusProvider.notifier).state = AuthStatus.signedIn;
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
}

class _GoogleSignInButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.inputBorder),
        backgroundColor: AppColors.cardWhite,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Google SVG inline (24×24, couleurs officielles)
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 10),
            const Text(
              'Continuer avec Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Peint le logo Google (4 couleurs, 4 arcs) en Flutter.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.35;

    // Partie bleue (haut-droite)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.65),
        -0.3, 1.6, false, paint);
    // Partie rouge (haut-gauche)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.65),
        -1.9, 1.0, false, paint);
    // Partie jaune (bas-gauche)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.65),
        2.1, 0.9, false, paint);
    // Partie verte (bas-droite)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.65),
        3.0, 0.45, false, paint);
    // Barre horizontale du « G »
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - r * 0.12, r * 0.65, r * 0.24),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
