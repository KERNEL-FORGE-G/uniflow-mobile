import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/common.dart';
import '../widgets/phosphor.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../repositories/academic_repository.dart';
import '../models/appwrite_models.dart';
import '../offline/cached_providers.dart';

final libraryListProvider = FutureProvider<List<AcademicLibraryEntry>>((ref) async {
  // Cache d'abord : la première valeur émise est le cache s'il existe, le
  // réseau sinon ; l'écran se rafraîchit au prochain passage.
  final all = await cachedDocumentList<AcademicLibraryEntry>(
    ref,
    collection: 'academic_library',
    fetch: () => ref.read(academicRepositoryProvider).listAll('academic_library', const []),
    fromDocument: AcademicLibraryEntry.fromDocument,
    replace: true,
  ).first;
  // Une ressource se rattache à un cours, et le cours porte filière et niveau :
  // un L2 ne voit pas les polycopiés des L1. Les ressources sans cours (guides,
  // règlements) restent visibles de tous les comptes universitaires.
  final scope = ref.watch(academicScopeProvider);
  if (scope.nothing) return const [];
  final courses = await ref.watch(scopedCoursesProvider.future);
  final general = all.where((e) => e.courseId.isEmpty && e.course.isEmpty).toList();
  final scoped = scope.byCourse(all, courses, (e) => e.courseId, courseCodeOf: (e) => e.course);
  return [...scoped, ...general.where((g) => !scoped.contains(g))];
});

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// Ressource en cours de téléchargement, pour n'animer que sa propre ligne.
  String? _enCours;
  String? _erreur;

  /// Télécharge la ressource puis la confie au système, qui choisit
  /// l'application capable de l'ouvrir — même démarche que les pièces jointes
  /// d'une conversation.
  Future<void> _telecharger(AcademicLibraryEntry entry) async {
    final fileId = entry.fileId;
    if (fileId == null || fileId.isEmpty) {
      setState(() => _erreur = '« ${entry.title} » n\'a pas de fichier joint : cette ressource est '
          'un simple intitulé.');
      return;
    }

    setState(() {
      _enCours = entry.id;
      _erreur = null;
    });
    try {
      final bytes = await ref.read(academicRepositoryProvider).downloadLibraryFile(fileId);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${libraryFileName(entry.title, entry.id)}');
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        setState(() => _erreur = 'Aucune application ne sait ouvrir « ${entry.title} ». Le fichier a '
            'été enregistré dans ${directory.path}.');
      }
    } catch (error) {
      if (mounted) setState(() => _erreur = error.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryListProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Bibliothèque', subtitle: 'Ressources et supports de cours'),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ErrorBanner(message: _erreur!),
            ),
          Expanded(
            child: libraryAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyState(
                    icon: PhosphorIconsDuotone.books,
                    title: 'Aucune ressource disponible',
                    message: 'Les supports déposés par vos enseignants apparaîtront ici.',
                  );
                }
                return ListView.separated(
                  padding: AppInsets.pageList,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    IconData fileIcon;
                    switch (entry.type.toLowerCase()) {
                      case 'pdf':
                        fileIcon = PhosphorIconsDuotone.filePdf;
                        break;
                      case 'video':
                        fileIcon = PhosphorIconsDuotone.fileVideo;
                        break;
                      case 'image':
                        fileIcon = PhosphorIconsDuotone.image;
                        break;
                      default:
                        fileIcon = PhosphorIconsDuotone.file;
                    }

                    final enCours = _enCours == entry.id;
                    return SectionCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: PhosphorIcon(fileIcon, color: AppColors.teal),
                        ),
                        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle:
                            Text('${entry.course} • ${entry.size ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                        // Le titre porte déjà l'information ; on la répète à
                        // l'oreille pour qui navigue au lecteur d'écran, qui
                        // n'entend sinon que « bouton ».
                        trailing: IconButton(
                          tooltip: 'Ouvrir « ${entry.title} »',
                          icon: enCours
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const PhosphorIcon(PhosphorIconsBold.downloadSimple),
                          onPressed: enCours ? null : () => _telecharger(entry),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingView(),
              error: (err, stack) => LoadErrorView(
                title: 'La bibliothèque n\'a pas pu être chargée',
                error: err,
                onRetry: () => ref.invalidate(libraryListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
