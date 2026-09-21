import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../repositories/auth_repository.dart';
import '../repositories/reference_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/feedback.dart';
import '../widgets/uni/uni_mascot.dart';

/// Inscription native, miroir de la page `/register` du web.
///
/// Un compte universitaire n'a **aucun** choix de rôle : il naît `STUDENT`, et
/// les rôles supérieurs ne se donnent que par labels, posés par
/// l'administration. Le formulaire enchaîne université → faculté → filière →
/// niveau à partir des collections de référence lues sans session
/// (`universities`, `faculties`, `academic_programs`) : rien n'est codé en
/// dur, et les niveaux offerts sont ceux de la filière (`levels`, M1 compris).
/// Ni le rôle ADMIN ni le type PLATFORM ne sont proposés : ils se posent côté
/// serveur.
class RegisterScreen extends ConsumerStatefulWidget {
  final UniFlowAccountType initialType;

  const RegisterScreen({super.key, this.initialType = UniFlowAccountType.university});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _matricule = TextEditingController();
  late UniFlowAccountType _type = widget.initialType;
  University? _university;
  Faculty? _faculty;
  AcademicProgram? _program;
  String? _level;
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
        university: _university?.name ?? '',
        faculty: _faculty?.code ?? '',
        program: _program?.code ?? '',
        level: _level,
        matricule: _matricule.text,
        availableLevels: _program?.levels ?? const [],
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
    final university = _type == UniFlowAccountType.university;
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
          const SizedBox(height: 18),
          AccountTypeSelector(
            value: _type,
            onChanged: _busy ? null : (type) => setState(() => _type = type),
          ),
          const SizedBox(height: 8),
          Text(
            university
                ? 'Compte étudiant rattaché à votre université.'
                : 'Espace personnel pour organiser vos propres études.',
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
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
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
              prefixIcon: Icon(Icons.mail_outline, size: 20),
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
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
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
            textInputAction: university ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) => university || _busy ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icon(Icons.lock_reset_outlined, size: 20),
            ),
          ),
          // La partie académique glisse en place quand on passe d'un type à
          // l'autre plutôt que d'apparaître d'un bloc.
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: university ? _academicFields() : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 22),
          GradientButton(
            label: university ? 'Créer mon compte étudiant' : 'Créer mon espace personnel',
            isLoading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _busy ? null : _openWeb,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('S\'inscrire depuis le site web', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _academicFields() {
    final universities = ref.watch(universitiesProvider);
    final faculties = ref.watch(facultiesProvider(_university?.code ?? ''));
    final programs = ref.watch(programsProvider('${_university?.code ?? ''}|${_faculty?.code ?? ''}'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        const Text('Rattachement académique', style: AppTextStyles.label),
        const SizedBox(height: 10),
        _ReferenceDropdown<University>(
          label: 'Université',
          icon: Icons.account_balance_outlined,
          value: _university,
          items: universities,
          itemLabel: (u) => u.shortName.isEmpty ? u.name : '${u.name} (${u.shortName})',
          emptyMessage: 'Aucune université n\'est encore ouverte à l\'inscription.',
          enabled: !_busy,
          onChanged: (u) => setState(() {
            _university = u;
            _faculty = null;
            _program = null;
            _level = null;
          }),
        ),
        const SizedBox(height: 12),
        _ReferenceDropdown<Faculty>(
          label: 'Faculté ou établissement',
          icon: Icons.domain_outlined,
          value: _faculty,
          items: faculties,
          itemLabel: (f) => f.name,
          emptyMessage: _university == null
              ? 'Choisissez d\'abord une université.'
              : 'Aucune faculté enregistrée pour cette université.',
          enabled: !_busy && _university != null,
          onChanged: (f) => setState(() {
            _faculty = f;
            _program = null;
            _level = null;
          }),
        ),
        const SizedBox(height: 12),
        _ReferenceDropdown<AcademicProgram>(
          label: 'Filière',
          icon: Icons.school_outlined,
          value: _program,
          items: programs,
          itemLabel: (p) => '${p.name} (${p.code})',
          emptyMessage: _university == null
              ? 'Choisissez d\'abord une université.'
              : 'Aucune filière enregistrée pour cette sélection.',
          enabled: !_busy && _university != null,
          onChanged: (p) => setState(() {
            _program = p;
            _level = null;
          }),
        ),
        const SizedBox(height: 12),
        _LevelChips(
          levels: _program?.levels ?? const [],
          value: _level,
          enabled: !_busy,
          onChanged: (level) => setState(() => _level = level),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _matricule,
          enabled: !_busy,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _submit(),
          decoration: const InputDecoration(
            labelText: 'Matricule (facultatif)',
            prefixIcon: Icon(Icons.numbers, size: 20),
          ),
        ),
      ],
    );
  }
}

/// Liste déroulante alimentée par une collection de référence, avec ses états
/// de chargement, d'erreur et de liste vide.
class _ReferenceDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final AsyncValue<List<T>> items;
  final String Function(T) itemLabel;
  final String emptyMessage;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  const _ReferenceDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.emptyMessage,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return items.when(
      loading: () => InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (error, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          errorText: 'Liste indisponible : $error',
          errorMaxLines: 3,
        ),
        child: const SizedBox.shrink(),
      ),
      data: (list) {
        if (list.isEmpty) {
          return InputDecorator(
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
            child: Text(emptyMessage, style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          );
        }
        // La valeur courante doit appartenir à la liste, sinon le widget lève.
        final current = list.contains(value) ? value : null;
        return DropdownButtonFormField<T>(
          initialValue: current,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
          items: [
            for (final item in list)
              DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        );
      },
    );
  }
}

/// Niveaux ouverts par la filière (« L1,L2,L3 »), en pastilles.
class _LevelChips extends StatelessWidget {
  final List<String> levels;
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _LevelChips({
    required this.levels,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Niveau', style: AppTextStyles.label),
        const SizedBox(height: 8),
        if (levels.isEmpty)
          const Text(
            'Choisissez d\'abord une filière : ses niveaux ouverts apparaîtront ici.',
            style: AppTextStyles.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in levels)
                ChoiceChip(
                  label: Text(level),
                  selected: value == level,
                  onSelected: enabled ? (_) => onChanged(level) : null,
                  selectedColor: AppColors.primary100,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value == level ? AppColors.primaryBlue : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
