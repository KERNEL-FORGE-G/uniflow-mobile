import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/providers.dart';
import '../repositories/messaging_repository.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/common.dart';

/// Fil de discussion avec un contact.
///
/// L'écran reçoit la conversation déjà sérialisée par la liste, puis la
/// rafraîchit via l'action `list` : une seule requête ramène l'ensemble des fils
/// et leur contenu, sans action supplémentaire à ajouter côté fonction.
class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;

  /// Conversation transmise par la liste, pour peindre l'écran immédiatement
  /// plutôt que d'attendre le réseau.
  final Conversation? initial;

  const ConversationScreen({super.key, required this.conversationId, this.initial});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Conversation? _conversation;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  /// Pièce jointe choisie mais pas encore envoyée, et sa taille en octets.
  PlatformFile? _attachment;
  int _attachmentSize = 0;

  /// Le prochain message partira signalé comme urgent.
  bool _urgent = false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.initial;
    _loading = widget.initial == null;
    _load(markRead: true);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool markRead = false}) async {
    try {
      final conversations =
          await ref.read(messagingRepositoryProvider).getConversations();
      final current = conversations
          .where((item) => item.id == widget.conversationId)
          .cast<Conversation?>()
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        // Si la conversation a disparu de la liste (contact retiré de
        // l'annuaire), on garde celle qu'on affiche déjà au lieu de vider
        // l'écran sous les yeux de l'utilisateur.
        if (current != null) _conversation = current;
        _loading = false;
        _error = null;
      });
      if (markRead) {
        await ref.read(messagingRepositoryProvider).markRead(widget.conversationId);
      }
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  /// Ouvre le sélecteur de fichiers, sans filtre d'extension.
  ///
  /// Le bucket accepte tous les types : restreindre ici reviendrait à refuser
  /// des formats légitimes (archives de projet, feuilles de calcul, audio).
  Future<void> _pickAttachment() async {
    if (_sending) return;
    try {
      // file_picker 13 expose `pickFile`, qui renvoie directement le fichier
      // choisi ou `null` si l'utilisateur ferme le sélecteur.
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final path = picked.path;
      if (path == null) {
        if (!mounted) return;
        setState(() => _error =
            '« ${picked.name} » n\'est pas un fichier local : il ne peut pas être '
            'téléversé depuis cet appareil.');
        return;
      }
      // Le sélecteur natif ne fournit pas toujours la taille : `length()`
      // retombe alors sur une lecture du fichier.
      final size = await picked.length() ?? await File(path).length();
      if (size > chatAttachmentMaxBytes) {
        if (!mounted) return;
        setState(() => _error =
            '« ${picked.name} » pèse ${_readable(size)} : la limite est de '
            '${_readable(chatAttachmentMaxBytes)}.');
        return;
      }
      setState(() {
        _attachment = picked;
        _attachmentSize = size;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Sélection du fichier impossible : $error');
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final attachment = _attachment;
    // Un fichier seul suffit : le texte n'est obligatoire que sans pièce jointe.
    if ((text.isEmpty && attachment == null) || _sending) return;

    setState(() => _sending = true);
    try {
      final repository = ref.read(messagingRepositoryProvider);
      final user = ref.read(currentUserProvider);
      final conversation = _conversation;
      var fileId = '';
      if (attachment != null) {
        if (conversation == null || user == null || conversation.userId.isEmpty) {
          throw MessagingException(
            'Conversation incomplète : impossible d\'attacher un fichier.',
          );
        }
        fileId = await repository.uploadAttachment(
          conversationId: widget.conversationId,
          otherUserId: conversation.userId,
          myUserId: user.id,
          path: attachment.path!,
          fileName: attachment.name,
        );
      }

      final notified = await repository.sendMessage(
        widget.conversationId,
        text,
        fileId: fileId,
        urgent: _urgent,
      );
      if (!mounted) return;
      setState(() {
        _conversation = repository.lastUpdate ?? _conversation;
        _attachment = null;
        _urgent = false;
        _error = null;
      });
      _input.clear();
      _scrollToEnd();
      // L'utilisateur doit savoir que son message a bien été signalé : sans ce
      // retour, la bascule d'urgence reste une intention invisible. Le serveur
      // seul sait si la notification a réellement été créée, d'où `notified`.
      if (notified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message urgent envoyé : le destinataire est notifié.')),
        );
      }
      ref.invalidate(conversationsProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Télécharge la pièce jointe puis la confie au système, qui choisit
  /// l'application capable de l'ouvrir.
  Future<void> _openAttachment(ChatMessage message) async {
    setState(() => _error = null);
    try {
      final bytes = await ref
          .read(messagingRepositoryProvider)
          .downloadAttachment(message.fileId);
      final directory = await getApplicationDocumentsDirectory();
      final safeName = message.fileName.isEmpty ? 'fichier' : message.fileName;
      final file = File('${directory.path}/uniflow_${message.id}_$safeName');
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        setState(() => _error =
            'Aucune application ne sait ouvrir « $safeName ». Le fichier a été '
            'enregistré dans ${directory.path}.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  /// Taille lisible, pour les messages d'erreur locaux.
  String _readable(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final messages = conversation?.messages ?? const <ChatMessage>[];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar(
              initials:
                  conversation == null ? '?' : initialsOf(conversation.name),
              avatarFileId: conversation?.avatarFileId,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    conversation?.name ?? 'Conversation',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conversation != null && conversation.handle.isNotEmpty)
                    Text(
                      conversation.handle,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: AppColors.danger.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                    onPressed: () => setState(() => _error = null),
                    tooltip: 'Masquer',
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? _EmptyThread(name: conversation?.name)
                    : RefreshIndicator(
                        onRefresh: () => _load(markRead: true),
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) => _Bubble(
                            message: messages[index],
                            onOpenAttachment: _openAttachment,
                          ),
                        ),
                      ),
          ),
          if (_attachment != null)
            _AttachmentPreview(
              file: _attachment!,
              size: _readable(_attachmentSize),
              onRemove: () => setState(() {
                _attachment = null;
                _attachmentSize = 0;
              }),
            ),
          _Composer(
            controller: _input,
            sending: _sending,
            urgent: _urgent,
            hasAttachment: _attachment != null,
            onToggleUrgent: () => setState(() => _urgent = !_urgent),
            onAttach: _pickAttachment,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  final String? name;
  const _EmptyThread({this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              name == null
                  ? 'Aucun message pour l\'instant.'
                  : 'Aucun message avec $name pour l\'instant.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Écrivez le premier message ci-dessous.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(ChatMessage) onOpenAttachment;

  const _Bubble({required this.message, required this.onOpenAttachment});

  /// Heure d'envoi, ou chaîne vide si l'horodatage est illisible : mieux vaut
  /// une bulle sans heure qu'une exception au milieu du fil.
  String get _time {
    final parsed = DateTime.tryParse(message.time);
    if (parsed == null) return '';
    return DateFormat.Hm().format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final foreground = mine ? Colors.white : AppColors.textPrimary;
    // Un message urgent se signale par un liseré, pas par une couleur de fond :
    // la couleur porte déjà l'information « envoyé » / « reçu ».
    final border = message.urgent
        ? Border.all(color: mine ? Colors.amber.shade200 : AppColors.danger, width: 2)
        : null;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primaryBlue : Colors.white,
          border: border,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.urgent) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.priority_high,
                      size: 13, color: mine ? Colors.amber.shade200 : AppColors.danger),
                  const SizedBox(width: 3),
                  Text(
                    'URGENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: mine ? Colors.amber.shade200 : AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
            ],
            if (message.hasAttachment) ...[
              _Attachment(message: message, onOpen: onOpenAttachment, mine: mine),
              // Le texte qui accompagne un fichier est souvent son nom : on ne
              // le répète pas sous l'aperçu.
              if (message.text.isNotEmpty && message.text != message.fileName)
                const SizedBox(height: 6),
            ],
            if (message.text.isNotEmpty && message.text != message.fileName)
              Text(
                message.text,
                style: TextStyle(color: foreground, fontSize: 14),
              ),
            if (_time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _time,
                style: TextStyle(
                  fontSize: 10,
                  color: mine ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Aperçu d'une pièce jointe : miniature pour une image, carte pour le reste.
class _Attachment extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(ChatMessage) onOpen;
  final bool mine;

  const _Attachment({
    required this.message,
    required this.onOpen,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isImage) return _ImageAttachment(message: message, onOpen: onOpen);

    return InkWell(
      onTap: () => onOpen(message),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(minWidth: 180),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(message.kind), size: 26,
                color: mine ? Colors.white : AppColors.primaryBlue),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: mine ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (message.readableSize.isNotEmpty)
                    Text(
                      message.readableSize,
                      style: TextStyle(
                        fontSize: 10,
                        color: mine ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.download_outlined, size: 18,
                color: mine ? Colors.white70 : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String kind) {
    switch (kind) {
      case 'audio':
        return Icons.audiotrack_outlined;
      case 'video':
        return Icons.movie_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

/// Miniature d'image, chargée à la demande depuis Appwrite.
///
/// L'aperçu passe par `getFilePreview` : afficher l'original téléchargerait
/// plusieurs mégaoctets pour une vignette de 220 px. Le `FutureBuilder` garde
/// l'échec visible — un aperçu indisponible ne doit pas passer pour une image
/// vide.
class _ImageAttachment extends ConsumerWidget {
  final ChatMessage message;
  final Future<void> Function(ChatMessage) onOpen;

  const _ImageAttachment({required this.message, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(_attachmentPreviewProvider(message.fileId));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: GestureDetector(
        onTap: () => onOpen(message),
        child: preview.when(
          data: (bytes) => Image.memory(
            bytes,
            width: 220,
            fit: BoxFit.cover,
            // Une image illisible (fichier tronqué, format exotique) ne doit
            // pas faire tomber tout le fil de discussion.
            errorBuilder: (_, __, ___) => _fallback(),
          ),
          loading: () => const SizedBox(
            width: 220,
            height: 140,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        width: 220,
        height: 90,
        alignment: Alignment.center,
        color: Colors.black.withValues(alpha: 0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 24, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              message.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}

/// Aperçu d'image mis en cache par identifiant de fichier, afin qu'un
/// défilement ne redemande pas les mêmes octets.
final _attachmentPreviewProvider =
    FutureProvider.family<Uint8List, String>((ref, fileId) {
  return ref.watch(messagingRepositoryProvider).attachmentPreview(fileId);
});

/// Bandeau de la pièce jointe sélectionnée, avant envoi.
///
/// La taille est fournie par l'appelant : le sélecteur natif ne la renseigne pas
/// toujours, et la relire ici dupliquerait un accès disque déjà fait.
class _AttachmentPreview extends StatelessWidget {
  final PlatformFile file;
  final String size;
  final VoidCallback onRemove;

  const _AttachmentPreview({
    required this.file,
    required this.size,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.attach_file, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${file.name} · $size',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Retirer la pièce jointe',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool urgent;
  final bool hasAttachment;
  final VoidCallback onToggleUrgent;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.urgent,
    required this.hasAttachment,
    required this.onToggleUrgent,
    required this.onAttach,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: sending ? null : onAttach,
              icon: const Icon(Icons.attach_file, color: AppColors.primaryBlue),
              tooltip: 'Joindre un fichier',
            ),
            IconButton(
              onPressed: sending ? null : onToggleUrgent,
              icon: Icon(
                urgent ? Icons.priority_high : Icons.priority_high_outlined,
                color: urgent ? AppColors.danger : AppColors.textSecondary,
              ),
              tooltip: urgent ? 'Message urgent activé' : 'Signaler comme urgent',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: urgent ? 'Message urgent…' : 'Votre message…',
                  filled: true,
                  fillColor: urgent
                      ? AppColors.danger.withValues(alpha: 0.06)
                      : AppColors.bg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: urgent ? AppColors.danger : AppColors.teal,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: sending ? null : onSend,
                  child: Center(
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
