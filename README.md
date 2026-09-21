# UniFlow Mobile

Application Android (et iOS) d'UniFlow pour les étudiants, délégués et
enseignants. Écrite en Flutter, elle parle **directement à Appwrite Cloud** —
mêmes collections, même bucket, mêmes Functions que le web et le desktop —
et fonctionne en lecture hors connexion grâce à un cache local.

## Sommaire

1. [Fonctionnalités](#fonctionnalités)
2. [Prérequis](#prérequis)
3. [Installation et lancement](#installation-et-lancement)
4. [Configuration](#configuration)
5. [Tests](#tests)
6. [Organisation du dépôt](#organisation-du-dépôt)
7. [Documentation](#documentation)

## Fonctionnalités

| Rôle | Écrans |
| --- | --- |
| Tous | Connexion (compte universitaire ou indépendant), tableau de bord, paramètres, notifications, aide, équipe KERNEL FORGE |
| Étudiant | Emploi du temps, unités d'enseignement et détail, inscriptions, notes, devoirs (rendu de fichier, quiz), bibliothèque (PDF), présence QR (scan), forum, messagerie |
| Délégué | Tout l'étudiant + émission du QR de présence et annonces |
| Enseignant | Listes d'étudiants et détail, saisie des notes, devoirs, présence |
| Administration | Annuaire des étudiants et enseignants |

Un écran « accès refusé » explicite s'affiche quand un rôle n'a pas droit à
une page, plutôt qu'une page vide.

## Prérequis

- Flutter stable (Dart ≥ 3.3).
- **Java 21.** Le projet tourne sous Gradle 8.14 / AGP 8.11.1, qui ne
  supportent pas Java 25. Si le build échoue sur
  `Gradle build failed due to Java/Gradle incompatibility`, épinglez le JDK
  (réglage utilisateur, rien n'est écrit dans le dépôt) :

  ```bash
  flutter config --jdk-dir=/usr/lib/jvm/java-21-openjdk-amd64
  ```

  Ne montez pas Gradle en 9.x pour contourner : AGP 8.11.1 n'y est pas
  compatible, il faudrait migrer AGP, Kotlin et les plugins (`workmanager`,
  `drift`, `image_picker`) ensemble.

## Installation et lancement

```bash
flutter pub get
flutter run                      # appareil ou émulateur connecté
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
./scripts/build_apk.sh           # même chose, avec les vérifications préalables
```

## Configuration

`pubspec.yaml` déclare `.env` comme asset : **tout ce qu'il contient est
embarqué en clair dans l'APK.** Il ne porte donc que des valeurs publiques
d'Appwrite Cloud et il est versionné pour que la CI puisse construire :

```env
APPWRITE_ENDPOINT=https://fra.cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=uniflow
APPWRITE_DATABASE_ID=uniflow
APPWRITE_STORAGE_BUCKET_ID=uniflow_assets
APPWRITE_AVATAR_BUCKET_ID=uniflow_assets
APPWRITE_CHAT_FILES_BUCKET_ID=uniflow_assets
APPWRITE_API_FUNCTION_ID=uniflow-api
```

Jamais de clé serveur ici : les opérations privilégiées (messagerie,
présence, notes, annuaire…) passent par la Function `uniflow-api`, qui vérifie
le rôle de l'appelant côté serveur.

## Tests

```bash
flutter analyze
flutter test                     # tests unitaires et de widgets
flutter test integration_test    # parcours sur appareil
```

Toute correction de logique ou de mise en page s'accompagne d'un test.

## Organisation du dépôt

```
uniflow-mobile/
├── lib/
│   ├── data/            appwrite_service.dart (client, exécution des Functions, envoi de fichiers)
│   ├── models/          modèles Appwrite et métier
│   ├── repositories/    accès aux collections, cache local, Functions
│   ├── providers/       état Riverpod (session, rôle, données)
│   ├── router/          GoRouter et gardes par rôle
│   ├── screens/         un fichier par écran
│   ├── widgets/         composants partagés
│   ├── services/        notifications, hors connexion, tâches de fond
│   └── theme/           thème UniFlow
├── test/                tests unitaires et de widgets
├── integration_test/    parcours de bout en bout
├── scripts/build_apk.sh
├── tools/               génération des icônes
├── assets/brand/        logos
└── docs/                notes techniques et historique
```

## Documentation

- `docs/erreurs-de-build-resolues.md` — incompatibilités de plugins déjà rencontrées et leur correction.
- `docs/publication-android.md` — clé de signature, construction de l'APK, release GitHub (`uniflow-apps`) et publication du lien sur le site.
- À la racine de l'espace de travail : `ETAT-DU-PROJET.md` et `TRAVAUX-RESTANTS.md`.
