import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';

/// Au-dessus de cette largeur, la carte cesse de s'étirer : un formulaire
/// large de toute la fenêtre est inconfortable à lire. Le seuil sert aux
/// tablettes et aux fenêtres redimensionnées, pas au téléphone en portrait.
const double kAuthCompactWidth = 480;

/// Fond, formes décoratives et centrage communs aux écrans hors session
/// (connexion, inscription, mot de passe oublié).
///
/// La mise en page s'adapte à la taille de la fenêtre : le contenu est centré
/// quand il y a de la place, et la page défile quand il n'y en a pas (petit
/// téléphone, clavier ouvert). Aucune largeur n'est imposée sans qu'un parent
/// puisse la réduire, ce qui évite les débordements.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final bool showBrand;

  const AuthScaffold({super.key, required this.child, this.showBrand = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              child: _Blob(size: 260, color: AppColors.primaryBlue.withValues(alpha: 0.10)),
            ),
            Positioned(
              bottom: -130,
              left: -100,
              child: _Blob(size: 280, color: AppColors.teal.withValues(alpha: 0.12)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth < kAuthCompactWidth ? 20.0 : 32.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: kAuthCompactWidth),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showBrand) ...[
                                const BrandHeader(),
                                const SizedBox(height: 28),
                              ],
                              child,
                              const SizedBox(height: 20),
                              const Text(
                                'UniFlow · KERNEL FORGE',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                              ),
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
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pastille dégradée : le logo posé sur un aplat blanc cassait la
        // continuité avec le dégradé de marque du web.
        Hero(
          tag: 'uniflow-brand',
          child: Container(
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
              // L'aplat clair sous l'écusson est indispensable : son mortier est
              // bleu marine et le dégradé de la pastille va du bleu au teal, donc
              // le logo transparent posé tel quel y disparaissait.
              child: ColoredBox(
                color: AppColors.cardWhite,
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Image.asset(
                    'assets/brand/uniflow_marque.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school_rounded,
                      color: AppColors.primaryBlue,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (bounds) => AppColors.logoGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: const Text(
            'UniFlow',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'La plateforme académique de référence',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.35),
        ),
      ],
    );
  }
}

/// La carte blanche qui porte un formulaire hors session.
class AuthCard extends StatelessWidget {
  final List<Widget> children;

  const AuthCard({super.key, required this.children});

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
        children: children,
      ),
    );
  }
}

/// Choix du type de compte, identique au web : un compte rattaché à une
/// université, ou un compte indépendant qui gère seul ses matières.
class AccountTypeSelector extends StatelessWidget {
  final UniFlowAccountType value;
  final ValueChanged<UniFlowAccountType>? onChanged;

  const AccountTypeSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeTile(
            selected: value == UniFlowAccountType.university,
            icon: Icons.account_balance_outlined,
            title: 'Compte universitaire',
            subtitle: 'Cours, notes, présences de ma filière',
            onTap: onChanged == null ? null : () => onChanged!(UniFlowAccountType.university),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TypeTile(
            selected: value == UniFlowAccountType.personal,
            icon: Icons.person_outline,
            title: 'Compte indépendant',
            subtitle: 'Mes matières, tâches et agenda',
            onTap: onChanged == null ? null : () => onChanged!(UniFlowAccountType.personal),
          ),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _TypeTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary50 : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.inputBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color, height: 1.2),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton principal, en dégradé bleu → teal avec une ombre portée colorée.
///
/// Construit à la main plutôt qu'avec `ElevatedButton` : `ElevatedButton` ne
/// sait pas peindre un dégradé, et c'est ce dégradé qui rattache visuellement
/// les écrans hors session au reste de la charte.
class GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child:
                                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.button),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.4)),
    );
  }
}
