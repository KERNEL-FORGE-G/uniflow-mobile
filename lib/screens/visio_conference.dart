import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/providers.dart';
import '../services/local_visio_server.dart';
import '../theme/app_theme.dart';
import '../widgets/phosphor.dart';

/// Statut de présence LMD d'un participant dans la séance
enum VisioAttendance {
  present100,
  present94,
  present88,
  late,
}

extension VisioAttendanceExt on VisioAttendance {
  String get label => switch (this) {
        VisioAttendance.present100 => 'PRÉSENT (Auto 100%)',
        VisioAttendance.present94 => 'PRÉSENT (Auto 94%)',
        VisioAttendance.present88 => 'PRÉSENT (Auto 88%)',
        VisioAttendance.late => 'EN RETARD (10 min)',
      };

  Color get color => switch (this) {
        VisioAttendance.present100 || VisioAttendance.present94 || VisioAttendance.present88 =>
          const Color(0xFF10B981),
        VisioAttendance.late => const Color(0xFFF59E0B),
      };
}

/// Modèle d'un participant connecté à la visioconférence embarquée
class VisioParticipant {
  final String id;
  final String name;
  final String matricule;
  final String role;
  final String initials;
  final bool micOn;
  final bool camOn;
  final bool handRaised;
  final bool isSpeaking;
  final VisioAttendance attendance;
  final String joinedAt;

  const VisioParticipant({
    required this.id,
    required this.name,
    required this.matricule,
    required this.role,
    required this.initials,
    required this.micOn,
    required this.camOn,
    this.handRaised = false,
    this.isSpeaking = false,
    required this.attendance,
    required this.joinedAt,
  });

  VisioParticipant copyWith({
    bool? micOn,
    bool? camOn,
    bool? handRaised,
    bool? isSpeaking,
  }) {
    return VisioParticipant(
      id: id,
      name: name,
      matricule: matricule,
      role: role,
      initials: initials,
      micOn: micOn ?? this.micOn,
      camOn: camOn ?? this.camOn,
      handRaised: handRaised ?? this.handRaised,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      attendance: attendance,
      joinedAt: joinedAt,
    );
  }
}

/// Message du chat de cours
class VisioMessage {
  final String id;
  final String sender;
  final String role;
  final String text;
  final String time;
  final bool isMe;

  const VisioMessage({
    required this.id,
    required this.sender,
    required this.role,
    required this.text,
    required this.time,
    this.isMe = false,
  });
}

/// Sondage interactif de cours
class VisioPoll {
  final String question;
  final List<String> options;
  final List<int> votes;
  final int? userVote;

  const VisioPoll({
    required this.question,
    required this.options,
    required this.votes,
    this.userVote,
  });

  int get totalVotes => votes.fold(0, (a, b) => a + b);

  VisioPoll copyWith({int? userVote, List<int>? votes}) {
    return VisioPoll(
      question: question,
      options: options,
      votes: votes ?? this.votes,
      userVote: userVote ?? this.userVote,
    );
  }
}

/// Écran de Visioconférence Embarquée Zéro-Config
///
/// Intègre directement la scène vidéo de l'amphithéâtre / orateur, la grille
/// des étudiants connectés, la présence LMD certifiée, le chat en direct,
/// les documents et les sondages instantanés sans aucun logiciel externe.
class VisioConferenceScreen extends ConsumerStatefulWidget {
  const VisioConferenceScreen({super.key});

  @override
  ConsumerState<VisioConferenceScreen> createState() => _VisioConferenceScreenState();
}

class _VisioConferenceScreenState extends ConsumerState<VisioConferenceScreen> {
  bool _micOn = true;
  bool _camOn = true;
  bool _screenShare = false;
  bool _handRaised = false;
  int _activeSideTab = 0; // 0: Chat, 1: Participants, 2: Documents, 3: Sondages
  final _messageController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  // Métadonnées de session Meet & Synchronisation Desktop <-> Android
  String _roomId = 'ICT313_AMPHI502_2026';
  String _courseTitle = 'ICT313 · Architecture des Ordinateurs & Systèmes';
  String _roomSubtitle = 'Amphi 502 · Relais Campus LAN 0 ms · Présence LMD active';
  bool _isCompanionMode = false;
  String? _syncedDesktopName;

  late List<VisioParticipant> _participants;
  late List<VisioMessage> _messages;
  late VisioPoll _poll;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(localVisioServerProvider.notifier).startServer(
            roomId: _roomId,
            roomTitle: _courseTitle,
          );
    });
    _participants = [
      const VisioParticipant(
        id: 'p1',
        name: 'Pr. Jean-Paul Ndiaye',
        matricule: 'ENS-UY1-014',
        role: 'ENSEIGNANT',
        initials: 'JN',
        micOn: true,
        camOn: true,
        isSpeaking: true,
        attendance: VisioAttendance.present100,
        joinedAt: '07:58',
      ),
      const VisioParticipant(
        id: 'p2',
        name: 'Ravel Nghomsi',
        matricule: '22U2418',
        role: 'DÉLÉGUÉ',
        initials: 'RN',
        micOn: true,
        camOn: true,
        attendance: VisioAttendance.present100,
        joinedAt: '08:00',
      ),
      const VisioParticipant(
        id: 'p3',
        name: 'Aïcha Bello',
        matricule: '22U2094',
        role: 'ÉTUDIANT',
        initials: 'AB',
        micOn: false,
        camOn: true,
        handRaised: true,
        attendance: VisioAttendance.present94,
        joinedAt: '08:02',
      ),
      const VisioParticipant(
        id: 'p4',
        name: 'Franck Kamga',
        matricule: '22U2110',
        role: 'ÉTUDIANT',
        initials: 'FK',
        micOn: false,
        camOn: false,
        attendance: VisioAttendance.present88,
        joinedAt: '08:05',
      ),
      const VisioParticipant(
        id: 'p5',
        name: 'Mireille Ngo Batoum',
        matricule: '22U2890',
        role: 'ÉTUDIANT',
        initials: 'MN',
        micOn: false,
        camOn: true,
        attendance: VisioAttendance.late,
        joinedAt: '08:14',
      ),
    ];

    _messages = [
      const VisioMessage(
        id: 'm1',
        sender: 'Pr. Jean-Paul Ndiaye',
        role: 'ENSEIGNANT',
        text: 'Bonjour à tous, bienvenue dans ce cours magistral. Nous abordons les architectures distribuées.',
        time: '08:01',
      ),
      const VisioMessage(
        id: 'm2',
        sender: 'Ravel Nghomsi',
        role: 'DÉLÉGUÉ',
        text: 'Bonjour Monsieur. Tous les groupes de TD ICT4D L3 sont connectés sur le relais LAN Campus.',
        time: '08:02',
      ),
      const VisioMessage(
        id: 'm3',
        sender: 'Aïcha Bello',
        role: 'ÉTUDIANT',
        text: 'Est-ce que le support PDF du chapitre 4 est déjà téléchargeable dans l\'onglet Documents ?',
        time: '08:04',
      ),
      const VisioMessage(
        id: 'm4',
        sender: 'Pr. Jean-Paul Ndiaye',
        role: 'ENSEIGNANT',
        text: 'Oui Aïcha, le support complet y est mis à disposition avec synchronisation hors-ligne.',
        time: '08:05',
      ),
    ];

    _poll = const VisioPoll(
      question: 'Avez-vous assimilé le principe du consensus RAFT dans les bases distribuées ?',
      options: [
        'Parfaitement assimilé',
        'Compris les grandes lignes',
        'Besoin d\'un exercice guidé',
      ],
      votes: [18, 12, 5],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(VisioMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: user?.name.isNotEmpty == true ? user!.name : 'Moi',
        role: 'ÉTUDIANT',
        text: text,
        time: timeStr,
        isMe: true,
      ));
      _messageController.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _vote(int optionIndex) {
    if (_poll.userVote != null) return;
    setState(() {
      final newVotes = List<int>.from(_poll.votes);
      newVotes[optionIndex] += 1;
      _poll = _poll.copyWith(userVote: optionIndex, votes: newVotes);
    });
  }

  void _showMeetQrDialog() {
    final serverState = ref.read(localVisioServerProvider);
    final lanUrl = serverState.lanUrl;
    final webUrl = serverState.webFallbackUrl;

    int selectedTab = 0;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final activeUrl = selectedTab == 0 ? lanUrl : (selectedTab == 1 ? webUrl : lanUrl);
            final activeTitle = selectedTab == 0
                ? 'Accès Invité LAN (Sans Internet 0 ms)'
                : (selectedTab == 1 ? 'Accès Web Public (Internet)' : 'Couplage App Android');

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const PhosphorIcon(PhosphorIconsBold.broadcast, color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Partager la Visioconférence',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Optimisé pour les invités sans application',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sélecteur d'onglets
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => selectedTab = 0),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: selectedTab == 0 ? AppColors.cardWhite : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: selectedTab == 0
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '⚡ LAN Wi-Fi',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: selectedTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                      color: selectedTab == 0 ? AppColors.primaryBlue : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => selectedTab = 1),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: selectedTab == 1 ? AppColors.cardWhite : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: selectedTab == 1
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '🌐 Web Internet',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: selectedTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                      color: selectedTab == 1 ? AppColors.primaryBlue : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => selectedTab = 2),
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: selectedTab == 2 ? AppColors.cardWhite : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: selectedTab == 2
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '📱 App Android',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: selectedTab == 2 ? FontWeight.w800 : FontWeight.w600,
                                      color: selectedTab == 2 ? AppColors.primaryBlue : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      selectedTab == 0
                          ? 'Les participants connectés au même Wi-Fi/LAN ouvrent ce lien dans leur navigateur (Chrome, Safari, Firefox). Aucune application à installer !'
                          : (selectedTab == 1
                              ? 'Pour les participants distants disposant d\'un accès Internet général sur le portail Web UniFlow.'
                              : 'Scannez ce QR avec l\'application mobile UniFlow pour coupler la caméra HD sans fil.'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: 190,
                        height: 190,
                        child: QrImageView(
                          data: activeUrl,
                          version: QrVersions.auto,
                          size: 190,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primaryBlue),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Lien cliquable / copiable
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            selectedTab == 0 ? PhosphorIconsBold.broadcast : PhosphorIconsBold.globe,
                            size: 16,
                            color: selectedTab == 0 ? const Color(0xFF10B981) : AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeUrl,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const PhosphorIcon(PhosphorIconsBold.clipboardText, size: 16, color: AppColors.primaryBlue),
                            tooltip: 'Copier le lien',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: activeUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lien $activeTitle copié dans le presse-papier !'),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openMeetQrScanner() async {
    final scannedData = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => const _MeetQrScannerView(),
      ),
    );

    if (scannedData != null && scannedData.isNotEmpty) {
      _handleScannedMeetCode(scannedData);
    }
  }

  void _handleScannedMeetCode(String code) {
    String scannedRoomId = _roomId;
    String scannedTitle = _courseTitle;
    String scannedSubtitle = _roomSubtitle;
    String host = 'Desktop Hôte';

    try {
      if (code.startsWith('{') && code.endsWith('}')) {
        final Map<String, dynamic> data = jsonDecode(code) as Map<String, dynamic>;
        if (data['roomId'] != null) scannedRoomId = data['roomId'].toString();
        if (data['title'] != null) scannedTitle = data['title'].toString();
        if (data['location'] != null) scannedSubtitle = data['location'].toString();
        if (data['host'] != null) host = data['host'].toString();
      } else if (code.contains('meet:')) {
        scannedRoomId = code.replaceFirst('meet:', '').trim();
      }
    } catch (_) {}

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const PhosphorIcon(PhosphorIconsFill.checkCircle, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QR Meet détecté avec succès !',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            scannedTitle,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _activateCompanionMode(scannedRoomId, scannedTitle, scannedSubtitle, host);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const PhosphorIcon(PhosphorIconsFill.deviceMobile, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mode Caméra & Micro Déporté (Recommandé)',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.teal),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Utilise cet appareil Android comme source vidéo HD et audio sans fil pour la réunion sur le Desktop.',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _joinAsParticipant(scannedRoomId, scannedTitle, scannedSubtitle);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const PhosphorIcon(PhosphorIconsFill.usersThree, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rejoindre en tant que Participant',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Accéder à la visio, au chat, aux documents et voter aux sondages directement sur ce smartphone.',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _activateCompanionMode(String roomId, String title, String subtitle, String host) {
    setState(() {
      _roomId = roomId;
      _courseTitle = title;
      _roomSubtitle = subtitle;
      _isCompanionMode = true;
      _syncedDesktopName = host;
      _messages.add(VisioMessage(
        id: 'msg_sync_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'Système UniFlow',
        role: 'RELAY LAN',
        text: '📱 Point de réception Android actif : Couplé à [$host] en caméra et micro déporté 0 ms.',
        time: 'Direct',
        isMe: false,
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📱 Couplé avec succès au Desktop ($host) en caméra/micro sans fil !'),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _joinAsParticipant(String roomId, String title, String subtitle) {
    final user = ref.read(currentUserProvider);
    setState(() {
      _roomId = roomId;
      _courseTitle = title;
      _roomSubtitle = subtitle;
      _isCompanionMode = false;
      _syncedDesktopName = 'Connecté via QR';
      _messages.add(VisioMessage(
        id: 'msg_join_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'Système UniFlow',
        role: 'SÉCURITÉ',
        text: '✅ ${user?.name ?? 'Vous'} a rejoint la session $roomId via QR Code Desktop.',
        time: 'Direct',
        isMe: false,
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Connecté au cours : $title !'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Barre supérieure de séance
            _buildTopSessionBar(isDesktop),
            // Contenu principal : Scène vidéo + Panneau latéral
            Expanded(
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Scène vidéo principale (gauche)
                        Expanded(
                          flex: 7,
                          child: _buildVideoStage(),
                        ),
                        // Panneau latéral intégré (droite)
                        SizedBox(
                          width: 380,
                          child: _buildSidePanel(),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Scène vidéo mobile
                        Expanded(
                          flex: 4,
                          child: _buildVideoStage(),
                        ),
                        // Onglets et panneau inférieur mobile
                        Expanded(
                          flex: 5,
                          child: _buildSidePanel(),
                        ),
                      ],
                    ),
            ),
            // Barre inférieure des commandes médias
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSessionBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 10, vertical: isDesktop ? 12 : 8),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isDesktop ? 'EN DIRECT' : 'DIRECT',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _courseTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _roomSubtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Bouton Générer/Afficher QR Meet
          IconButton(
            tooltip: 'Afficher le QR code du salon Meet',
            onPressed: _showMeetQrDialog,
            icon: const PhosphorIcon(PhosphorIconsBold.qrCode, size: 18, color: AppColors.primaryBlue),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 4),
          // Bouton Scanner QR Meet (Point de réception pour Android)
          IconButton(
            tooltip: 'Scanner le QR Meet d\'un Desktop',
            onPressed: _openMeetQrScanner,
            icon: const PhosphorIcon(PhosphorIconsBold.scan, size: 18, color: Color(0xFF0D9488)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 6),
            // Badge Relais Local LAN / Serveur embarqué
            Consumer(
              builder: (context, ref, _) {
                final srv = ref.watch(localVisioServerProvider);
                return InkWell(
                  onTap: _showMeetQrDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: srv.isRunning
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: srv.isRunning
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          srv.isRunning ? PhosphorIconsFill.broadcast : PhosphorIconsDuotone.broadcast,
                          size: 14,
                          color: srv.isRunning ? const Color(0xFF10B981) : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          srv.isRunning ? 'Relais LAN 0ms :${srv.port}' : 'LAN OFF',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: srv.isRunning ? const Color(0xFF059669) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PhosphorIcon(PhosphorIconsFill.usersThree, size: 12, color: AppColors.primaryBlue),
                const SizedBox(width: 3),
                Text(
                  isDesktop ? '${_participants.length} en ligne' : '${_participants.length}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoStage() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTall = constraints.maxHeight >= 260;
            return Stack(
              children: [
                // Scène orateur principale
                Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isTall ? 70 : 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: isTall ? 80 : 54,
                            height: isTall ? 80 : 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF60A5FA), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'JN',
                                style: TextStyle(
                                  fontSize: isTall ? 28 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pr. Jean-Paul Ndiaye',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(PhosphorIconsFill.waveform, size: 12, color: Color(0xFF34D399)),
                                SizedBox(width: 4),
                                Text(
                                  'Prend la parole · Audio HD',
                                  style: TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Vignettes des participants en bas de la scène vidéo (si assez d'espace)
                if (isTall)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _participants.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final p = _participants[index];
                          return Container(
                            width: 95,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: p.isSpeaking ? const Color(0xFF34D399) : Colors.white24,
                                width: p.isSpeaking ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: p.role == 'ENSEIGNANT'
                                      ? AppColors.primaryBlue
                                      : p.role == 'DÉLÉGUÉ'
                                          ? AppColors.teal
                                          : const Color(0xFF64748B),
                                  child: Text(
                                    p.initials,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder, width: 1),
      ),
      child: Column(
        children: [
          // En-tête des onglets
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.inputBorder, width: 1)),
            ),
            child: Row(
              children: [
                _buildTabButton(0, 'Chat', PhosphorIconsDuotone.chatCircleDots),
                _buildTabButton(1, 'Présences', PhosphorIconsDuotone.checkCircle),
                _buildTabButton(2, 'Supports', PhosphorIconsDuotone.fileText),
                _buildTabButton(3, 'Quiz', PhosphorIconsDuotone.chartBar),
              ],
            ),
          ),
          // Corps de l'onglet actif
          Expanded(
            child: switch (_activeSideTab) {
              0 => _buildChatView(),
              1 => _buildParticipantsView(),
              2 => _buildDocumentsView(),
              _ => _buildPollsView(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, PhosphorIconData icon) {
    final active = _activeSideTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeSideTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary50 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                icon,
                size: 18,
                color: active ? AppColors.primaryBlue : AppColors.textSecondary,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primaryBlue : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _chatScroll,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final msg = _messages[i];
              return Align(
                alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: msg.isMe ? AppColors.primaryBlue : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: msg.isMe ? AppColors.primaryBlue : AppColors.inputBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              msg.sender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: msg.isMe ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            msg.time,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: msg.isMe ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: msg.isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            border: Border(top: BorderSide(color: AppColors.inputBorder, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Poser une question en direct…',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const PhosphorIcon(PhosphorIconsFill.paperPlaneRight, color: AppColors.primaryBlue),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsView() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _participants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = _participants[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryBlue,
                child: Text(
                  p.initials,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${p.matricule} · ${p.role}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: p.attendance.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.attendance.label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: p.attendance.color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentsView() {
    final docs = [
      ('Chapitre_4_Architectures_Distribuees.pdf', '3.8 Mo · Pr. Ndiaye', PhosphorIconsDuotone.filePdf),
      ('Travaux_Pratiques_3_Consensus_RAFT.pdf', '1.2 Mo · Département Info', PhosphorIconsDuotone.filePdf),
      ('Schema_Reseau_Campus_UY1.png', '840 Ko · Infrastructure', PhosphorIconsDuotone.fileImage),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final d = docs[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            children: [
              PhosphorIcon(d.$3, size: 28, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.$1,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      d.$2,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const PhosphorIcon(PhosphorIconsDuotone.downloadSimple, size: 20, color: AppColors.teal),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Support téléchargé pour consultation hors-ligne : ${d.$1}')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPollsView() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              PhosphorIcon(PhosphorIconsDuotone.sparkle, size: 18, color: AppColors.amber),
              SizedBox(width: 6),
              Text(
                'Sondage instantané de cours',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _poll.question,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _poll.options.length; i++) ...[
            InkWell(
              onTap: () => _vote(i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _poll.userVote == i ? AppColors.primary50 : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _poll.userVote == i ? AppColors.primaryBlue : AppColors.inputBorder,
                    width: _poll.userVote == i ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _poll.options[i],
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _poll.userVote == i ? FontWeight.w700 : FontWeight.w500,
                          color: _poll.userVote == i ? AppColors.primaryBlue : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${_poll.votes[i]} votes',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Total : ${_poll.totalVotes} réponses d\'étudiants enregistrées',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.inputBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bouton Micro
            _buildControlButton(
              icon: _micOn ? PhosphorIconsFill.microphone : PhosphorIconsFill.microphoneSlash,
              label: _micOn ? 'Micro ON' : 'Micro OFF',
              color: _micOn ? AppColors.primaryBlue : const Color(0xFFEF4444),
              active: _micOn,
              onTap: () => setState(() => _micOn = !_micOn),
            ),
            const SizedBox(width: 8),
            // Bouton Caméra
            _buildControlButton(
              icon: _camOn ? PhosphorIconsFill.videoCamera : PhosphorIconsFill.videoCameraSlash,
              label: _camOn ? 'Caméra ON' : 'Caméra OFF',
              color: _camOn ? AppColors.primaryBlue : const Color(0xFFEF4444),
              active: _camOn,
              onTap: () => setState(() => _camOn = !_camOn),
            ),
            const SizedBox(width: 8),
            // Bouton Lever la main
            _buildControlButton(
              icon: PhosphorIconsFill.hand,
              label: _handRaised ? 'Main levée' : 'Lever main',
              color: _handRaised ? const Color(0xFFF59E0B) : AppColors.textSecondary,
              active: _handRaised,
              onTap: () => setState(() => _handRaised = !_handRaised),
            ),
            const SizedBox(width: 8),
            // Bouton Partager l'écran
            _buildControlButton(
              icon: PhosphorIconsFill.screencast,
              label: _screenShare ? 'Partage ON' : 'Partager',
              color: _screenShare ? AppColors.teal : AppColors.textSecondary,
              active: _screenShare,
              onTap: () => setState(() => _screenShare = !_screenShare),
            ),
            const SizedBox(width: 12),
            // Bouton Quitter
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              icon: const PhosphorIcon(PhosphorIconsFill.phoneDisconnect, size: 16, color: Colors.white),
              label: const Text('Quitter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required PhosphorIconData icon,
    required String label,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : AppColors.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vue caméra dédiée pour scanner le QR Meet projeté sur un Desktop ou écran d'amphithéâtre
class _MeetQrScannerView extends StatefulWidget {
  const _MeetQrScannerView();

  @override
  State<_MeetQrScannerView> createState() => _MeetQrScannerViewState();
}

class _MeetQrScannerViewState extends State<_MeetQrScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue?.trim();
    if (value != null && value.isNotEmpty) {
      _detected = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(value);
    }
  }

  void _enterCodeManually() {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Entrer le code du salon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ex: ICT313_AMPHI502_2026',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(text);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scanner le QR Meet Desktop', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text('Pointez vers l\'écran du PC ou du vidéoprojecteur', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Changer de caméra',
            onPressed: () => _controller.switchCamera(),
            icon: const PhosphorIcon(PhosphorIconsBold.arrowsClockwise, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Lampe torche',
            onPressed: () => _controller.toggleTorch(),
            icon: const PhosphorIcon(PhosphorIconsBold.flashlight, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhosphorIcon(PhosphorIconsBold.warningCircle, color: Colors.orange, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Caméra indisponible : ${error.errorDetails?.message ?? error.errorCode.name}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _enterCodeManually,
                      child: const Text('Saisir le code du salon manuellement'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Cadre de visée animé
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.95, end: 1.05),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _detected ? const Color(0xFF10B981) : const Color(0xFF0D9488),
                        width: 3.5,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.white, width: 3),
                                left: BorderSide(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.white, width: 3),
                                right: BorderSide(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white, width: 3),
                                left: BorderSide(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white, width: 3),
                                right: BorderSide(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Aide en bas avec bouton manuel
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Row(
                    children: [
                      PhosphorIcon(PhosphorIconsFill.info, color: Color(0xFF0D9488), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Placez le QR Code affiché sur l\'écran du Desktop au centre pour synchroniser immédiatement.',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _enterCodeManually,
                  icon: const PhosphorIcon(PhosphorIconsBold.pencilSimpleLine, color: Colors.white70, size: 16),
                  label: const Text(
                    'Entrer le code du salon manuellement',
                    style: TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline),
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

