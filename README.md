# 🎓 UniFlow Mobile — L'Expérience Académique Augmentée

![UniFlow Logo](assets/logo.png)

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
UNIFLOW_API_TOKEN=votre_token_secret
```

## 📦 Build & CI/CD
Le projet intègre des workflows **GitHub Actions** pour :
- **Analyse statique** : Vérification de la qualité du code.
- **Tests** : Exécution des tests unitaires et de widgets.
- **Build Automatisé** : Génération de l'APK à chaque push sur `main`.

---
© 2026 **KERNEL FORGE** — Numérisons l'avenir académique.
