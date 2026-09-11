import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import 'grades.dart';
import 'assignments.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final gradesAsync = ref.watch(gradesListProvider);
    final assignmentsAsync = ref.watch(assignmentsListProvider);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'UniFlow Mobile',
            subtitle: user != null ? 'Bonjour, ${user.name}' : 'Bienvenue sur UniFlow',
            trailing: SizedBox(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildQuickStats(gradesAsync, assignmentsAsync),
                const SizedBox(height: 20),
                const Text('Actions Rapides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildActionGrid(context),
                const SizedBox(height: 20),
                const Text('Prochains Devoirs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildRecentAssignments(assignmentsAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(AsyncValue gradesAsync, AsyncValue assignmentsAsync) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Moyenne',
            value: gradesAsync.when(
              data: (grades) {
                if (grades.isEmpty) return '--';
                final avg = grades.map((e) => e.score / e.maxScore).reduce((a, b) => a + b) / grades.length;
                return '${(avg * 20).toStringAsFixed(1)}/20';
              },
              loading: () => '...',
              error: (_, __) => '!',
            ),
            icon: Icons.trending_up,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Devoirs',
            value: assignmentsAsync.when(
              data: (list) => '${list.where((e) => e.status != "DONE").length}',
              loading: () => '...',
              error: (_, __) => '!',
            ),
            icon: Icons.assignment_outlined,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _ActionCard(icon: Icons.calendar_month, label: 'Planning', color: Colors.indigo, onTap: () {}),
        _ActionCard(icon: Icons.library_books, label: 'Bibliothèque', color: Colors.teal, onTap: () => context.push('/bibliotheque')),
        _ActionCard(icon: Icons.qr_code_scanner, label: 'Scanner QR', color: Colors.purple, onTap: () => context.push('/presence')),
        _ActionCard(icon: Icons.forum_outlined, label: 'Forum', color: Colors.pink, onTap: () => context.push('/forum')),
      ],
    );
  }

  Widget _buildRecentAssignments(AsyncValue assignmentsAsync) {
    return assignmentsAsync.when(
      data: (list) {
        final pending = list.where((e) => e.status != "DONE").take(3).toList();
        if (pending.isEmpty) return const SectionCard(child: Center(child: Text('Aucun devoir proche')));
        return Column(
          children: pending.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w500))),
                  Text(a.courseCode, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          )).toList(),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Erreur'),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});
  @override Widget build(BuildContext context) => SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 20), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))]));
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: SectionCard(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 10), Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))])));
}
