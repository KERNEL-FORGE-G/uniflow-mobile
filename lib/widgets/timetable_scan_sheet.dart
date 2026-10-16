import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/phosphor.dart';

class MobileTimetableScanInfo {
  final String program;
  final String level;
  final String fileId;
  final String label;
  final String? classroom;

  const MobileTimetableScanInfo({
    required this.program,
    required this.level,
    required this.fileId,
    required this.label,
    this.classroom,
  });
}

const List<MobileTimetableScanInfo> kMobileTimetableScans = [
  MobileTimetableScanInfo(
      program: 'ENR',
      level: 'L3',
      fileId: 'edt_scan_enr_l3',
      label: 'Énergies Renouvelables L3',
      classroom: 'Salle S012'),
  MobileTimetableScanInfo(
      program: 'ENR',
      level: 'L2',
      fileId: 'edt_scan_enr_l2',
      label: 'Énergies Renouvelables L2',
      classroom: 'Salle R110'),
  MobileTimetableScanInfo(
      program: 'ENR',
      level: 'L1',
      fileId: 'edt_scan_enr_l1',
      label: 'Énergies Renouvelables L1',
      classroom: 'E206 / R106'),
  MobileTimetableScanInfo(
      program: 'GEO', level: 'M1', fileId: 'edt_scan_geo_m1', label: 'Géosciences M1', classroom: 'S24B / AIII / R101'),
  MobileTimetableScanInfo(
      program: 'PHY', level: 'M1', fileId: 'edt_scan_phy_m1', label: 'Physique M1', classroom: 'AIII / S48 / R110'),
  MobileTimetableScanInfo(
      program: 'GEO', level: 'L2', fileId: 'edt_scan_geo_l2', label: 'Géosciences L2', classroom: 'A350 / A502 / R106'),
  MobileTimetableScanInfo(
      program: 'GEO', level: 'L3', fileId: 'edt_scan_geo_l3', label: 'Géosciences L3', classroom: 'A350 / A250 / R106'),
  MobileTimetableScanInfo(
      program: 'PHY', level: 'L3', fileId: 'edt_scan_phy_l3', label: 'Physique L3', classroom: 'AII / A135 / A502'),
  MobileTimetableScanInfo(
      program: 'PHY', level: 'L2', fileId: 'edt_scan_phy_l2', label: 'Physique L2', classroom: 'A1002 / A502 / A135'),
  MobileTimetableScanInfo(
      program: 'PHY', level: 'L1', fileId: 'edt_scan_phy_l1', label: 'Physique L1', classroom: 'A1001 / A1002'),
  MobileTimetableScanInfo(
      program: 'MAT',
      level: 'L2',
      fileId: 'edt_scan_mat_l2',
      label: 'Mathématiques L2',
      classroom: 'A250 / A1002 / A350'),
  MobileTimetableScanInfo(
      program: 'MAT', level: 'L3', fileId: 'edt_scan_mat_l3', label: 'Mathématiques L3', classroom: 'AI / A250 / S103'),
  MobileTimetableScanInfo(
      program: 'MAT', level: 'M1', fileId: 'edt_scan_mat_m1', label: 'Mathématiques M1', classroom: 'S102 / S110 / AI'),
  MobileTimetableScanInfo(
      program: 'MAT',
      level: 'L1',
      fileId: 'edt_scan_mat_l1',
      label: 'Mathématiques L1',
      classroom: 'A502 / A1002 / A250'),
  MobileTimetableScanInfo(
      program: 'INF',
      level: 'M1',
      fileId: 'edt_scan_inf_m1',
      label: 'Informatique M1',
      classroom: 'S005 / S006 / AIII'),
  MobileTimetableScanInfo(
      program: 'INF',
      level: 'L3',
      fileId: 'edt_scan_inf_l3',
      label: 'Informatique L3',
      classroom: 'S008 / S006 / AIII'),
  MobileTimetableScanInfo(
      program: 'INF',
      level: 'L2',
      fileId: 'edt_scan_inf_l2',
      label: 'Informatique L2',
      classroom: 'A350 / R108 / R106'),
  MobileTimetableScanInfo(
      program: 'INF',
      level: 'L1',
      fileId: 'edt_scan_inf_l1',
      label: 'Informatique L1',
      classroom: 'A1002 / A502 / A250'),
  MobileTimetableScanInfo(
      program: 'CHM', level: 'L2', fileId: 'edt_scan_chm_l2', label: 'Chimie L2', classroom: 'A502 / R108 / R106'),
  MobileTimetableScanInfo(
      program: 'CHM', level: 'L3', fileId: 'edt_scan_chm_l3', label: 'Chimie L3', classroom: 'A350 / AI / AII'),
  MobileTimetableScanInfo(
      program: 'CHM', level: 'M1', fileId: 'edt_scan_chm_m1', label: 'Chimie M1', classroom: 'R108 / AII / E206'),
  MobileTimetableScanInfo(
      program: 'CHM', level: 'L1', fileId: 'edt_scan_chm_l1', label: 'Chimie L1', classroom: 'A1001 / A502 / A1002'),
  MobileTimetableScanInfo(
      program: 'MIB',
      level: 'M1',
      fileId: 'edt_scan_mib_m1',
      label: 'Microbiologie M1',
      classroom: 'AIII / R108 / S005'),
  MobileTimetableScanInfo(
      program: 'MIB', level: 'L3', fileId: 'edt_scan_mib_l3', label: 'Microbiologie L3', classroom: 'A502 / A250 / AI'),
  MobileTimetableScanInfo(
      program: 'BOA',
      level: 'M1',
      fileId: 'edt_scan_boa_m1',
      label: 'Biologie des Organismes Animaux M1',
      classroom: 'S24B / AI / AII'),
  MobileTimetableScanInfo(
      program: 'BOV',
      level: 'L3',
      fileId: 'edt_scan_bov_l3',
      label: 'Biologie des Organismes Végétaux L3',
      classroom: 'R106 / AIII / AI'),
  MobileTimetableScanInfo(
      program: 'BOV',
      level: 'M1',
      fileId: 'edt_scan_bov_m1',
      label: 'Biologie des Organismes Végétaux M1',
      classroom: 'S58 / E206 / AIII'),
  MobileTimetableScanInfo(
      program: 'BOA',
      level: 'L3',
      fileId: 'edt_scan_boa_l3',
      label: 'Biologie des Organismes Animaux L3',
      classroom: 'R106 / A350 / A250'),
  MobileTimetableScanInfo(
      program: 'BCH', level: 'M1', fileId: 'edt_scan_bch_m1', label: 'Biochimie M1', classroom: 'R106 / E206 / R108'),
  MobileTimetableScanInfo(
      program: 'BCH', level: 'L3', fileId: 'edt_scan_bch_l3', label: 'Biochimie L3', classroom: 'P1 / P2 / AI / AII'),
  MobileTimetableScanInfo(
      program: 'BIOS',
      level: 'L2',
      fileId: 'edt_scan_bios_l2',
      label: 'Biosciences L2',
      classroom: 'A1002 / A250 / R101'),
  MobileTimetableScanInfo(
      program: 'BIOS',
      level: 'L1',
      fileId: 'edt_scan_bios_l1',
      label: 'Biosciences L1 & Géosciences L1 (Groupes)',
      classroom: 'A1001 / A1002'),
  MobileTimetableScanInfo(
      program: 'ICT4D',
      level: 'L1',
      fileId: 'edt_scan_ict4d_l1',
      label: 'ICT4D L1 (Licence Pro)',
      classroom: 'Salle R101'),
  MobileTimetableScanInfo(
      program: 'ICT4D',
      level: 'L2',
      fileId: 'edt_scan_ict4d_l2',
      label: 'ICT4D L2 (Licence Pro)',
      classroom: 'Salle S003 / S008'),
  MobileTimetableScanInfo(
      program: 'ICT4D',
      level: 'L3',
      fileId: 'edt_scan_ict4d_l3',
      label: 'ICT4D L3 (Licence Pro)',
      classroom: 'Salle S107'),
  MobileTimetableScanInfo(
      program: 'SIGL',
      level: 'M1',
      fileId: 'edt_scan_sigl_m1',
      label: 'Master SIGL M1 (Professionnel)',
      classroom: 'Salle S111'),
  MobileTimetableScanInfo(
      program: 'SIGL',
      level: 'M2',
      fileId: 'edt_scan_sigl_m2',
      label: 'Master SIGL M2 (Professionnel)',
      classroom: 'Salle S105'),
];

class MobileTimetableScanSheet extends StatefulWidget {
  final String? initialProgram;
  final String? initialLevel;

  const MobileTimetableScanSheet({
    super.key,
    this.initialProgram,
    this.initialLevel,
  });

  static void show(BuildContext context, {String? program, String? level}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileTimetableScanSheet(
        initialProgram: program,
        initialLevel: level,
      ),
    );
  }

  @override
  State<MobileTimetableScanSheet> createState() => _MobileTimetableScanSheetState();
}

class _MobileTimetableScanSheetState extends State<MobileTimetableScanSheet> {
  late MobileTimetableScanInfo _selected;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    final p = (widget.initialProgram ?? '').toUpperCase();
    final l = (widget.initialLevel ?? '').toUpperCase();
    _selected = kMobileTimetableScans.firstWhere(
      (s) => s.program == p && s.level == l,
      orElse: () => kMobileTimetableScans.first,
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isICT4D = (widget.initialProgram ?? '').toUpperCase() == 'ICT4D';
    final imageUrl =
        'https://vps.kernelforge.codes/v1/storage/buckets/uniflow_academic/files/${_selected.fileId}/view?project=uniflow';

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Affichage Officiel — Faculté UY1',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _selected.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MobileTimetableScanInfo>(
                      value: _selected,
                      isDense: true,
                      items: kMobileTimetableScans.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.program} ${s.level}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selected = val;
                            _transformController.value = Matrix4.identity();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          if (isICT4D)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Licence ICT4D : les cours sont intégrés directement dans l\'appli. Feuilles ci-dessous : scans Faculté.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Viewer
          Expanded(
            child: Container(
              color: const Color(0xFF0F172A),
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 4.5,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryBlue,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/emplois_du_temps/${_selected.fileId}.jpg',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_outlined, size: 40, color: Colors.white54),
                                SizedBox(height: 8),
                                Text(
                                  'Document en cours de synchronisation',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.inputBorder)),
            ),
            child: Row(
              children: [
                if (_selected.classroom != null) ...[
                  const PhosphorIcon(PhosphorIconsDuotone.door, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _selected.classroom!,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
                const Spacer(),
                const Text(
                  'Pincez pour zoomer',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
