import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_role.dart';
import '../providers/providers.dart';
import '../providers/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';

/// Mot à recopier pour confirmer la suppression — le même que sur le web.
const String deletionKeyword = 'SUPPRIMER';

/// Le mot doit être recopié exactement (majuscules comprises) : c'est un
/// geste volontaire, pas un champ à remplir vite. Fonction pure, testée.
bool deletionKeywordMatches(String input) => input.trim() == deletionKeyword;

/// Suppression du compte par son titulaire, en deux étapes : mot de passe
/// (revérifié par une ouverture de session), puis le mot « SUPPRIMER ».
///
/// Un `superadmin` n'a pas la case : la plateforme ne doit pas pouvoir
/// perdre son administrateur d'un geste, et le serveur refuse de toute
/// façon — autant le dire avant plutôt qu'après un mot de passe saisi.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _keyword = TextEditingController();
  int _step = 0;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Saisissez votre mot de passe.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider).verifyPassword(user.email, _password.text);
      if (mounted) setState(() => _step = 1);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!deletionKeywordMatches(_keyword.text)) {
      setState(() => _error = 'Recopiez exactement le mot $deletionKeyword.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider).deleteOwnAccount();
      if (mounted) setState(() => _step = 2);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isSuperadmin = user?.labels.any((l) => l.toLowerCase() == 'superadmin') ?? false;

    if (_step == 2) {
      // `clearLocalState` a déjà basculé `authStatusProvider` : la garde du
      // routeur renverra à la connexion dès que cet écran sera quitté.
      return Scaffold(
        body: FeedbackView(
          kind: FeedbackKind.success,
          title: 'Compte supprimé',
          message: 'Vos données ont été retirées d\'UniFlow. Merci d\'avoir utilisé l\'application.',
          actionLabel: 'Revenir à l\'accueil',
          onAction: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Supprimer mon compte')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cette action est définitive : compte, profil, messages et données personnelles seront effacés.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (isSuperadmin)
            const FeedbackBanner(
              kind: FeedbackKind.info,
              message: 'Le compte administrateur de la plateforme ne peut pas être supprimé depuis l\'application.',
            )
          else ...[
            _StepHeader(index: 1, label: 'Confirmez votre mot de passe', active: _step == 0, done: _step > 0),
            if (_step == 0) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: _obscure,
                autofocus: true,
                enabled: !_busy,
                onSubmitted: (_) => _verifyPassword(),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _StepHeader(index: 2, label: 'Recopiez le mot $deletionKeyword', active: _step == 1, done: false),
            if (_step == 1) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _keyword,
                autofocus: true,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _delete(),
                decoration: const InputDecoration(
                  labelText: deletionKeyword,
                  prefixIcon: Icon(Icons.delete_forever_outlined, size: 20),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
            ],
            const SizedBox(height: 22),
            if (_step == 0)
              PrimaryButton(
                  label: 'Continuer',
                  icon: Icons.arrow_forward,
                  isLoading: _busy,
                  onPressed: _busy ? null : _verifyPassword)
            else
              FilledButton.icon(
                onPressed: _busy ? null : _delete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.delete_forever_outlined),
                label: const Text('Supprimer définitivement mon compte'),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  final bool done;
  const _StepHeader({required this.index, required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : active
            ? AppColors.primaryBlue
            : AppColors.textMuted;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.h3.copyWith(color: active || done ? AppColors.textPrimary : AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// Le rôle n'entre pas dans la décision : un ADMIN d'université peut
/// supprimer son propre compte ; seul le label `superadmin` protège.
bool canDeleteOwnAccount(UniFlowRole role, List<String> labels) => !labels.any((l) => l.toLowerCase() == 'superadmin');
