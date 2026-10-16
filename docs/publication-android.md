# Publier UniFlow Mobile (Android)

Les APK sont publiés dans les **releases GitHub** du dépôt public
`KERNEL-FORGE-G/uniflow-apps` ; le site web lit le lien de téléchargement
dans la collection Appwrite `app_releases` (modifiable depuis la page
Administration › Paramètres du web, ou par script). Rien n'est codé en dur :
une nouvelle version ne demande qu'une nouvelle release et une mise à jour du
lien.

## 1. Une fois pour toutes : la clé de signature

Sans `android/key.properties`, `flutter build apk --release` signe avec la clé
de **debug** (voir `android/app/build.gradle.kts`). Android refuse ensuite
d'installer une mise à jour signée avec une autre clé : les testeurs devraient
désinstaller puis réinstaller, et perdraient leurs données locales. Créer la
clé **avant** la première publication, et la conserver hors du dépôt (elle est
irrécupérable une fois perdue, et publiable par personne d'autre une fois
divulguée).

```bash
cd uniflow-mobile/android/app
keytool -genkey -v -keystore uniflow-release.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias uniflow
```

Puis `android/key.properties` (ignoré par Git, `storeFile` relatif à
`android/app`) :

```properties
storeFile=uniflow-release.jks
storePassword=…
keyAlias=uniflow
keyPassword=…
```

Sauvegarder `uniflow-release.jks` et ces mots de passe dans un coffre (pas dans
Google Drive en clair, pas dans un dépôt).

## 2. Construire et empreinter

```bash
cd uniflow-mobile
flutter pub get
flutter build apk --release                 # APK universel (toutes architectures)
# variante plus légère par appareil : flutter build apk --release --split-per-abi
mv build/app/outputs/flutter-apk/app-release.apk uniflow-mobile-1.0.0-beta.1.apk
sha256sum uniflow-mobile-1.0.0-beta.1.apk
stat -c %s uniflow-mobile-1.0.0-beta.1.apk    # taille en octets, pour le site
```

Le numéro de version vient de `pubspec.yaml` (`version: 1.0.0+1` : nom `1.0.0`,
code `1`). **Incrémenter le code de build à chaque publication** (`+2`, `+3`…),
sinon Android refuse la mise à jour.

## 3. La release GitHub (`uniflow-apps`)

Le dépôt accueillera aussi les binaires desktop : les étiquettes sont préfixées
par l'application.

| Champ | Valeur |
| --- | --- |
| Étiquette (tag) | `mobile-v1.0.0-beta.1` — cible `main` |
| Titre | `UniFlow Mobile 1.0.0 bêta 1 — Android (APK)` |
| Fichier joint | `uniflow-mobile-1.0.0-beta.1.apk` |
| Pré-lancement | **coché** tant que la version n'a pas été validée sur téléphone |
| Dernière version | laisser coché |

Notes de version (Markdown, à coller dans « Décrivez cette version ») :

```markdown
## UniFlow Mobile 1.0.0 — bêta 1 (Android)

Première version installable de l'application mobile UniFlow, la plateforme
universitaire de KERNEL FORGE (Université de Yaoundé I, faculté des Sciences).

### Ce que contient l'application
- **Compte universitaire ou indépendant** : inscription directe depuis
  l'application, raccordement automatique à la filière et au niveau.
- **Emploi du temps** personnalisé (filière + niveau), unités d'enseignement,
  inscriptions.
- **Devoirs** (rendu de fichiers, quiz), **notes**, **bibliothèque** (PDF).
- **Présence par QR code** : scan côté étudiant, émission côté délégué et
  enseignant.
- **Forum**, **messagerie**, **notifications**.
- **Badges** de progression et assistant **Uni**.
- **Hors ligne** : consultation des données déjà chargées, synchronisation au
  retour du réseau.
- Espaces enseignant (listes d'étudiants, saisie des notes, présence) et
  administration (annuaire).

### Installation
1. Télécharger `uniflow-mobile-1.0.0-beta.1.apk` ci-dessous.
2. Ouvrir le fichier ; Android demande d'autoriser l'installation depuis cette
   source (Chrome, Fichiers…) : accepter.
3. Lancer UniFlow, suivre les écrans de présentation, créer un compte ou se
   connecter.

Android **7.0 ou plus récent** (ciblage Android 16). Aucun compte Google ni
Play Store nécessaire.

### Vérification
- Taille : `__ Mo`
- SHA-256 : `________________________________________________________________`

Vérifier : `sha256sum uniflow-mobile-1.0.0-beta.1.apk`.

### Limites connues de cette bêta
- Version de **test** : les retours sont attendus sur le forum de l'application,
  par message direct à l'équipe, ou par courriel à uniflow@kernelforge.codes.
- Les emplois du temps ICT4D L2 et L3 sont **provisoires** (données de
  démonstration en attendant les horaires officiels).
- La visioconférence est réservée à l'application desktop.
- Une version bêta publiée avec une clé de signature de développement devra être
  désinstallée avant d'installer la première version signée définitivement.
```

## 4. Publier le lien sur le site

Depuis `uniflow-we` (clé serveur lue dans `uniflow-backend/.env`) :

```bash
node scripts/set-app-release.mjs android \
  --url "https://github.com/KERNEL-FORGE-G/uniflow-apps/releases/download/mobile-v1.0.0-beta.1/uniflow-mobile-1.0.0-beta.1.apk" \
  --version "1.0.0-beta.1" --file "uniflow-mobile-1.0.0-beta.1.apk" \
  --size <octets> --sha256 <empreinte>
```

Ou, connecté en `superadmin` sur le web : Administration › Paramètres ›
« Applications à télécharger ». La landing et le pied de page affichent le
bouton dès que le document `android` est publié.
