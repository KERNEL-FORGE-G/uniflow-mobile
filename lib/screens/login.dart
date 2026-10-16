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

/// Écran de connexion Appwrite unifié.
///
/// Permet l'accès aux deux mondes UniFlow :
/// 1. Espace Académique : rattaché à une université (UY1...), pour Étudiants,
///    Enseignants et Administration.
/// 2. Espace Indépendant : 100% autonome pour Étudiants, Délégués et Enseignants
///    hors université partenaire.
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
    _applyTypeDefaults(_type);
  }

  void _applyTypeDefaults(UniFlowAccountType type) {
    if (type == UniFlowAccountType.university) {
      _email.text = 'ict@uy1.cm';
      _password.text = 'password123';
    } else {
      _email.text = 'independant@uniflow.test';
      _password.text = 'password123';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Traduit une exception Appwrite en message lisible.
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
      setState(() => _error = 'Renseignez votre identifiant et votre mot de passe.');
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
          'Contactez le support ou l\'administration.',
        );
      }
      ref.read(currentUserProvider.notifier).state = user;
      ref.read(authStatusProvider.notifier).state = AuthStatus.signedIn;
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.loginWithGoogle();
      final user = await auth.getCurrentUser();
      if (user == null) {
        throw AuthException('Connexion Google réussie, mais aucun profil UniFlow trouvé.');
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

  @override
  Widget build(BuildContext context) {
    final isUni = _type == UniFlowAccountType.university;

    return AuthScaffold(
      pose: _error != null
          ? UniPose.sorry
          : _busy
              ? UniPose.thinking
              : UniPose.wave,
      headline: const AuthHeadline('Bienvenue.\nConnectez-vous pour rester ', 'au fil', ' de vos cours.'),
      child: AuthCard(
        children: [
          AuthSheetTitle(
            title: 'Connexion',
            prompt: 'Pas encore de compte ?',
            actionLabel: 'S\'inscrire',
            onAction: _busy ? null : () => context.push('/register?type=${_type.wireValue}'),
          ),
          const SizedBox(height: 14),

          // ── Sélecteur de type d'espace (Académique vs Indépendant) ──
          AccountTypeSelector(
            value: _type,
            onChanged: _busy
                ? null
                : (newType) {
                    setState(() {
                      _type = newType;
                      _error = null;
                      _applyTypeDefaults(newType);
                    });
                  },
          ),
          const SizedBox(height: 10),

          // ── Description contextuelle de l'espace sélectionné ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUni
                  ? AppColors.primaryBlue.withValues(alpha: 0.05)
                  : const Color(0xFF0D9488).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isUni
                    ? AppColors.primaryBlue.withValues(alpha: 0.12)
                    : const Color(0xFF0D9488).withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                PhosphorIcon(
                  isUni ? PhosphorIconsBold.buildings : PhosphorIconsBold.globe,
                  color: isUni ? AppColors.primaryBlue : const Color(0xFF0D9488),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isUni
                        ? 'Espace Académique : Étudiants, Enseignants et Administration UY1.'
                        : 'Espace Indépendant : Espace d\'apprentissage et tutorat autonome.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isUni ? AppColors.primaryBlue : const Color(0xFF0D9488),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
          ],
          const SizedBox(height: 16),

          // ── Champ Identifiant / Email ──
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: isUni ? 'Email universitaire ou matricule' : 'Adresse e-mail',
              hintText: isUni ? 'ict@uy1.cm ou 21T2345' : 'vous@exemple.com',
              prefixIcon: PhosphorIcon(
                isUni ? PhosphorIconsBold.identificationBadge : PhosphorIconsBold.envelope,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Champ Mot de passe ──
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

          // ── Bouton de connexion principal ──
          GradientButton(
            label: isUni ? 'Se connecter à l\'Université' : 'Se connecter à l\'Espace Indépendant',
            icon: isUni ? PhosphorIconsBold.buildings : PhosphorIconsBold.arrowRight,
            isLoading: _busy,
            onPressed: _busy ? null : _submit,
          ),

          // ── Raccourcis démo pour test rapide ──
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (isUni) ...[
                _DemoChip(
                  label: 'Étudiant ICT4D',
                  onTap: _busy
                      ? null
                      : () {
                          setState(() {
                            _email.text = 'ict@uy1.cm';
                            _password.text = 'password123';
                            _error = null;
                          });
                        },
                ),
                _DemoChip(
                  label: 'Enseignant UY1',
                  onTap: _busy
                      ? null
                      : () {
                          setState(() {
                            _email.text = 'prof@uy1.cm';
                            _password.text = 'password123';
                            _error = null;
                          });
                        },
                ),
                _DemoChip(
                  label: 'Admin FS',
                  onTap: _busy
                      ? null
                      : () {
                          setState(() {
                            _email.text = 'admin@uy1.cm';
                            _password.text = 'password123';
                            _error = null;
                          });
                        },
                ),
              ] else ...[
                _DemoChip(
                  label: 'Étudiant Indépendant',
                  onTap: _busy
                      ? null
                      : () {
                          setState(() {
                            _email.text = 'independant@uniflow.test';
                            _password.text = 'password123';
                            _error = null;
                          });
                        },
                ),
              ],
            ],
          ),

          if (!isUni) ...[
            const SizedBox(height: 14),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: AppTextStyles.bodySmall),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
            _GoogleSignInButton(busy: _busy, onPressed: _signInWithGoogle),
          ],
        ],
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _DemoChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PhosphorIcon(PhosphorIconsBold.lightning, size: 12, color: Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
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

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.35;

    // Bleu
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.65), -0.3, 1.6, false, paint);
    // Rouge
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.65), -1.9, 1.0, false, paint);
    // Jaune
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.65), 2.1, 0.9, false, paint);
    // Vert
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.65), 3.0, 0.45, false, paint);
    // Barre horizontale du G
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
