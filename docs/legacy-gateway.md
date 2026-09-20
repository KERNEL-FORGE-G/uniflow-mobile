# UniFlow Mobile — connexion à la gateway

L’application mobile utilise l’API gateway UniFlow et ne doit pas appeler Appwrite directement pour les données métier.

L’URL par défaut est :

```text
https://api-uniflow.kernelforge.codes/api/v1
```

Pour un autre environnement, passez l’URL au moment du build :

```bash
flutter build apk --release \
  --dart-define=UNIFLOW_API_BASE_URL=https://api-uniflow.kernelforge.codes/api/v1
```

Les providers chargent les étudiants, enseignants et unités d’enseignement via la gateway. En cas de coupure réseau, les données locales mockées restent visibles afin de préserver le mode offline-first. Un jeton JWT peut être ajouté ultérieurement au client sans changer les écrans.
