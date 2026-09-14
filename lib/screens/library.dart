import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../repositories/academic_repository.dart';
import '../models/appwrite_models.dart';

final libraryListProvider = FutureProvider<List<AcademicLibraryEntry>>((ref) async {
  return ref.read(academicRepositoryProvider).getLibrary();
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryListProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Bibliothèque', subtitle: 'Ressources et supports de cours'),
          Expanded(
            child: libraryAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyState(
                    icon: Icons.library_books_outlined,
                    title: 'Aucune ressource disponible',
                    message: 'Les supports déposés par vos enseignants apparaîtront ici.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    IconData fileIcon;
                    switch (entry.type.toLowerCase()) {
                      case 'pdf': fileIcon = Icons.picture_as_pdf_outlined; break;
                      case 'video': fileIcon = Icons.video_file_outlined; break;
                      case 'image': fileIcon = Icons.image_outlined; break;
                      default: fileIcon = Icons.insert_drive_file_outlined;
                    }

                    return SectionCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(fileIcon, color: AppColors.teal),
                        ),
                        title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${entry.course} • ${entry.size ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () {
                            // TODO: Implement download from Appwrite Storage
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement bientôt disponible')));
                          },
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingView(),
              error: (err, stack) => Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(message: 'Chargement impossible.\n$err')),
            ),
          ),
        ],
      ),
    );
  }
}
