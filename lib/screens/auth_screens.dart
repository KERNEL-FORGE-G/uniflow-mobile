import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthTitle(
              title: 'Connexion', subtitle: 'Bienvenue de retour !'),
          const SizedBox(height: 22),
          const AuthTextField(
            label: 'Email',
            hint: 'exemple@gmail.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          const AuthTextField(
            label: 'Mot de passe',
            hint: '********',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
          const SizedBox(height: 6),
          AuthPrimaryButton(
            label: 'Se connecter',
            onPressed: () => context.go('/etudiants'),
          ),
          const SizedBox(height: 20),
          const AuthDivider(label: 'ou continuer avec'),
          const SizedBox(height: 16),
          const SocialButton(
            label: 'Continuer avec Google',
            iconText: 'G',
            iconColor: Color(0xFF4285F4),
          ),
          const SizedBox(height: 10),
          const SocialButton(
            label: 'Continuer avec Microsoft',
            iconText: 'M',
            iconColor: Color(0xFF00A4EF),
          ),
          const SizedBox(height: 24),
          AuthFooter(
            text: 'Pas encore de compte ?',
            action: "S'inscrire",
            onPressed: () => context.go('/register'),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthTitle(
            title: 'Créer un compte',
            subtitle: 'Rejoignez UniFlow dès maintenant',
          ),
          const SizedBox(height: 22),
          const AuthTextField(
            label: 'Nom complet',
            hint: 'Votre nom complet',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          const AuthTextField(
            label: 'Email',
            hint: 'exemple@gmail.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          const AuthTextField(
            label: 'Mot de passe',
            hint: '********',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 14),
          const AuthTextField(
            label: 'Confirmer le mot de passe',
            hint: '********',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: false,
                  onChanged: (_) {},
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: "J'accepte les ",
                    children: [
                      TextSpan(
                        text: "Conditions d'utilisation",
                        style: TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' et la '),
                      TextSpan(
                        text: 'Politique de confidentialité',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: "S'inscrire",
            onPressed: () => context.go('/etudiants'),
          ),
          const SizedBox(height: 24),
          AuthFooter(
            text: 'Vous avez déjà un compte ?',
            action: 'Se connecter',
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthTitle(
            title: 'Mot de passe oublié ?',
            subtitle:
                'Entrez votre email pour recevoir un lien de réinitialisation.',
          ),
          const SizedBox(height: 24),
          const AuthTextField(
            label: 'Email',
            hint: 'exemple@gmail.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          const AuthPrimaryButton(label: 'Envoyer le lien'),
          const SizedBox(height: 34),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  color: Color(0xFF8CA3D8),
                  size: 44,
                ),
                SizedBox(height: 12),
                Text(
                  'Vérifiez votre boîte mail',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Le lien de réinitialisation expire dans 15 minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  final Widget child;

  const AuthScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.teal,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 19, color: AppColors.textMuted),
            suffixIcon: obscureText
                ? const Icon(
                    Icons.visibility_off_outlined,
                    size: 19,
                    color: AppColors.textMuted,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed ?? () {},
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  final String label;

  const AuthDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
      ],
    );
  }
}

class SocialButton extends StatelessWidget {
  final String label;
  final String iconText;
  final Color iconColor;

  const SocialButton({
    super.key,
    required this.label,
    required this.iconText,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              iconText,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthFooter extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onPressed;

  const AuthFooter({
    super.key,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: const TextStyle(
              color: AppColors.teal,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
