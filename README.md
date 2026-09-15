# 🎓 UniFlow Mobile — L'Expérience Académique Augmentée

![UniFlow Logo](assets/brand/uniflow_logo_horizontal.png)

UniFlow Mobile est l'application compagnon essentielle pour les étudiants et enseignants de l'écosystème **UniFlow**. Conçue avec **Flutter**, elle offre une interface fluide, réactive et optimisée pour une utilisation quotidienne sur le campus, même en conditions de connectivité limitée.

## 🚀 Vision du Projet
UniFlow vise à numériser l'expérience universitaire en Afrique subsaharienne. Le module mobile se concentre sur la mobilité, l'instantanéité et la sécurité (émargement contrôlé).

## 🛠️ Améliorations Récentes & Unification
Auparavant dépendante d'une API gateway intermédiaire, l'application a été entièrement migrée pour une **communication directe avec Appwrite**.
- **Source de Vérité Unique** : Partage les mêmes collections (BD), buckets (Stockage) et fonctions que la version Web.
- **Zéro Latence** : Suppression des couches de transit inutiles pour une réactivité maximale.
- **Sécurité Renforcée** : Authentification native Appwrite avec gestion granulaire des permissions.

## ✨ Fonctionnalités Clés

### 1. Gestion des Études & Scolarité
- **Emploi du Temps Dynamique** : Visualisez vos cours par jour avec les salles et enseignants associés.
- **Mes Notes** : Accès instantané aux résultats académiques dès leur publication.
- **Mes Devoirs** : Liste des travaux à rendre avec rappels de date limite et statut de soumission.
- **Bibliothèque Numérique** : Accès aux supports de cours (PDF, Vidéos) stockés sur le Cloud UniFlow.

### 2. Émargement & Présence (Innovation)
- **Scanner QR Sécurisé** : Système d'appel par QR Code avec vérification de jeton temporaire pour éviter les fraudes.
- **Historique de Présence** : Suivi de votre assiduité pour chaque unité d'enseignement (UE).

### 3. Communication & Communauté
- **Forum UniFlow** : Espace d'entraide pour poser des questions, partager des ressources et liker les meilleures réponses.
- **Messagerie Privée** : Discutez directement avec vos délégués ou enseignants.

### 4. Sentinelle IoT (Santé & Sécurité)
- **Monitoring Santé** : Interface mobile pour consulter les rapports des kiosques Sentinelle (SpO2, Rythme cardiaque).
- **Alertes Vigie** : Notifications en cas d'incident détecté sur le campus par l'IA Edge.

## 💻 Stack Technique
- **Framework** : Flutter (Dart)
- **Gestion d'État** : Riverpod (Flexible & Testable)
- **Backend-as-a-Service** : Appwrite (Database, Auth, Storage, Functions)
- **Navigation** : GoRouter
- **Persistence** : flutter_dotenv & Appwrite SDK

## ⚙️ Configuration
Créez un fichier `.env` à la racine :
```env
APPWRITE_ENDPOINT=https://appwrite.kernelforge.codes/v1
APPWRITE_PROJECT_ID=6a959096002a64d9d4e6
APPWRITE_DATABASE_ID=uniflow
APPWRITE_STORAGE_BUCKET_ID=uniflow_assets
```

> ⚠️ **Ne jamais mettre de clé d'API serveur (`APPWRITE_API_KEY`) dans ce fichier.**
> `pubspec.yaml` déclare `.env` comme asset : tout ce qu'il contient est embarqué
> en clair dans l'APK. Les opérations privilégiées passent par les **Functions
> Appwrite**, qui détiennent la clé côté serveur.

## 📦 Build & CI/CD
Le projet intègre des workflows **GitHub Actions** pour :
- **Analyse statique** : Vérification de la qualité du code.
- **Tests** : Exécution des tests unitaires et de widgets.
- **Build Automatisé** : Génération de l'APK à chaque push sur `main`.

## 🧰 Prérequis outillage

**Java 21 est requis.** Le projet tourne sous Gradle 8.14 / AGP 8.11.1, qui
**ne supportent pas Java 25**. Si votre `java` par défaut est plus récent, le build
échoue sur `Gradle build failed due to Java/Gradle incompatibility`. Épinglez le JDK —
c'est un réglage utilisateur, rien n'est écrit dans le dépôt :

```bash
flutter config --jdk-dir=/usr/lib/jvm/java-21-openjdk-amd64
```

> ⚠️ Ne montez **pas** Gradle en 9.x pour « régler » ce problème : AGP 8.11.1 n'est
> pas compatible avec Gradle 9, il faudrait migrer AGP, Kotlin et les plugins
> (`flutter_webrtc`, `workmanager`, `drift`, `image_picker`) en même temps.

---
© 2026 **KERNEL FORGE** — Numérisons l'avenir académique.
