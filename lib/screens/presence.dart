import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/phosphor.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../providers/providers.dart';
import '../repositories/attendance_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/motion.dart';
import '../widgets/uni_icons.dart';

/// Présence sécurisée par QR et proximité.
///
/// L'écran affichait « Module de présence bientôt disponible » alors que le
/// service `/attendance-secure` était en production et utilisé par le web.
/// Deux faces selon le rôle :
/// - apprenant (étudiant, délégué) : scanner le QR affiché en salle ;
/// - émetteur (délégué, enseignant, administration) : ouvrir la séance du
///   jour d'un cours de son périmètre et afficher le QR, valable quinze
///   minutes autour de sa position.
class PresenceScreen extends ConsumerWidget {
  const PresenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final canIssue = role.canIssueAttendance;
    final canScan = role.canScanAttendance;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Présence',
            subtitle: canIssue && canScan
                ? 'Émarger ou faire émarger'
                : canIssue
                    ? 'Faire émarger votre séance'
                    : 'Émarger en scannant le QR de la séance',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (canScan) const FadeSlideIn(index: 0, child: _ScanCard()),
                if (canScan && canIssue) const SizedBox(height: 14),
                if (canIssue) const FadeSlideIn(index: 1, child: _IssueCard()),
                const SizedBox(height: 14),
                const FadeSlideIn(index: 2, child: _HowItWorks()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Position
// ---------------------------------------------------------------------------

/// Position actuelle, avec les messages d'erreur que l'utilisateur peut
/// comprendre (autorisation refusée, GPS coupé, précision insuffisante).
Future<GeoPosition> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw AttendanceException(
        'La localisation est désactivée sur cet appareil. Activez-la : la présence vérifie que vous êtes bien en salle.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw AttendanceException('Autorisez la position : elle ne sert qu\'à vérifier votre proximité avec la séance.');
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
  );
  // La Function refuse une précision au-delà de 100 m : autant le dire ici,
  // avec un conseil, plutôt qu'un « Précision de localisation insuffisante ».
  final accuracy = position.accuracy <= 0 ? 50.0 : position.accuracy;
  if (accuracy > 100) {
    throw AttendanceException(
        'Position trop imprécise (± ${accuracy.round()} m). Rapprochez-vous d\'une fenêtre ou sortez du bâtiment un instant, puis réessayez.');
  }
  return GeoPosition(latitude: position.latitude, longitude: position.longitude, accuracy: accuracy);
}

// ---------------------------------------------------------------------------
// Scanner (apprenants)
// ---------------------------------------------------------------------------

class _ScanCard extends ConsumerWidget {
  const _ScanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              IconTile(icon: PhosphorIconsDuotone.scan, color: AppColors.primaryBlue, size: IconTile.dense),
              SizedBox(width: 10),
              Expanded(child: Text('Émarger', style: AppTextStyles.h3)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Scannez le QR affiché par votre délégué ou votre enseignant. Votre position n\'est utilisée que pour vérifier que vous êtes dans la salle.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Scanner le QR de la séance',
            icon: PhosphorIconsBold.scan,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _ScanPage(), fullscreenDialog: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanPage extends ConsumerStatefulWidget {
  const _ScanPage();

  @override
  ConsumerState<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<_ScanPage> {
  final _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: [BarcodeFormat.qrCode]);
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    if (decodeAttendanceQr(raw) == null) {
      setState(() => _status = 'Ce QR n\'est pas un QR de présence UniFlow.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'QR reconnu : vérification de votre position…';
    });
    await _controller.stop();
    try {
      final position = await currentPosition();
      if (mounted) setState(() => _status = 'Position obtenue (± ${position.accuracy.round()} m) : émargement…');
      final result = await ref.read(attendanceRepositoryProvider).scan(qrContent: raw, position: position);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _ResultPage(
            kind: FeedbackKind.success,
            title: result.alreadyRecorded ? 'Déjà émargé' : 'Présence enregistrée',
            message: result.message,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final detail = error is AttendanceException && error.distanceMeters != null
          ? '${error.message} (à ${error.distanceMeters} m de la séance)'
          : error.toString();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _ResultPage(kind: FeedbackKind.failure, title: 'Émargement refusé', message: detail),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner le QR'),
        actions: [
          IconButton(
            tooltip: 'Lampe',
            onPressed: () => _controller.toggleTorch(),
            icon: const PhosphorIcon(PhosphorIconsBold.flashlight),
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
                child: Text(
                  'Caméra indisponible : ${error.errorDetails?.message ?? error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          // Viseur : un cadre aux coins arrondis, qui pulse tant que rien n'est lu.
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.96, end: 1.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: _busy ? AppColors.success : AppColors.tealLight, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey(_status),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration:
                    BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    if (_busy) ...[
                      const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _status ?? 'Placez le QR dans le cadre.',
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Émission (délégué, enseignant, administration)
// ---------------------------------------------------------------------------

class _IssueCard extends ConsumerStatefulWidget {
  const _IssueCard();

  @override
  ConsumerState<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends ConsumerState<_IssueCard> {
  String? _courseId;
  int _radius = 80;
  bool _busy = false;
  String? _error;

  Future<void> _issue(AcademicCourse course) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final origin = await currentPosition();
      final qr = await ref.read(attendanceRepositoryProvider).openQrSession(
            courseId: course.id,
            origin: origin,
            radiusMeters: _radius,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _QrPage(qr: qr, course: course), fullscreenDialog: true),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(scopedCoursesProvider);
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentRoleProvider);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              IconTile(icon: PhosphorIconsDuotone.qrCode, color: AppColors.teal, size: IconTile.dense),
              SizedBox(width: 10),
              Expanded(child: Text('Faire émarger', style: AppTextStyles.h3)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Ouvre la séance du jour et affiche un QR valable quinze minutes autour de votre position.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          courses.when(
            loading: () => const ShimmerBox(height: 52),
            error: (error, _) => ErrorBanner(
                message: 'Cours indisponibles : $error', onRetry: () => ref.invalidate(scopedCoursesProvider)),
            data: (list) {
              // Un enseignant n'émet que pour ses cours ; la Function le
              // vérifie aussi (COURSE_ASSIGNMENT_DENIED), autant ne pas
              // proposer ce qui sera refusé.
              final mine = role == UniFlowRole.teacher && user != null
                  ? list.where((c) => c.teacherId == user.id).toList()
                  : list;
              if (mine.isEmpty) {
                return const Text('Aucun cours de votre périmètre ne peut recevoir une séance pour l\'instant.',
                    style: AppTextStyles.bodySmall);
              }
              final selected = mine.where((c) => c.id == _courseId).firstOrNull ?? mine.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Cours', prefixIcon: PhosphorIcon(PhosphorIconsBold.bookOpenText, size: 20)),
                    items: [
                      for (final c in mine)
                        DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.code} · ${c.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _courseId = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const PhosphorIcon(PhosphorIconsBold.mapPin, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _radius.toDouble(),
                          min: 20,
                          max: 250,
                          divisions: 23,
                          label: '$_radius m',
                          onChanged: _busy ? null : (v) => setState(() => _radius = v.round()),
                        ),
                      ),
                      SizedBox(
                          width: 52, child: Text('$_radius m', textAlign: TextAlign.end, style: AppTextStyles.label)),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
                  ],
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Générer le QR de la séance',
                    icon: PhosphorIconsBold.qrCode,
                    isLoading: _busy,
                    onPressed: _busy ? null : () => _issue(selected),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QrPage extends ConsumerStatefulWidget {
  final IssuedQr qr;
  final AcademicCourse course;

  const _QrPage({required this.qr, required this.course});

  @override
  ConsumerState<_QrPage> createState() => _QrPageState();
}

class _QrPageState extends ConsumerState<_QrPage> {
  late Timer _ticker;
  Duration _left = Duration.zero;
  bool _revoking = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final left = widget.qr.expiresAt.difference(DateTime.now());
    setState(() => _left = left.isNegative ? Duration.zero : left);
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _close() async {
    // Fermer révoque le jeton : un QR photographié ne doit pas servir après
    // la séance.
    setState(() => _revoking = true);
    try {
      await ref.read(attendanceRepositoryProvider).revoke(widget.qr.token);
    } catch (_) {
      // Le jeton expire de lui-même dans le quart d'heure.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _left == Duration.zero;
    final mm = _left.inMinutes.toString().padLeft(2, '0');
    final ss = (_left.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('QR de présence'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.course.name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(widget.course.code, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 22),
                  FadeSlideIn(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              blurRadius: 30,
                              offset: const Offset(0, 12))
                        ],
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: expired ? 0.25 : 1,
                        child: QrImageView(
                          data: widget.qr.payload,
                          size: 240,
                          version: QrVersions.auto,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primaryBlue),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square, color: AppColors.deepBlue),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(PhosphorIconsBold.timer,
                          size: 18, color: expired ? AppColors.danger : AppColors.teal),
                      const SizedBox(width: 6),
                      Text(
                        expired ? 'QR expiré' : 'Valable encore $mm:$ss',
                        style: AppTextStyles.label.copyWith(color: expired ? AppColors.danger : AppColors.teal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rayon autorisé : ${widget.qr.radiusMeters} m autour de vous. Un apprenant inscrit ne peut émarger qu\'une fois.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: expired ? 'Fermer' : 'Terminer et révoquer le QR',
                    icon: PhosphorIconsBold.lock,
                    isLoading: _revoking,
                    onPressed: _revoking ? null : _close,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Divers
// ---------------------------------------------------------------------------

class _ResultPage extends StatelessWidget {
  final FeedbackKind kind;
  final String title;
  final String message;

  const _ResultPage({required this.kind, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FeedbackView(
                kind: kind,
                title: title,
                message: message,
                actionLabel: 'Retour à la présence',
                onAction: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comment ça marche', style: AppTextStyles.h3),
          SizedBox(height: 10),
          _Step(
              n: '1',
              text: 'L\'émetteur ouvre la séance du jour depuis la salle : sa position fixe le centre de la zone.'),
          _Step(n: '2', text: 'Le QR reste valable quinze minutes ; en régénérer un révoque le précédent.'),
          _Step(
              n: '3',
              text:
                  'Chaque apprenant inscrit au cours scanne le QR depuis la zone : sa présence est enregistrée une seule fois.'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primary50, shape: BoxShape.circle),
            child: Text(n,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
