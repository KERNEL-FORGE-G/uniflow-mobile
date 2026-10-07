import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/appwrite_models.dart';
import '../offline/cached_providers.dart';
import '../providers/appwrite_provider.dart';
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
    case 'pdf':
      return const Color(0xFFEF4444); // rouge
    case 'video':
      return const Color(0xFF8B5CF6); // violet
    case 'image':
      return const Color(0xFF10B981); // vert
    case 'doc':
    case 'docx':
      return const Color(0xFF3B82F6); // bleu
    case 'ppt':
    case 'pptx':
      return const Color(0xFFF59E0B); // ambre
    default:
      return const Color(0xFF6B7280); // gris
  }
}

IconData _typeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':
      return PhosphorIconsDuotone.filePdf;
    case 'video':
      return PhosphorIconsDuotone.fileVideo;
    case 'image':
      return PhosphorIconsDuotone.image;
    case 'doc':
    case 'docx':
      return PhosphorIconsDuotone.fileDoc;
    case 'ppt':
    case 'pptx':
      return PhosphorIconsDuotone.filePpt;
    default:
      return PhosphorIconsDuotone.file;
  }
}

String _typeLabel(String type) => type.isEmpty ? 'Fichier' : type.toUpperCase();

// ─── Modèle Uni Book ──────────────────────────────────────────────────────────

class UniBookItem {
  final String id;
  final String title;
  final List<String> authors;
  final String category;
  final String? coverUrl;
  final String? downloadUrl;
  final String format;
  final String source;
  final int? year;
  final String? description;
  final int downloadsCount;

  const UniBookItem({
    required this.id,
    required this.title,
    required this.authors,
    required this.category,
    this.coverUrl,
    this.downloadUrl,
    this.format = 'PDF',
    this.source = 'Uni Book',
    this.year,
    this.description,
    this.downloadsCount = 100,
  });

  factory UniBookItem.fromJson(Map<String, dynamic> json) {
    return UniBookItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Livre').toString(),
      authors: (json['authors'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      category: (json['category'] ?? 'Général').toString(),
      coverUrl: json['coverUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      format: (json['format'] ?? 'PDF').toString(),
      source: (json['source'] ?? 'Uni Book').toString(),
      year: json['year'] is int ? json['year'] as int : null,
      description: json['description'] as String?,
      downloadsCount: (json['downloadsCount'] as num?)?.toInt() ?? 100,
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  String? _enCours;
  String? _erreur;
  String _searchQuery = '';
  String? _selectedCategory;
  late final AnimationController _headerAnim;

  // Mode Uni Book
  int _selectedMode = 0; // 0 = Supports de cours, 1 = Uni Book
  List<UniBookItem> _uniBookResults = [];
  bool _isLoadingUniBook = false;
  String _uniBookQuery = '';
  String _selectedUniBookCategory = 'Tous';

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _searchUniBook(query: 'sciences');
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  Future<void> _searchUniBook({String? query, String? category}) async {
    final q = (query ?? _uniBookQuery).trim();
    final cat = category ?? _selectedUniBookCategory;
    setState(() {
      _isLoadingUniBook = true;
      _erreur = null;
    });
    try {
      Map<String, dynamic>? res;
      try {
        res = await ref.read(appwriteServiceProvider).callService('/open-library', {
          'action': 'search',
          'query': q,
          'category': cat,
          'limit': 35,
        });
      } catch (_) {
        res = null;
      }

      // Le web UniFlow retransmet l'API book si le BaaS local/cloud tarde ou échoue
      if (res == null || res['ok'] != true) {
        try {
          final client = HttpClient();
          final uri = Uri.parse('https://uniflow.kernelforge.codes/api/books').replace(queryParameters: {
            'q': q,
            'category': cat,
            'limit': '35',
          });
          final req = await client.getUrl(uri).timeout(const Duration(seconds: 6));
          final resp = await req.close().timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200) {
            final body = await resp.transform(utf8.decoder).join();
            res = jsonDecode(body) as Map<String, dynamic>;
          }
        } catch (_) {}
      }

      if (res != null && res['ok'] == true && res['results'] is List) {
        final list = (res['results'] as List).whereType<Map<String, dynamic>>().map(UniBookItem.fromJson).toList();
        if (mounted) {
          setState(() {
            _uniBookResults = list;
          });
        }
      } else if (mounted) {
        setState(() {
          _erreur = res?['error']?.toString() ?? 'Erreur lors de la recherche Uni Book.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingUniBook = false);
    }
  }

  Future<void> _telecharger(AcademicLibraryEntry entry) async {
    final fileId = entry.fileId;
    if (fileId == null || fileId.isEmpty) {
      setState(() => _erreur = '« ${entry.title} » n\'a pas de fichier joint.');
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
    if (_selectedMode == 1) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildUniBookContent(),
      );
    }

    final libraryAsync = ref.watch(libraryListProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: libraryAsync.when(
        data: (entries) => _buildContent(entries),
        loading: () => const LoadingView(label: 'Chargement des ressources…', mascot: true),
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
    final categories = [
      'Tous',
      ...{...entries.map((e) => e.category).where((c) => c.isNotEmpty)}
    ];
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
        _buildSliverHeader(entries.length),
        _buildModeSwitcher(),
        _buildSearchBar(),
        if (categories.length > 1) _buildCategoryChips(categories),
        if (_erreur != null) _buildErrorBanner(),
        if (filtered.isEmpty) _buildEmptyState() else ..._buildGroupedList(grouped),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  // ── Header hero « Book Lending » ───────────────────────────────────────────

  Widget _buildSliverHeader(int count) {
    final isUniBook = _selectedMode == 1;
    final badgeLabel = isUniBook ? '$count ouvrages libres' : '$count ressources';
    final titleLabel = isUniBook ? 'Uni Book' : 'Bibliothèque';
    final subtitleLabel =
        isUniBook ? 'Bibliothèque ouverte — 30+ résultats par recherche' : 'Supports de cours & polycopiés officiels';

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 12),
        height: 148,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isUniBook ? const [Color(0xFF0F172A), Color(0xFF0D9488)] : const [Color(0xFF1E3A8A), Color(0xFF0D9488)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Couverture livre hero en filigrane à droite
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 170,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Colors.black, Colors.transparent],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    'assets/illustrations/hero_books.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
            ),
            // Contenu texte à gauche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsBold.books, color: Colors.white, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            badgeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      titleLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
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
  }

  // ── Switcher de mode : Supports vs Uni Book ────────────────────────────────

  Widget _buildModeSwitcher() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMode = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                    decoration: BoxDecoration(
                      color: _selectedMode == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedMode == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIconsBold.folderOpen,
                          size: 15,
                          color: _selectedMode == 0 ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Supports',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _selectedMode == 0 ? FontWeight.w700 : FontWeight.w500,
                              color: _selectedMode == 0 ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedMode = 1);
                    if (_uniBookResults.isEmpty && !_isLoadingUniBook) {
                      _searchUniBook();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                    decoration: BoxDecoration(
                      color: _selectedMode == 1 ? const Color(0xFF1E3A8A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedMode == 1
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIconsBold.books,
                          size: 15,
                          color: _selectedMode == 1 ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Uni Book',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _selectedMode == 1 ? FontWeight.w700 : FontWeight.w500,
                              color: _selectedMode == 1 ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Contenu Uni Book ───────────────────────────────────────────────────────

  Widget _buildUniBookContent() {
    final uniBookCategories = [
      'Tous',
      'Informatique & Tech',
      'Mathématiques',
      'Physique & Chimie',
      'Biologie & Santé',
      'Économie & Droit',
      'Sciences Générales',
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(_uniBookResults.length),
        _buildModeSwitcher(),
        _buildUniBookSearchBar(),
        _buildUniBookCategoryChips(uniBookCategories),
        if (_erreur != null) _buildErrorBanner(),
        if (_isLoadingUniBook)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingView(
              label: 'Recherche dans Uni Book (30+ ouvrages)…',
              mascot: true,
            ),
          )
        else if (_uniBookResults.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: PhosphorIconsDuotone.books,
              title: 'Aucun livre trouvé',
              message: 'Essayez un autre mot-clé (ex: Python, Algèbre, Physique, Biologie).',
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  const Icon(PhosphorIconsBold.bookBookmark, size: 16, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 8),
                  Text(
                    '${_uniBookResults.length} ouvrages disponibles (≥ 30 par requête)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = _uniBookResults[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UniBookCard(book: book),
                  );
                },
                childCount: _uniBookResults.length,
              ),
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildUniBookSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(PhosphorIconsBold.magnifyingGlass, color: Color(0xFF64748B), size: 18),
              ),
              Expanded(
                child: TextField(
                  onSubmitted: (v) {
                    _uniBookQuery = v;
                    _searchUniBook(query: v);
                  },
                  onChanged: (v) => _uniBookQuery = v,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher dans Uni Book (titre, sujet, auteur)…',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_uniBookQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() => _uniBookQuery = '');
                    _searchUniBook(query: '');
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(PhosphorIconsBold.x, color: Color(0xFF94A3B8), size: 16),
                  ),
                ),
              GestureDetector(
                onTap: () => _searchUniBook(query: _uniBookQuery),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Chercher',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUniBookCategoryChips(List<String> cats) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final selected = _selectedUniBookCategory == cats[i];
            return GestureDetector(
              onTap: () {
                setState(() => _selectedUniBookCategory = cats[i]);
                _searchUniBook(category: cats[i]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0D9488) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  cats[i],
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Barre de recherche ────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(PhosphorIconsBold.magnifyingGlass, color: Color(0xFF64748B), size: 18),
              ),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un cours, un document…',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
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
                    child: Icon(PhosphorIconsBold.x, color: Color(0xFF94A3B8), size: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1E3A8A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  cats[i],
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
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
                width: 4,
                height: 16,
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
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${entry.value.length}',
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
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

// ─── Card avec Couverture Livre Réelle ──────────────────────────────────────

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

class _LibraryCardState extends State<_LibraryCard> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + widget.index * 40),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 40), _anim.forward);
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.isDownloading ? null : widget.onDownload,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Couverture du livre en miniature réelle
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent.withValues(alpha: 0.8), accent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Image.asset(
                              'assets/illustrations/course_books.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(icon, color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                          // Badge format (PDF, DOCX) en haut à gauche
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Titre et métadonnées
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (widget.entry.course.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEBF4FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.entry.course,
                                    style: const TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (widget.entry.size != null)
                                Text(
                                  widget.entry.size!,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          if (widget.entry.description != null && widget.entry.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.entry.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Bouton Télécharger
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDownloading ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDownloading ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE),
          ),
        ),
        child: isDownloading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A8A)),
                ),
              )
            : const Center(
                child: Icon(
                  PhosphorIconsBold.downloadSimple,
                  color: Color(0xFF1E3A8A),
                  size: 18,
                ),
              ),
      ),
    );
  }
}

// ── Carte livre Uni Book ────────────────────────────────────────────────────

class _UniBookCard extends StatelessWidget {
  final UniBookItem book;

  const _UniBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Couverture de livre
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 72,
              height: 102,
              color: const Color(0xFFF1F5F9),
              child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                  ? Image.network(
                      book.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultCover(),
                    )
                  : _defaultCover(),
            ),
          ),
          const SizedBox(width: 12),
          // Métadonnées
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book.authors.isEmpty ? 'Auteur académique' : book.authors.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: book.format == 'EPUB' ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book.format,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: book.format == 'EPUB' ? const Color(0xFF059669) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    if (book.year != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${book.year}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Uni Book',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Bouton de consultation / téléchargement
                if (book.downloadUrl != null && book.downloadUrl!.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(book.downloadUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Impossible d\'ouvrir le lien de téléchargement.')),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsBold.arrowSquareOut, size: 13, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Consulter / Télécharger',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(PhosphorIconsDuotone.bookOpen, size: 30, color: Colors.white),
      ),
    );
  }
}
