# Intégration continue — `.github/workflows/ci.yml`

Un seul fichier, trois jobs chaînés. Un job qui échoue arrête les suivants.

## Déclencheurs

- `push` sur `main` et `team-fronted-dev-mo`, et sur tout tag `v*` ;
- `pull_request` vers `main` ;
- `workflow_dispatch` (lancement manuel depuis l'onglet Actions).

`concurrency` regroupe les runs par branche et annule celui en cours quand
un nouveau commit arrive : les builds Android sont longs, il est inutile de
finir celui d'un commit déjà dépassé.

## Job `qualite`

Flutter **3.47.1** (`channel: stable`, cache activé), la même version qu'en
local. Étapes :

1. `flutter pub get` ;
2. `dart format --output=none --set-exit-if-changed lib test` — échoue si un
   fichier n'est pas formaté (largeur 120, cf. `analysis_options.yaml`) ;
3. `flutter analyze` — **réel**, sans assouplissement : les dépréciations
   `Databases.*Document` du SDK Appwrite sont ignorées fichier par fichier
   (`// ignore_for_file: deprecated_member_use`, justifié en commentaire) en
   attendant la migration `TablesDB` commune aux trois clients ;
4. `flutter test --coverage` ;
5. dépôt de `coverage/lcov.info` en artefact `couverture-lcov` (14 jours).

Les tests n'ont pas besoin de `.env` : `flutter_dotenv` n'est chargé que par
`main.dart`. Rappel : `flutter test` remplace le client HTTP par un faux qui
répond 400 à tout ; un run vert ne prouve rien sur les appels réseau (voir
`test_live/` et `integration_test/`).

## Job `build-android` (`needs: qualite`)

JDK **21** (Zulu) — Gradle 8.14 refuse le JDK par défaut du runner — puis
Flutter 3.47.1.

Le fichier `.env` est généré depuis les **secrets du dépôt** :

| Secret                        | Valeur attendue (Appwrite Cloud)   |
| ----------------------------- | ---------------------------------- |
| `APPWRITE_ENDPOINT`           | `https://fra.cloud.appwrite.io/v1` |
| `APPWRITE_PROJECT_ID`         | `uniflow`                          |
| `APPWRITE_DATABASE_ID`        | `uniflow`                          |
| `APPWRITE_STORAGE_BUCKET_ID`  | `uniflow_assets`                   |
| `APPWRITE_API_FUNCTION_ID`    | `uniflow-api`                      |

Ce sont des identifiants publics : le binaire embarque `.env` **en clair**,
aucune clé d'API ne doit jamais y figurer.

Builds : `flutter build apk --release --split-per-abi` (une archive par
ABI) et `flutter build appbundle --release`. Artefacts `UniFlow-Mobile-APK`
et `UniFlow-Mobile-AAB` (30 jours). La signature reste celle de débogage
tant qu'aucun `key.properties` n'est fourni ; l'AAB n'est donc pas
publiable sur le Play Store en l'état.

## Job `release` (`needs: build-android`, tags `v*` uniquement)

Télécharge l'artefact APK et publie une GitHub Release
(`softprops/action-gh-release@v2`) nommée `UniFlow Mobile vX.Y.Z`, avec
notes générées automatiquement et les APK en pièces jointes. Nécessite la
permission `contents: write`, déclarée dans le job.

## Suivre un run

```bash
gh run list --limit 5
gh run watch            # suit le dernier run de la branche courante
gh run view <id> --log-failed
```
