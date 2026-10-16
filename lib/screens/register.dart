import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_role.dart';
import '../providers/providers.dart';
import '../repositories/auth_repository.dart';
import '../repositories/reference_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/feedback.dart';
import '../widgets/phosphor.dart';
import '../widgets/uni/uni_mascot.dart';

/// Écran d'inscription unifié UniFlow.
///
/// Implémente la distinction stricte :
/// - Compte Académique : réservé aux étudiants (cascade Université → Faculté →
///   Filière → Niveau + Matricule). Les enseignants et l'administration sont
///   créés depuis le panel Admin.
/// - Compte Indépendant : pour les étudiants, délégués et enseignants
///   indépendants (autonomes, sans rattachement universitaire).
class RegisterScreen extends ConsumerStatefulWidget {
  final UniFlowAccountType initialType;

  const RegisterScreen({super.key, this.initialType = UniFlowAccountType.personal});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late UniFlowAccountType _type;

  // Contrôleurs communs
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _matricule = TextEditingController();

  // Rôle indépendant (parmi Étudiant, Délégué, Enseignant)
  UniFlowRole _independentRole = UniFlowRole.student;

  // Cursus académique (compte universitaire)
  String _selectedUnivCode = 'UY1';
  String _selectedUnivName = 'Université de Yaoundé I';
  String _selectedFacultyCode = 'FS';
  String _selectedProgramCode = 'ICT4D';
  String _selectedLevel = 'L1';
  List<String> _currentAvailableLevels = const ['L1', 'L2', 'L3', 'M1', 'M2'];

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _matricule.dispose();
    super.dispose();
  }

  RegistrationInput _input() {
    final isUni = _type == UniFlowAccountType.university;
    return RegistrationInput(
      email: _email.text.trim(),
      password: _password.text,
      name: _name.text.trim(),
      accountType: _type,
      university: isUni ? _selectedUnivName : '',
      faculty: isUni ? _selectedFacultyCode : '',
      program: isUni ? _selectedProgramCode : '',
      level: isUni ? _selectedLevel : null,
      matricule: isUni ? _matricule.text.trim() : '',
      availableLevels: isUni ? _currentAvailableLevels : const [],
      role: isUni ? UniFlowRole.student : _independentRole,
    );
  }

  Future<void> _submit() async {
    final input = _input();
    final invalid = validateRegistration(input) ?? passwordConfirmationError(_password.text, _confirm.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    if (_type == UniFlowAccountType.university && _matricule.text.trim().isEmpty) {
      setState(() => _error = 'Le matricule étudiant est obligatoire pour un compte universitaire.');
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
    final isUni = _type == UniFlowAccountType.university;

    // Récupération des référentiels académiques avec fallbacks résilients
    final universitiesAsync = ref.watch(universitiesProvider);
    final facultiesAsync = ref.watch(facultiesProvider(_selectedUnivCode));
    final programsAsync = ref.watch(programsProvider('$_selectedUnivCode|$_selectedFacultyCode'));

    return AuthScaffold(
      pose: _error != null ? UniPose.sorry : UniPose.pointing,
      headline: const AuthHeadline('Créez votre compte et ', 'simplifiez', ' vos études.'),
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

          // ── Sélecteur de type : Académique vs Indépendant ──
          AccountTypeSelector(
            value: _type,
            onChanged: _busy
                ? null
                : (newType) {
                    setState(() {
                      _type = newType;
                      _error = null;
                    });
                  },
          ),
          const SizedBox(height: 12),

          if (isUni) ...[
            // ── Avertissement Compte Académique (Étudiants uniquement) ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhosphorIcon(PhosphorIconsBold.graduationCap, color: Color(0xFF1E3A8A), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte Académique (Étudiants)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E3A8A)),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'L\'auto-inscription est réservée aux étudiants. Les comptes Enseignants et Administration sont créés directement depuis le panel Admin de la Faculté.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Section Cursus Académique ──
            const Text(
              'CURSUS UNIVERSITAIRE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            // Dropdown Université
            universitiesAsync.when(
              data: (univs) {
                if (univs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucune université disponible dans la base.'),
                  );
                }
                final selectedCode =
                    univs.any((u) => u.code == _selectedUnivCode) ? _selectedUnivCode : univs.first.code;
                return DropdownButtonFormField<String>(
                  initialValue: selectedCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Université',
                    prefixIcon: PhosphorIcon(PhosphorIconsBold.buildings, size: 20),
                  ),
                  items: univs
                      .map((u) => DropdownMenuItem(
                            value: u.code,
                            child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (code) {
                          if (code == null) return;
                          final u = univs.firstWhere((x) => x.code == code, orElse: () => univs.first);
                          setState(() {
                            _selectedUnivCode = u.code;
                            _selectedUnivName = u.name;
                          });
                        },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Erreur de chargement: $err', style: AppTextStyles.bodySmall),
            ),
            const SizedBox(height: 12),

            // Dropdown Faculté
            facultiesAsync.when(
              data: (facs) {
                if (facs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucune faculté trouvée pour cette université.'),
                  );
                }
                final selectedCode =
                    facs.any((f) => f.code == _selectedFacultyCode) ? _selectedFacultyCode : facs.first.code;
                return DropdownButtonFormField<String>(
                  initialValue: selectedCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Faculté / Établissement',
                    prefixIcon: PhosphorIcon(PhosphorIconsBold.buildings, size: 20),
                  ),
                  items: facs
                      .map((f) => DropdownMenuItem(
                            value: f.code,
                            child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (code) {
                          if (code == null) return;
                          final f = facs.firstWhere((x) => x.code == code, orElse: () => facs.first);
                          setState(() {
                            _selectedFacultyCode = f.code;
                          });
                        },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Erreur faculté: $err', style: AppTextStyles.bodySmall),
            ),
            const SizedBox(height: 12),

            // Dropdown Filière
            programsAsync.when(
              data: (progs) {
                if (progs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucune filière trouvée pour cet établissement.'),
                  );
                }
                final selectedCode =
                    progs.any((p) => p.code == _selectedProgramCode) ? _selectedProgramCode : progs.first.code;
                final currentProg = progs.firstWhere((p) => p.code == selectedCode, orElse: () => progs.first);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Filière d\'études',
                        prefixIcon: PhosphorIcon(PhosphorIconsBold.books, size: 20),
                      ),
                      items: progs
                          .map((p) => DropdownMenuItem(
                                value: p.code,
                                child: Text('${p.name} (${p.code})', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (code) {
                              if (code == null) return;
                              final p = progs.firstWhere((x) => x.code == code, orElse: () => progs.first);
                              setState(() {
                                _selectedProgramCode = p.code;
                                _currentAvailableLevels = p.levels.isNotEmpty ? p.levels : const ['L1', 'L2', 'L3'];
                                if (!_currentAvailableLevels.contains(_selectedLevel)) {
                                  _selectedLevel = _currentAvailableLevels.first;
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 12),

                    // Sélecteur dynamique des niveaux réels de la filière (issus de la BD)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Niveau d\'études ouvert (${currentProg.code})',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children:
                              (currentProg.levels.isNotEmpty ? currentProg.levels : ['L1', 'L2', 'L3']).map((lvl) {
                            final selected = _selectedLevel == lvl;
                            return ChoiceChip(
                              label: Text(lvl,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: selected ? Colors.white : AppColors.textPrimary)),
                              selected: selected,
                              selectedColor: AppColors.primaryBlue,
                              backgroundColor: AppColors.inputFill,
                              onSelected: _busy
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _selectedLevel = lvl;
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Erreur filière: $err', style: AppTextStyles.bodySmall),
            ),
            const SizedBox(height: 12),

            // Matricule étudiant
            TextField(
              controller: _matricule,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Matricule étudiant',
                hintText: 'Ex: 22T2841',
                prefixIcon: PhosphorIcon(PhosphorIconsBold.identificationCard, size: 20),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            // ── Compte Indépendant : Choix du rôle ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  PhosphorIcon(PhosphorIconsBold.globe, color: Color(0xFF0D9488), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Espace Indépendant (Autonome)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F766E)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Non rattaché à une université. Choisissez votre profil pour organiser vos cours et plannings.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF047857), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'VOTRE PROFIL INDÉPENDANT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            IndependentRoleSelector(
              value: _independentRole,
              onChanged: _busy ? null : (r) => setState(() => _independentRole = r),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_independentRole) {
                UniFlowRole.student => 'Étudiant indépendant : organisez vos cours personnels, devoirs et examens.',
                UniFlowRole.delegate =>
                  'Délégué indépendant : coordonnez votre groupe d\'étude et diffusez les plannings.',
                UniFlowRole.teacher => 'Enseignant indépendant : publiez des supports, exercices et corrigés.',
                _ => 'Espace personnel autonome.',
              },
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
          ],

          if (_error != null) ...[
            FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
            const SizedBox(height: 16),
          ],

          // ── Identité & Sécurité (Communs) ──
          const Text(
            'INFORMATIONS PERSONNELLES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              hintText: 'Ex: Samuel Eto\'o',
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
              hintText: 'vous@exemple.com',
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

          // ── Bouton Inscription ──
          GradientButton(
            label: isUni
                ? 'Créer mon compte Étudiant Universitaire'
                : 'Créer mon compte ${_independentRole.label.toLowerCase()}',
            icon: isUni ? PhosphorIconsBold.graduationCap : PhosphorIconsBold.userPlus,
            isLoading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 12),

          TextButton.icon(
            onPressed: _busy ? null : _openWeb,
            icon: const PhosphorIcon(PhosphorIconsBold.arrowSquareOut, size: 16),
            label: const Text('S\'inscrire depuis le portail web', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
