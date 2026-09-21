import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../providers/providers.dart';
import '../repositories/admin_directory_repository.dart';
import '../repositories/reference_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/motion.dart';
import '../widgets/phosphor.dart';

/// Comptes de l'université, pour l'administration (`ADMIN`).
///
/// Création, modification (rôle, statut, rattachement) et suppression via
/// `/admin-directory`. Le rôle `ADMIN` n'est proposé qu'à l'administrateur de
/// la plateforme (`superadmin`) ; une administration ne gère que sa propre
/// université — le serveur le vérifie, l'écran ne propose pas l'inverse.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  String _query = '';
  UniFlowRole? _roleFilter;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(managedAccountsProvider);
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      floatingActionButton: GradientFab(
        icon: PhosphorIconsFill.userPlus,
        label: 'Compte',
        onPressed: () => _edit(context),
      ),
      body: Column(
        children: [
          GradientHeader(
            title: 'Comptes',
            subtitle: (me?.university ?? '').isEmpty ? 'Administration des comptes' : me!.university!,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SearchField(hint: 'Nom, e-mail, matricule…', onChanged: (v) => setState(() => _query = v)),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                _RoleChip(
                    label: 'Tous', selected: _roleFilter == null, onTap: () => setState(() => _roleFilter = null)),
                for (final role in [UniFlowRole.admin, UniFlowRole.teacher, UniFlowRole.delegate, UniFlowRole.student])
                  _RoleChip(
                      label: role.label,
                      selected: _roleFilter == role,
                      onTap: () => setState(() => _roleFilter = role)),
              ],
            ),
          ),
          Expanded(
            child: accounts.when(
              loading: () => const ShimmerList(),
              error: (error, _) => LoadErrorView(
                title: 'Les comptes n\'ont pas pu être chargés',
                error: error,
                onRetry: () => ref.invalidate(managedAccountsProvider),
              ),
              data: (list) {
                final filtered = filterAccounts(list, query: _query, role: _roleFilter);
                if (filtered.isEmpty) {
                  return const EmptyState(
                      icon: PhosphorIconsDuotone.userGear,
                      title: 'Aucun compte',
                      message: 'Aucun compte ne correspond à ce filtre.');
                }
                return StaggeredList(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final account = filtered[index];
                    return _AccountCard(
                      account: account,
                      isMe: account.userId == me?.id,
                      onTap: () => _edit(context, account: account),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, {ManagedAccount? account}) async {
    final me = ref.read(currentUserProvider);
    final roles = assignableRoles(me);
    if (roles.isEmpty) return;
    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountSheet(account: account, roles: roles, caller: me!),
    );
    if (result == null || !context.mounted) return;
    final repo = ref.read(adminDirectoryRepositoryProvider);
    try {
      String title;
      String? message;
      if (result.delete && account != null) {
        await repo.delete(account.userId);
        title = 'Compte supprimé';
        message = account.email;
      } else if (account == null) {
        final created = await repo.create(result.draft!);
        title = 'Compte créé';
        message = '${created.name} · ${created.email}\nRôle ${mapRole(created.role).label}.';
      } else {
        await repo.update(account.userId, result.draft!);
        title = 'Compte mis à jour';
        message = result.draft!.email;
      }
      ref.invalidate(managedAccountsProvider);
      ref.invalidate(academicSyncProvider);
      if (context.mounted) await showFeedbackSheet(context, kind: FeedbackKind.success, title: title, message: message);
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context,
            kind: FeedbackKind.failure, title: 'Opération refusée', message: error.toString());
      }
    }
  }
}

/// Recherche plein texte (nom, e-mail, matricule, filière) et filtre de rôle.
/// Fonction pure, testée.
List<ManagedAccount> filterAccounts(List<ManagedAccount> all, {String query = '', UniFlowRole? role}) {
  final q = query.trim().toLowerCase();
  return all.where((a) {
    if (role != null && a.uniflowRole != role) return false;
    if (q.isEmpty) return true;
    return a.name.toLowerCase().contains(q) ||
        a.email.toLowerCase().contains(q) ||
        a.matricule.toLowerCase().contains(q) ||
        a.program.toLowerCase().contains(q);
  }).toList();
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary100,
        labelStyle:
            TextStyle(fontWeight: FontWeight.w600, color: selected ? AppColors.primaryBlue : AppColors.textSecondary),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final ManagedAccount account;
  final bool isMe;
  final VoidCallback onTap;

  const _AccountCard({required this.account, required this.isMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final role = account.uniflowRole;
    final suspended = account.status.toUpperCase() != 'ACTIVE';
    final initials =
        account.name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
    return SectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Row(
          children: [
            Avatar(initials: initials.isEmpty ? '?' : initials, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${account.name} (vous)' : account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 2),
                  Text(account.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Tag(label: account.isSuperAdmin ? 'Plateforme' : role.label, color: _roleColor(role)),
                      if (account.program.isNotEmpty)
                        _Tag(
                            label: [account.program, if (account.level.isNotEmpty) account.level].join(' · '),
                            color: AppColors.teal),
                      if (suspended) const _Tag(label: 'Suspendu', color: AppColors.danger),
                    ],
                  ),
                ],
              ),
            ),
            const PhosphorIcon(PhosphorIconsBold.caretRight, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  static Color _roleColor(UniFlowRole role) => switch (role) {
        UniFlowRole.admin => AppColors.purple,
        UniFlowRole.teacher => AppColors.primaryBlue,
        UniFlowRole.delegate => AppColors.warning,
        _ => AppColors.textSecondary,
      };
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => StatusBadge(
        label: label,
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: Color.lerp(color, Colors.black, 0.2),
      );
}

class _SheetResult {
  final AccountDraft? draft;
  final bool delete;
  const _SheetResult({this.draft, this.delete = false});
}

class _AccountSheet extends ConsumerStatefulWidget {
  final ManagedAccount? account;
  final List<UniFlowRole> roles;
  final UniFlowUser caller;

  const _AccountSheet({required this.account, required this.roles, required this.caller});

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _email = TextEditingController(text: widget.account?.email ?? '');
  final _password = TextEditingController();
  late final _matricule = TextEditingController(text: widget.account?.matricule ?? '');
  late UniFlowRole _role = widget.account == null
      ? (widget.roles.contains(UniFlowRole.student) ? UniFlowRole.student : widget.roles.first)
      : widget.account!.uniflowRole;
  late String _program = widget.account?.program ?? widget.caller.program ?? '';
  late String _level = widget.account?.level ?? '';
  late bool _active = (widget.account?.status ?? 'ACTIVE').toUpperCase() == 'ACTIVE';
  String? _error;

  bool get _creating => widget.account == null;
  bool get _learner => _role == UniFlowRole.student || _role == UniFlowRole.delegate;

  /// Code d'université du compte appelant, pour lister ses filières : le
  /// document `users` porte le nom, la collection de référence le code, on
  /// retrouve le code par le nom.
  String _universityCode(List<University> universities) {
    final name = (widget.caller.university ?? '').trim().toLowerCase();
    return universities.where((u) => u.name.trim().toLowerCase() == name).map((u) => u.code).firstOrNull ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _matricule.dispose();
    super.dispose();
  }

  void _submit() {
    final draft = AccountDraft(
      name: _name.text,
      email: _email.text,
      password: _password.text,
      role: _role,
      university: widget.caller.university ?? '',
      program: _program,
      level: _learner ? _level : '',
      matricule: _matricule.text,
      status: _active ? 'ACTIVE' : 'SUSPENDED',
    );
    final invalid = draft.validate(creating: _creating);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    Navigator.of(context).pop(_SheetResult(draft: draft));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
            '${widget.account!.name} perdra son accès. Un compte qui porte des notes ou des présences sera refusé : suspendez-le plutôt.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(const _SheetResult(delete: true));
  }

  @override
  Widget build(BuildContext context) {
    final universities = ref.watch(universitiesProvider).value ?? const <University>[];
    final universityCode = _universityCode(universities);
    final programs = ref.watch(programsProvider('$universityCode|')).value ?? const <AcademicProgram>[];
    final selectedProgram = programs.where((p) => p.code.toUpperCase() == _program.toUpperCase()).firstOrNull;
    final levels = selectedProgram?.levels ?? const <String>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_creating ? 'Nouveau compte' : 'Modifier le compte', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              _creating
                  ? 'Le compte reçoit son rôle par label Appwrite et, s\'il est apprenant, ses inscriptions aux cours de sa filière.'
                  : widget.account!.email,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
              const SizedBox(height: 12),
            ],
            TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom complet')),
            const SizedBox(height: 12),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email')),
            if (_creating) ...[
              const SizedBox(height: 12),
              TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe initial (8 caractères min.)')),
            ],
            const SizedBox(height: 14),
            const Text('Rôle', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in widget.roles)
                  ChoiceChip(
                    label: Text(role.label),
                    selected: _role == role,
                    onSelected: (_) => setState(() => _role = role),
                    selectedColor: AppColors.primary100,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _role == role ? AppColors.primaryBlue : AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (programs.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: selectedProgram?.code,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Filière', prefixIcon: PhosphorIcon(PhosphorIconsBold.graduationCap, size: 20)),
                items: [
                  for (final p in programs)
                    DropdownMenuItem(
                        value: p.code,
                        child: Text('${p.name} (${p.code})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() {
                  _program = v ?? '';
                  _level = '';
                }),
              )
            else
              TextField(
                controller: TextEditingController(text: _program),
                onChanged: (v) => _program = v,
                decoration: const InputDecoration(
                    labelText: 'Filière (code)', prefixIcon: PhosphorIcon(PhosphorIconsBold.graduationCap, size: 20)),
              ),
            if (_learner) ...[
              const SizedBox(height: 12),
              const Text('Niveau', style: AppTextStyles.label),
              const SizedBox(height: 8),
              if (levels.isEmpty)
                TextField(
                  controller: TextEditingController(text: _level),
                  onChanged: (v) => _level = v.toUpperCase(),
                  decoration: const InputDecoration(labelText: 'Niveau (L1, L2…)'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final level in levels)
                      ChoiceChip(
                        label: Text(level),
                        selected: _level == level,
                        onSelected: (_) => setState(() => _level = level),
                        selectedColor: AppColors.primary100,
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              TextField(
                  controller: _matricule,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Matricule (facultatif)')),
            ],
            if (!_creating) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compte actif'),
                subtitle: const Text('Un compte suspendu ne peut plus se connecter ; ses historiques sont conservés.'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(label: _creating ? 'Créer le compte' : 'Enregistrer', onPressed: _submit),
            if (!_creating && !widget.account!.isSuperAdmin && widget.account!.userId != widget.caller.id) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const PhosphorIcon(PhosphorIconsBold.trash, size: 18),
                label: const Text('Supprimer le compte'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
