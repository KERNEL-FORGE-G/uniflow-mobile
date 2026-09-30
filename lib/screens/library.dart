import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/appwrite_models.dart';
import '../offline/cached_providers.dart';
import '../providers/providers.dart';
import '../repositories/academic_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/phosphor.dart';

// ─── Providers ──────────────────────────────────────────────────────────────

final libraryListProvider = FutureProvider<List<AcademicLibraryEntry>>((ref) async {
  final all = await cachedDocumentList<AcademicLibraryEntry>(
    ref,
    collection: 'academic_library',
    fetch: () => ref.read(academicRepositoryProvider).listAll('academic_library', const []),
    fromDocument: AcademicLibraryEntry.fromDocument,
    replace: true,
  ).first;
  final scope = ref.watch(academicScopeProvider);
  if (scope.nothing) return const [];
  final courses = await ref.watch(scopedCoursesProvider.future);
  final general = all.where((e) => e.courseId.isEmpty && e.course.isEmpty).toList();
  final scoped = scope.byCourse(all, courses, (e) => e.courseId, courseCodeOf: (e) => e.course);
  return [...scoped, ...general.where((g) => !scoped.contains(g))];
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Couleur d'accent selon le type de fichier.
Color _typeColor(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':   return const Color(0xFFEF4444); // rouge
    case 'video': return const Color(0xFF8B5CF6); // violet
    case 'image': return const Color(0xFF10B981); // vert
    case 'doc':
    case 'docx':  return const Color(0xFF3B82F6); // bleu
    case 'ppt':
    case 'pptx':  return const Color(0xFFF59E0B); // ambre
    default:      return const Color(0xFF6B7280); // gris
  }
}

IconData _typeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':   return PhosphorIconsDuotone.filePdf;
    case 'video': return PhosphorIconsDuotone.fileVideo;
    case 'image': return PhosphorIconsDuotone.image;
    case 'doc':
    case 'docx':  return PhosphorIconsDuotone.fileDoc;
    case 'ppt':
    case 'pptx':  return PhosphorIconsDuotone.filePpt;
    default:      return PhosphorIconsDuotone.file;
  }
}

String _typeLabel(String type) => type.isEmpty ? 'Fichier' : type.toUpperCase();

// ─── Screen ──────────────────────────────────────────────────────────────────

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  String? _enCours;
  String? _erreur;
  String _searchQuery = '';
  String? _selectedCategory;
  late final AnimationController _headerAnim;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  Future<void> _telecharger(AcademicLibraryEntry entry) async {
    final fileId = entry.fileId;
    if (fileId == null || fileId.isEmpty) {
      setState(() => _erreur = '« ${entry.title} » n\'a pas de fichier joint.');
      return;
    }
    setState(() { _enCours = entry.id; _erreur = null; });
    try {
      final bytes = await ref.read(academicRepositoryProvider).downloadLibraryFile(fileId);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${libraryFileName(entry.title, entry.id)}');
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        setState(() => _erreur = 'Aucune application ne sait ouvrir « ${entry.title} ».');
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
      backgroundColor: const Color(0xFF0A0A14),
      body: libraryAsync.when(
        data: (entries) => _buildContent(entries),
        loading: () => const LoadingView(),
        error: (err, _) => LoadErrorView(
          title: 'La bibliothèque n\'a pas pu être chargée',
          error: err,
          onRetry: () => ref.invalidate(libraryListProvider),
        ),
      ),
    );
  }

  Widget _buildContent(List<AcademicLibraryEntry> entries) {
    // Catégories uniques
    final categories = ['Tous', ...{...entries.map((e) => e.category).where((c) => c.isNotEmpty)}];
    _selectedCategory ??= 'Tous';

    // Filtrage
    final filtered = entries.where((e) {
      final matchSearch = _searchQuery.isEmpty ||
          e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.course.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCat = _selectedCategory == 'Tous' || e.category == _selectedCategory;
      return matchSearch && matchCat;
    }).toList();

    // Grouper par cours
    final grouped = <String, List<AcademicLibraryEntry>>{};
    for (final e in filtered) {
      final key = e.course.isEmpty ? 'Général' : e.course;
      (grouped[key] ??= []).add(e);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(),
        _buildSearchBar(),
        if (categories.length > 1) _buildCategoryChips(categories),
        if (_erreur != null) _buildErrorBanner(),
        if (filtered.isEmpty)
          _buildEmptyState()
        else
          ..._buildGroupedList(grouped),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  // ── Header animé ───────────────────────────────────────────────────────────

  Widget _buildSliverHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF0A0A14)],
          ),
        ),
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
        child: FadeTransition(
          opacity: _headerAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(PhosphorIconsBold.books, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Bibliothèque',
                          style: TextStyle(color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      Text('Ressources & supports de cours',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Barre de recherche ────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2D2D4E)),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(PhosphorIconsBold.magnifyingGlass,
                    color: Color(0xFF6B7280), size: 18),
              ),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un document…',
                    hintStyle: TextStyle(color: Color(0xFF4B5563), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _searchQuery = ''),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(PhosphorIconsBold.x, color: Color(0xFF6B7280), size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chips catégories ──────────────────────────────────────────────────────

  Widget _buildCategoryChips(List<String> cats) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final selected = _selectedCategory == cats[i];
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cats[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)])
                      : null,
                  color: selected ? null : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? Colors.transparent : const Color(0xFF2D2D4E),
                  ),
                ),
                child: Text(cats[i],
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF9CA3AF),
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: ErrorBanner(message: _erreur!),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SliverFillRemaining(
      child: EmptyState(
        icon: PhosphorIconsDuotone.books,
        title: 'Aucune ressource',
        message: 'Les supports déposés par vos enseignants apparaîtront ici.',
      ),
    );
  }

  // ── Liste groupée ─────────────────────────────────────────────────────────

  List<Widget> _buildGroupedList(Map<String, List<AcademicLibraryEntry>> grouped) {
    return grouped.entries.expand((entry) {
      return <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(entry.key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${entry.value.length}',
                    style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11)),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LibraryCard(
                  entry: entry.value[i],
                  isDownloading: _enCours == entry.value[i].id,
                  onDownload: () => _telecharger(entry.value[i]),
                  index: i,
                ),
              ),
              childCount: entry.value.length,
            ),
          ),
        ),
      ];
    }).toList();
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _LibraryCard extends StatefulWidget {
  final AcademicLibraryEntry entry;
  final bool isDownloading;
  final VoidCallback onDownload;
  final int index;

  const _LibraryCard({
    required this.entry,
    required this.isDownloading,
    required this.onDownload,
    required this.index,
  });

  @override
  State<_LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<_LibraryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + widget.index * 50),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 60), _anim.forward);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _typeColor(widget.entry.type);
    final icon = _typeIcon(widget.entry.type);
    final label = _typeLabel(widget.entry.type);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13132B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2D2D4E)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.isDownloading ? null : widget.onDownload,
              splashColor: accent.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Icône type
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withValues(alpha: 0.25)),
                      ),
                      child: Stack(
                        children: [
                          Center(child: PhosphorIcon(icon, color: accent, size: 24)),
                          Positioned(
                            bottom: 2, right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(label,
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  )),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Infos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.entry.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              )),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (widget.entry.course.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(widget.entry.course,
                                      style: const TextStyle(
                                        color: Color(0xFF93C5FD),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      )),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (widget.entry.size != null)
                                Text(widget.entry.size!,
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 11,
                                    )),
                            ],
                          ),
                          if (widget.entry.description != null &&
                              widget.entry.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(widget.entry.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 11.5,
                                )),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton téléchargement
                    _DownloadButton(
                      isDownloading: widget.isDownloading,
                      accent: accent,
                      onTap: widget.isDownloading ? null : widget.onDownload,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final bool isDownloading;
  final Color accent;
  final VoidCallback? onTap;

  const _DownloadButton({
    required this.isDownloading,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isDownloading
              ? const Color(0xFF1A1A2E)
              : accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDownloading ? const Color(0xFF2D2D4E) : accent.withValues(alpha: 0.3),
          ),
        ),
        child: isDownloading
            ? Padding(
                padding: const EdgeInsets.all(9),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              )
            : Icon(PhosphorIconsBold.downloadSimple, color: accent, size: 18),
      ),
    );
  }
}
