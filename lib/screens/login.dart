import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';

/// Au-dessus de cette largeur, la carte de connexion cesse de s'étirer : un
/// formulaire large de toute la fenêtre est inconfortable à lire. Le seuil sert
/// aux tablettes et aux fenêtres redimensionnées, pas au téléphone en portrait.
const double _kCompactWidth = 480;

/// Écran de connexion Appwrite.
///
/// Sans lui, l'application démarrait sur le tableau de bord sans jamais créer
/// de session : toutes les lectures partaient en anonyme et Appwrite les
/// refusait, laissant des écrans vides sans explication.
///
/// La mise en page s'adapte à la taille de la fenêtre : le contenu est centré
/// quand il y a de la place, et la page défile quand il n'y en a pas (petit
/// téléphone, clavier ouvert, fenêtre réduite). Aucune largeur n'est imposée
/// sans qu'un parent puisse la réduire, ce qui évite les débordements.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
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
    if (error is AppwriteException) {
      switch (error.code) {
        case 401:
          return 'Email ou mot de passe incorrect.';
        case 403:
          return 'Ce client n\'est pas autorisé à joindre le projet Appwrite. '
              'La plateforme Android doit être enregistrée dans la console.';
        case 429:
          return 'Trop de tentatives. Réessayez dans quelques instants.';
      }
      return error.message ?? 'Erreur Appwrite (code ${error.code}).';
    }
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
      await auth.login(email, password);
      final user = await auth.getCurrentUser();
      if (user == null) {
        throw Exception(
          'Session créée, mais aucun profil UniFlow n\'est associé à ce compte. '
          'Contactez un administrateur UY1/ICT4D.',
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

  /// Explique pourquoi le lien « Mot de passe oublié ? » ne mène nulle part,
  /// plutôt que de laisser croire à une panne.
  void _explainForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "La réinitialisation en libre-service n'est pas encore disponible. "
          'Contactez un administrateur pour réinitialiser votre mot de passe.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Le clavier qui s'ouvre réduit la hauteur disponible : le contenu défile
      // au lieu d'être comprimé.
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.meshGradient),
        child: Stack(
          children: [
            // Formes décoratives hors du flux : elles ne participent pas au
            // calcul de taille et ne peuvent donc pas provoquer de débordement.
            Positioned(
              top: -110,
              right: -90,
              child: _Blob(
                size: 260,
                color: AppColors.primaryBlue.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: -130,
              left: -100,
              child: _Blob(
                size: 280,
                color: AppColors.teal.withValues(alpha: 0.12),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal =
                      constraints.maxWidth < _kCompactWidth ? 20.0 : 32.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontal,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      // Occupe au moins toute la hauteur de la fenêtre : le
                      // contenu est ainsi centré quand il y a de la place, et
                      // la page défile quand il n'y en a pas.
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _kCompactWidth,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _BrandHeader(),
                              const SizedBox(height: 28),
                              _FormCard(
                                email: _email,
                                password: _password,
                                obscure: _obscure,
                                busy: _busy,
                                error: _error,
                                onToggleObscure: () =>
                                    setState(() => _obscure = !_obscure),
                                onSubmit: _submit,
                                onForgotPassword: _explainForgotPassword,
                              ),
                              const SizedBox(height: 20),
                              const _Footer(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo, nom de la marque et accroche, au-dessus de la carte.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pastille dégradée : le logo posé sur un aplat blanc cassait la
        // continuité avec le dégradé de marque du web.
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: AppColors.logoGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
              // Un logo absent ne doit pas faire échouer l'écran de connexion.
              errorBuilder: (_, __, ___) => const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // « UniFlow » en dégradé bleu → teal, comme le `gradient-text` du web.
        ShaderMask(
          shaderCallback: (bounds) => AppColors.logoGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: const Text(
            'UniFlow',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'La plateforme académique de référence',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// La carte blanche qui porte le formulaire.
class _FormCard extends StatelessWidget {
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool busy;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;

  const _FormCard({
    required this.email,
    required this.password,
    required this.obscure,
    required this.busy,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.12),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Se connecter',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h1,
          ),
          const SizedBox(height: 6),
          const Text(
            'Connectez-vous à votre espace académique',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          if (error != null) ...[
            const SizedBox(height: 18),
            _ErrorBanner(message: error!),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: email,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'prenom.nom@uniflow.edu',
              prefixIcon: Icon(Icons.mail_outline, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: password,
            enabled: !busy,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => busy ? null : onSubmit(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              // Œil pour révéler le mot de passe : sur un clavier tactile, la
              // saisie masquée est la première source d'échec de connexion.
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                tooltip: obscure
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy ? null : onForgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Mot de passe oublié ?', style: AppTextStyles.link),
            ),
          ),
          const SizedBox(height: 16),
          _GradientButton(
            label: 'Se connecter',
            isLoading: busy,
            onPressed: busy ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

/// Pied de page discret, sous la carte.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'UniFlow · KERNEL FORGE',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
    );
  }
}

/// Bouton principal, en dégradé bleu → teal avec une ombre portée colorée.
///
/// Construit à la main plutôt qu'avec `ElevatedButton` : `ElevatedButton` ne
/// sait pas peindre un dégradé, et c'est ce dégradé qui rattache visuellement
/// l'écran de connexion au reste de la charte.
class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDisabled ? null : AppColors.logoGradient,
        color: isDisabled ? AppColors.inputBorder : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: SizedBox(
            height: 52,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.button,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encadré rouge affichant l'erreur de connexion.
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  /// Rouge plus sombre que `AppColors.danger`, réservé au **texte** posé sur un
  /// fond rouge très clair : le rouge d'alerte est prévu pour des icônes et des
  /// bordures, il manque de contraste pour de la lecture.
  static const Color _ink = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          // `Flexible` : le message peut être long (erreur Appwrite brute), il
          // doit se replier sur plusieurs lignes et non élargir l'encadré.
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Forme organique décorative du fond de page.
class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.4),
      ),
    );
  }
}
