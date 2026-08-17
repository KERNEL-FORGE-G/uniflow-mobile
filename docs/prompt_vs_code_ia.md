# Prompt de génération pour l'application mobile UniFlow

Tu es un développeur Flutter senior expert en UI/UX Material 3 et en architecture propre avec Riverpod et GoRouter.
Voici le cahier des charges et les instructions détaillées pour implémenter toutes les interfaces manquantes de l'application **UniFlow** basées sur les maquettes fournies.

---

## 🎨 Consignes Générales de Design (Aesthetics & Premium UI)
*   **Thème & Couleurs :** Utilise le thème déjà défini dans l'application (pas besoin de redéfinir les couleurs, utilise `Theme.of(context).colorScheme`).
*   **Aesthetics Modernes :** Style premium avec des cartes épurées, des coins arrondis (`BorderRadius.circular(16)`), des espacements harmonieux et des ombres légères.
*   **Composants Standardisés :** Utilise les boutons, inputs et widgets natifs de Flutter stylisés via le thème pour une cohérence globale.
*   **Feedback Visuel :** Tous les écrans interactifs (soumission de formulaire, chargements) doivent afficher un indicateur de chargement (`CircularProgressIndicator`) et gérer proprement les états d'erreur et de succès.

---

## 📂 Structure & Architecture Cible
L'application utilise :
*   **GoRouter** pour la navigation (défini dans `lib/router/app_router.dart`).
*   **Riverpod** pour la gestion d'état (providers asynchrones avec pagination infinie).
*   **Dio** pour les requêtes réseau (avec intercepteur pour le jeton JWT).

---

## 📱 Spécification des Écrans par Rôle à Implémenter ou Mettre à Jour

### 1. Authentification & Accueil (Partie 1)
*   **Splash Screen & Onboarding :** Implémenter les 3 étapes d'onboarding avec illustrations professionnelles (widgets d'icônes ou placeholders soignés), indicateur de page (`PageController`) et bouton "Commencer" menant au Login.
*   **Login & Register :** Formulaires complets avec champs de saisie stylisés (Email, Mot de passe avec bouton pour masquer/afficher, Nom complet pour l'inscription, case à cocher pour les conditions générales).
*   **Forgot Password :** Saisie d'email et carte de confirmation avec indication de vérification de boîte mail.

### 2. Dashboard Étudiant (`StudentDashboardScreen`)
*   **En-tête :** Message d'accueil personnalisé ("Bonjour, [Nom] 👋") avec avatar de l'utilisateur.
*   **Cours du jour :** Liste verticale des cours avec horaires, code de l'UE, type de cours (CM/TD/TP), salle et badge d'état interactif ("En cours", "À venir").
*   **Prochains devoirs :** Liste des tâches avec indicateur de date sous forme de bloc calendrier (Jour/Mois) et date limite de rendu.

### 3. Dashboard Enseignant (`TeacherDashboardScreen`)
*   **Sessions à venir :** Liste des cours à dispenser avec compte à rebours ("Dans 30 min", "Dans 2h").
*   **Section "À faire" :** Liste de tâches administratives (ex: "Corriger des copies", "Publier des notes").

### 4. Dashboard Délégué (`DelegateDashboardScreen`)
*   **Alertes récentes :** Alertes de retards, absences non justifiées de la classe, ou réunions de délégués à venir.
*   **Statistiques de classe :** Cartes affichant le nombre d'élèves, taux de présence moyen et le nombre d'absents du jour.

### 5. Dashboard Administrateur (`AdminDashboardScreen`)
*   **Grille de statistiques :** Affichage 2x2 des indicateurs clés (Total Étudiants, Enseignants, UEs, Sessions actives aujourd'hui).
*   **Activité récente :** Journal des événements système en temps réel (inscriptions, alertes de retards, mises à jour d'EDT).

### 6. Gestion Académique & Emploi du Temps (Partie 2)
*   **Emploi du Temps (Semaine) :**
    *   Sélecteur de semaine et barre de jours horizontale interactive (Lun-Sam) avec indicateur du jour sélectionné.
    *   Liste chronologique des cours de la journée avec ligne de temps (Timeline) colorée selon le type de cours.
*   **Détail d'un Cours :** Fiche détaillée affichant la date, l'heure, la salle, l'enseignant, le groupe, et une description du cours avec bouton "Ajouter à mon calendrier" et "Voir les étudiants".
*   **Salles Disponibles :** Liste de recherche des salles en temps réel avec indicateur de statut ("Libre", "Occupée", "Indisponible") et filtre de recherche.
*   **Inscriptions UEs :** Écran avec deux onglets ("Cours" / "Demandes") permettant aux étudiants de rechercher des UEs et de postuler pour s'inscrire via un bouton interactif.

---

## 🛠️ Instructions pour l'IA (VS Code)
1.  Remplace les écrans placeholders existants dans `lib/screens/` par ces implémentations complètes.
2.  Assure-toi que les formulaires intègrent la validation des champs (ex: format email valide, mot de passe non vide).
3.  Pour chaque liste (Étudiants, UEs, Enseignants), couple l'interface avec les providers Riverpod asynchrones existants et utilise le défilement infini pour charger les données.
4.  Garantis que l'application compile sans aucune erreur (`flutter analyze` valide).
