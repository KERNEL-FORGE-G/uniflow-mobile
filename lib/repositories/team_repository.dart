// `Databases.*Document` est marqué déprécié par le SDK Dart 26 au profit de
// `TablesDB.*Row` (Appwrite 1.8). Le schéma du projet est encore déclaré en
// collections/documents (`uniflow-we/scripts/appwrite-schema.mjs`) et la
// migration vers TablesDB se fera pour les trois clients en même temps ; on
// ignore la dépréciation ici, fichier par fichier, sans assouplir l'analyse
// globale.
// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../models/team_member.dart';
import '../providers/appwrite_provider.dart';

/// Accès à la collection `team_members`.
///
/// Lecture seule : l'ajout, la modification et la suppression d'un membre se
/// font **uniquement** depuis l'espace d'administration du web, qui passe par
/// la Function `team-roster` après vérification du rôle ADMIN côté serveur. La
/// collection n'accorde aucune écriture, sans quoi n'importe quel compte
/// connecté pourrait effacer la page publique de l'équipe.
class TeamRepository {
  final AppwriteService _service;

  TeamRepository(this._service);

  /// Membres de l'équipe, dans l'ordre voulu par l'administration.
  ///
  /// Le tri est demandé au serveur (`displayOrder`) plutôt que refait ici :
  /// c'est ce qui garantit que le mobile, le desktop et le web listent les
  /// mêmes personnes dans le même ordre.
  Future<List<TeamMember>> getMembers() async {
    try {
      final response = await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: 'team_members',
        queries: [Query.orderAsc('displayOrder'), Query.limit(100)],
      );
      if (response.documents.isNotEmpty) {
        return response.documents.map((doc) => TeamMember.fromDocument(doc)).toList();
      }
    } catch (_) {
      // BaaS non joignable ou collection non initialisée : repli sur les membres locaux.
    }
    return defaultTeamMembers;
  }
}

/// Équipe KERNEL FORGE complète (5 piliers + contributeurs).
/// Assure une consultation fluide 100% hors-ligne.
final List<TeamMember> defaultTeamMembers = [
  TeamMember(
    id: 'ravel',
    slug: 'ravel',
    name: 'NGHOMSI FEUKOUO RAVEL',
    github: 'Archlord12345',
    email: 'ravelnghomsi@gmail.com',
    team: 'Leadership',
    subTeam: 'Architecture & Direction',
    role: 'Fondateur KERNEL FORGE & Architecte',
    badge: 'Fondateur & Lead',
    accent: 'cyan',
    avatarFileId: 'assets/team/ravel.jpg',
    displayOrder: 0,
    bio: "Fondateur de KERNEL FORGE (kernelforge.codes) et architecte principal d'UniFlow. Étudiant à l'UY1.",
    linkedin: 'https://www.linkedin.com/in/kernelforge',
    website: 'https://ravelnghomsi.me',
  ),
  TeamMember(
    id: 'hassane',
    slug: 'hassane',
    name: 'HASSANE YOUSSOUF OUMAR',
    github: 'Hawadja',
    email: 'h.hawadja1@gmail.com',
    team: 'Backend',
    subTeam: 'Backend Microservices & Réseaux',
    role: 'Backend Developer & Systèmes',
    badge: 'NestJS Backend',
    accent: 'rose',
    avatarFileId: 'assets/team/hassane.jpg',
    displayOrder: 1,
    bio: 'Développeur Backend KERNEL FORGE. Spécialisé en microservices et architectures distribuées.',
    website: 'https://hawadja.github.io/portfolio/',
  ),
  TeamMember(
    id: 'sandra',
    slug: 'sandra',
    name: 'FEBNCHAK SANDRA BORELLE',
    github: 'FEBNCHAK',
    email: 'sandraborelle0@gmail.com',
    team: 'Frontend',
    subTeam: 'Frontend Mobile App & Web',
    role: 'Développeuse Full-Stack & Mobile UI/UX',
    badge: 'Mobile & Web',
    accent: 'emerald',
    avatarFileId: 'assets/team/sandra.jpg',
    displayOrder: 2,
    bio: 'Développeuse Full-Stack chez KERNEL FORGE. Spécialisée en interfaces mobiles et web réactives (Flutter & React) et ergonomie UX.',
  ),
  TeamMember(
    id: 'william',
    slug: 'william',
    name: 'MELI WILLIAM',
    github: 'WilliamMeli27',
    email: 'meliwilliam74@gmail.com',
    team: 'Backend',
    subTeam: 'Infrastructure, Réseaux & Sécurité',
    role: 'Infrastructure Réseau & Cybersécurité',
    badge: 'Infra & Cybersec',
    accent: 'amber',
    avatarFileId: 'assets/team/william.jpg',
    displayOrder: 3,
    bio: 'Technicien & Développeur chez KERNEL FORGE. Spécialisé en infrastructure réseau, sécurité des systèmes et bases de données.',
  ),
  TeamMember(
    id: 'ange',
    slug: 'ange',
    name: 'MOKAM ZUNE Ange Gabrielle',
    github: 'Ange55-star',
    email: 'gabriellemokam9@gmail.com',
    team: 'Backend',
    subTeam: 'Backend, Sécurité & APIs REST',
    role: 'Ingénieure Backend, Sécurité & APIs REST',
    badge: 'Backend & Sécurité',
    accent: 'cyan',
    avatarFileId: 'assets/team/mokam.jpg',
    displayOrder: 4,
    bio: 'Développeuse Backend & Sécurité chez KERNEL FORGE. Experte en APIs REST NestJS/TypeScript, PostgreSQL, webhooks sécurisés MoMo/OM et architecture BaaS Appwrite.',
    linkedin: 'https://www.linkedin.com/in/gabrielle-mokam-968389326',
  ),
  TeamMember(
    id: 'aliya',
    slug: 'aliya',
    name: 'Aliyatou Rachid Oumou Tourab',
    github: 'aliya-nadi',
    email: 'oumou.aliyatou@facsciences-uy1.cm',
    team: 'Frontend',
    subTeam: 'Frontend Desktop & Web',
    role: 'Frontend Developer',
    badge: 'Web Desktop',
    accent: 'purple',
    avatarFileId: '',
    displayOrder: 5,
  ),
  TeamMember(
    id: 'judith',
    slug: 'judith',
    name: 'Mandeng Judith Oceanne',
    github: 'oceannemj',
    email: 'judithoceanne12@gmail.com',
    team: 'Frontend',
    subTeam: 'Frontend Mobile App',
    role: 'Mobile Developer',
    badge: 'Mobile App',
    accent: 'emerald',
    avatarFileId: '',
    displayOrder: 6,
  ),
  TeamMember(
    id: 'juvenal',
    slug: 'juvenal',
    name: 'SINENG KENGNI JUVENAL',
    github: 'skjuv',
    email: 'sinengjuvenal@gmail.com',
    team: 'Frontend',
    subTeam: 'Multiplateforme',
    role: 'Frontend Developer',
    badge: 'Fullstack UI',
    accent: 'indigo',
    avatarFileId: '',
    displayOrder: 7,
  ),
  TeamMember(
    id: 'tessoh',
    slug: 'tessoh-pekam-marcel',
    name: 'Tessoh pekam marcel',
    github: '',
    email: 'tesmarcel48@gmail.com',
    team: 'Frontend',
    subTeam: 'MARKETING',
    role: 'Chef branche marketing',
    badge: 'MARKETING & Dev frontend',
    accent: 'blue',
    avatarFileId: '',
    displayOrder: 8,
  ),
  TeamMember(
    id: 'miguel',
    slug: 'miguel',
    name: 'DJOMGUE Miguel',
    github: '',
    email: '',
    team: 'Frontend',
    subTeam: 'Frontend Desktop',
    role: 'Desktop Developer',
    badge: 'Desktop App',
    accent: 'purple',
    avatarFileId: '',
    displayOrder: 9,
  ),
];

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(appwriteServiceProvider));
});

/// L'équipe telle que l'affiche l'écran `/equipe`.
///
/// Aucune session n'est requise : la collection est lisible par tous, comme la
/// page publique du web.
final teamMembersProvider = FutureProvider<List<TeamMember>>((ref) async {
  return ref.read(teamRepositoryProvider).getMembers();
});
