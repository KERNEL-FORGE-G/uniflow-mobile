import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class PresenceScreen extends ConsumerStatefulWidget {
  const PresenceScreen({super.key});

  @override
  ConsumerState<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends ConsumerState<PresenceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _qrCodeController = TextEditingController();
  bool _isScanning = false;
  bool _isSuccess = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qrCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitQrCode(String code) async {
    if (code.trim().isEmpty) return;

    setState(() {
      _isScanning = true;
      _statusMessage = null;
      _isSuccess = false;
    });

    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.post('/attendance/scan', data: {'code': code.trim()});
      
      setState(() {
        _isScanning = false;
        _isSuccess = true;
        _statusMessage = response.data['message'] ?? 'Présence enregistrée avec succès ! 🎉';
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? 'Code QR invalide ou expiré.';
      setState(() {
        _isScanning = false;
        _isSuccess = false;
        _statusMessage = msg is List ? msg.join(', ') : msg.toString();
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _isSuccess = false;
        _statusMessage = 'Erreur de connexion au serveur.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isTeacherOrAdmin = authState.user?.role == 'ENSEIGNANT' ||
                             authState.user?.role == 'ADMIN' ||
                             authState.user?.role == 'DELEGUE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Présence & Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.textMutedLight,
          indicatorColor: AppColors.secondary,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scanner / Code QR'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Feuille d\'appel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: SCANNER / CHECK-IN QR
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isTeacherOrAdmin ? Icons.qr_code_2 : Icons.qr_code_scanner,
                        size: 100,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isTeacherOrAdmin
                            ? 'Générateur de Pass de Présence'
                            : 'Check-in Émargeur Étudiant',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isTeacherOrAdmin
                            ? 'Scannez le code QR de l\'étudiant ou entrez son code de session pour valider sa présence.'
                            : 'Scannez le code affiché par l\'enseignant ou entrez le code de séance.',
                        style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _qrCodeController,
                        decoration: InputDecoration(
                          hintText: 'Code de session ou Token QR',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppColors.secondary),
                            onPressed: () => _submitQrCode(_qrCodeController.text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isScanning ? null : () => _submitQrCode(_qrCodeController.text.isNotEmpty ? _qrCodeController.text : 'SESSION-LIVE-2026'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
                          icon: _isScanning
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.camera_alt_outlined),
                          label: Text(_isScanning ? 'Vérification...' : 'Valider Présence Immédiate'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isSuccess ? AppColors.secondary.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isSuccess ? AppColors.secondary : AppColors.danger),
                    ),
                    child: Row(
                      children: [
                        Icon(_isSuccess ? Icons.check_circle : Icons.error, color: _isSuccess ? AppColors.secondary : AppColors.danger),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _isSuccess ? AppColors.secondary : AppColors.danger,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // TAB 2: FEUILLE D'APPEL DIRECTE
          Consumer(
            builder: (context, ref, _) {
              final studentsAsync = ref.watch(studentsProvider);

              return studentsAsync.when(
                data: (paginated) {
                  if (paginated.items.isEmpty) {
                    return const Center(child: Text('Aucun étudiant dans la liste d\'appel.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: paginated.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = paginated.items[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(student.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${student.matricule} • ${student.filiere}'),
                          trailing: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'P', label: Text('P', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              ButtonSegment(value: 'A', label: Text('A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            ],
                            selected: const {'P'},
                            onSelectionChanged: (newSelection) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Statut de ${student.fullName} mis à jour (${newSelection.first})')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
              );
            },
          ),
        ],
      ),
    );
  }
}
