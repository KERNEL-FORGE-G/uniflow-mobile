import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_photo_service.dart';
import '../utils/avatar.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../repositories/auth_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _uploading = false;
  String? _photoError;

  /// Vrai pendant l'enregistrement du pseudo.
  bool _savingUsername = false;
  String? _usernameError;

  /// Ouvre la boîte de dialogue de création / modification du pseudo.
  ///
  /// Le pseudo est l'adresse de la messagerie : il ne peut pas être vide, et
  /// c'est le serveur qui garantit son unicité.
  Future<void> _editUsername() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final controller = TextEditingController(text: user.username ?? '');
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.username == null || user.username!.isEmpty
            ? 'Créer votre pseudo'
            : 'Changer de pseudo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vos contacts vous trouvent par ce pseudo dans la messagerie.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'prenom.nom',
                helperText: '3 à 32 caractères : lettres, chiffres, . _ -',
              ),
              onSubmitted: (value) => Navigator.pop(ctx, value),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (submitted == null || !mounted) return;

    final normalized = normalizeUsername(submitted);
    if (normalized == null) {
      setState(() => _usernameError =
          'Pseudo invalide : 3 à 32 caractères, lettres minuscules, chiffres, '
          'point, tiret ou souligné, en commençant par une lettre ou un chiffre.');
      return;
    }
    if (normalized == user.username) {
      setState(() => _usernameError = null);
      return;
    }

    setState(() {
      _savingUsername = true;
      _usernameError = null;
    });
    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updateUsername(user.id, normalized);
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = updated;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pseudo enregistré : @$normalized')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _usernameError = error.toString());
    } finally {
      if (mounted) setState(() => _savingUsername = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez ressaisir vos identifiants pour revenir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // Une session déjà expirée côté serveur ne doit pas bloquer la sortie.
    }
    ref.read(currentUserProvider.notifier).state = null;
    ref.read(studentsProvider.notifier).state = const [];
    ref.read(teachersProvider.notifier).state = const [];
    ref.read(uesProvider.notifier).state = const [];
    ref.read(authStatusProvider.notifier).state = AuthStatus.signedOut;
  }

  Future<void> _pickAndUpload() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _photoError = null);

    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      // Le redimensionnement évite d'envoyer une photo de 12 Mpx alors que
      // l'avatar s'affiche au plus en 96 px : le quota du bucket et la
      // connexion de l'utilisateur en profitent tous les deux.
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (picked == null) return;

    final invalid = validateAvatarPath(picked.path);
    if (invalid != null) {
      setState(() => _photoError = invalid);
      return;
    }

    setState(() => _uploading = true);
    try {
      await ref.uploadAvatar(File(picked.path), user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _photoError = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.avatarFileId == null || user.avatarFileId!.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer la photo ?'),
        content: const Text('Vos initiales réapparaîtront à la place.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _uploading = true;
      _photoError = null;
    });
    try {
      await ref.removeAvatar(user);
    } catch (error) {
      if (mounted) setState(() => _photoError = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final hasPhoto = user?.avatarFileId != null && user!.avatarFileId!.isNotEmpty;

    return Column(
      children: [
        const GradientHeader(title: 'Réglages', subtitle: 'Préférences de l\'application'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _PhotoAvatar(
                        initials: user == null ? '?' : initialsOf(user.name),
                        avatarFileId: user?.avatarFileId,
                        uploading: _uploading,
                      ),
                      title: Text(user?.name ?? 'Non connecté',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        user == null
                            ? 'Aucune session active'
                            : (user.username == null || user.username!.isEmpty
                                ? '${user.role} · ${user.email}'
                                : '@${user.username} · ${user.role}'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 8),
                      // `Wrap` et non `Row` : « Changer la photo » et « Retirer »
                      // ne tiennent pas sur une même ligne à 320 px de large, et
                      // la ligne débordait de 44 px. Ici le second bouton passe
                      // simplement à la ligne suivante.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickAndUpload,
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: Text(hasPhoto ? 'Changer la photo' : 'Ajouter une photo'),
                          ),
                          if (hasPhoto)
                            TextButton(
                              onPressed: _uploading ? null : _removePhoto,
                              child: const Text('Retirer',
                                  style: TextStyle(color: AppColors.danger)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPEG, PNG ou WebP · 5 Mo maximum',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (_photoError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _photoError!,
                          style: const TextStyle(fontSize: 12, color: AppColors.danger),
                        ),
                      ],
                    ],
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alternate_email, color: AppColors.primaryBlue),
                      title: const Text('Pseudo de messagerie'),
                      subtitle: Text(
                        user == null || user.username == null || user.username!.isEmpty
                            ? 'Aucun pseudo : vous n\'êtes pas joignable'
                            : '@${user.username}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: _savingUsername
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      onTap: user == null || _savingUsername ? null : _editUsername,
                    ),
                    if (_usernameError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _usernameError!,
                          style: const TextStyle(fontSize: 12, color: AppColors.danger),
                        ),
                      ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.security_outlined, color: AppColors.primaryBlue),
                      title: const Text('Sentinelle IoT'),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      onTap: () => GoRouter.of(context).push('/sentinelle'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_outlined, color: AppColors.primaryBlue),
                      title: const Text('L\'Équipe KERNEL FORGE'),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      onTap: () => GoRouter.of(context).push('/equipe'),
                    ),
                    if (user != null) ...[
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout, color: AppColors.danger),
                        title: const Text('Se déconnecter',
                            style: TextStyle(color: AppColors.danger)),
                        onTap: _logout,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// L'avatar du profil, surmonté d'un voile pendant le téléversement pour que
/// l'attente soit visible sans masquer l'image en cours de remplacement.
class _PhotoAvatar extends StatelessWidget {
  final String initials;
  final String? avatarFileId;
  final bool uploading;

  const _PhotoAvatar({
    required this.initials,
    required this.avatarFileId,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Avatar(initials: initials, avatarFileId: avatarFileId, size: 52);
    if (!uploading) return avatar;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
