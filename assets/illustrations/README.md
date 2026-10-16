# IMAGES-UNIFLOW — toutes les images du projet, pour le propriétaire

Dossier constitué le 2026-09-21 à la demande du propriétaire : **une copie de
chaque image utilisée ou générée** pour UniFlow, rangée par usage. Les
applications n'y lisent rien — chacune embarque ses propres copies
(`uniflow-we/src/assets/mascot`, `uniflow-mobile/assets`,
`uniflow-desktop/assets`). Ce dossier sert à réutiliser les visuels
(réseaux sociaux, présentations, boutiques d'applications, impression).

## `logos/`

| Fichier | Usage |
| --- | --- |
| `uniflow-logo-principal-transparent.png` | Logo UniFlow principal, fond retiré (référence du bucket Appwrite `uniflow_primary_logo`) |
| `uniflow-logo-alternatif-transparent.png` | Variante horizontale |
| `uniflow-wordmark.png` | Mot-symbole (barre de navigation du site) |
| `uniflow-mascotte-logo-transparent.png` | Ancienne mascotte du logo, détourée |
| `uniflow-logo.svg` | Version vectorielle |
| `uniflow-icone-512.png` | Icône PWA / boutique |
| `kernel-forge-logo.png` / `.webp` | Logo **KERNEL FORGE** (fourni le 2026-09-21), fond crème retiré |
| `kernel-forge-logo-original.jpeg` | Original tel que fourni |

## `mascotte-uni/`

Les **12 poses d'Uni**, la mascotte-assistant (style Duolingo, palette
UniFlow bleu `#1e3a8a` / turquoise `#0d9488`), détourées et recadrées, en PNG
(768 px) et WebP. `originaux-generes/` garde les rendus bruts avant détourage.

| Pose | Quand elle apparaît |
| --- | --- |
| `uni_wave` | Accueil, connexion, présentation aux visiteurs |
| `uni_thinking` | Chargement, Uni qui rédige une réponse |
| `uni_celebrate` | Succès (inscription, devoir rendu, paiement validé) |
| `uni_sorry` | Erreurs, écran de secours, réponse impossible |
| `uni_search` | Page introuvable (404), listes vides, recherche sans résultat |
| `uni_sleeping` | Hors ligne, session expirée |
| `uni_graduate` | Notes, réussite académique, fin de parcours |
| `uni_pointing` | Conseils, mise en avant d'un bouton ou d'une étape |
| `uni_peek_right` / `uni_peek_bottom` | Apparitions depuis le bord de l'écran (astuces, nouveautés) |
| `uni_headset` | Assistant en ligne, support, messagerie |
| `uni_shield` | Sécurité, confidentialité, suppression de compte |

## `mascotte-archlord/`

**Archlord**, la mascotte du fondateur (demande du 2026-09-21), dessinée dans
le même style qu'Uni d'après la photo fournie : jeune homme à la peau foncée,
cheveux courts, sweat à capuche bleu UniFlow avec le logo, badge au cou. Il
apparaît sur certaines pages, souvent avec Uni, les deux échangeant une
remarque sur un point de la page (composant `MascotDialogue` du web ; les
mêmes fichiers sont dans `assets/mascot/` des dépôts mobile et desktop).

| Pose | Quand elle apparaît |
| --- | --- |
| `archlord_wave` | Accueil de la page Contact, salut au visiteur |
| `archlord_explain` | Quand il parle dans un dialogue (pose par défaut) |
| `archlord_laptop` | Le développement, la startup, la technique |
| `archlord_thumbs` | Encouragement, validation d'un point |
| `archlord_thinking` | Une question ouverte, un problème à résoudre |
| `archlord_pointing` | Il désigne un élément de la page (l'équipe, la vidéo) |
| `archlord_uni_fistbump` | Archlord et Uni poing contre poing — appel final de la page À propos |

`originaux-generes/` : rendus bruts avant détourage. Les fonds ont été retirés
puis les franges « démattées » (le halo clair des bords a été recalculé) pour
rester nets sur les pages bleues.

## `assistant/`

`uni-avatar-visage.png` : le visage d'Uni (bouton flottant, bulles de
conversation). `uni-avatar-original-genere.png` : rendu d'origine.

## `illustrations/`

Les trois écrans d'accueil de l'application mobile (`onboarding_1_bienvenue`,
`onboarding_2_univers`, `onboarding_3_connecte`).

## Régénérer

Les scripts de détourage / recadrage / export sont volontairement hors des
dépôts (`/tmp/uniflow-tools/detourer.py`, `mascotte.py`) : ils ne servent
qu'à la fabrication. Le principe : détection de la couleur de fond connexe aux
bords, remplissage en transparence avec lissage du contour, recadrage au
contenu, export PNG + WebP vers chaque dépôt et ici.
