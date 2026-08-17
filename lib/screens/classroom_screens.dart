import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class ClassroomSearchScreen extends ConsumerStatefulWidget {
  const ClassroomSearchScreen({super.key});

  @override
  ConsumerState<ClassroomSearchScreen> createState() => _ClassroomSearchScreenState();
}

class _ClassroomSearchScreenState extends ConsumerState<ClassroomSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salles disponibles', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(classroomsProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.textMutedLight,
          indicatorColor: AppColors.secondary,
          tabs: const [
            Tab(text: 'Maintenant'),
            Tab(text: 'Plus tard'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Rechercher une salle...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          
          // Note de rafraîchissement
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.sync, size: 14, color: AppColors.textMutedLight),
                SizedBox(width: 4),
                Text('Mis à jour en temps réel depuis le serveur', style: TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Liste des salles dynamiques
          Expanded(
            child: classroomsAsync.when(
              data: (classrooms) {
                final filtered = classrooms.where((room) {
                  return room.name.toLowerCase().contains(_searchQuery) ||
                         room.building.toLowerCase().contains(_searchQuery) ||
                         room.typeLabel.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Aucune salle trouvée.', style: TextStyle(color: AppColors.textMutedLight)),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildClassroomList(filtered),
                    _buildClassroomList(filtered),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomList(List rooms) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text('${room.name} (${room.building})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('Type: ${room.typeLabel} • Capacité: ${room.capacity} places', style: const TextStyle(color: AppColors.textMutedLight)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Disponible',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
