/// Identité publique de l'application et de KERNEL FORGE, en un seul endroit.
///
/// Miroir de `uniflow-we/src/lib/contactInfo.ts` : les trois clients doivent
/// annoncer les mêmes liens. Rien de secret ici — ce fichier est embarqué en
/// clair dans le binaire, comme tout le reste.
///
/// La version est tenue à la main plutôt que lue par un greffon natif : un
/// test (`test/app_info_test.dart`) la compare à `pubspec.yaml`, ce qui
/// attrape l'oubli sans ajouter de dépendance de plateforme.
library;

const String appVersion = '1.0.0';
const int appBuildNumber = 1;
const String appVersionLabel = 'Version $appVersion (build $appBuildNumber)';

const String uniflowWebsiteUrl = 'https://uniflow.kernelforge.codes';
const String kernelForgeGithubUrl = 'https://github.com/KERNEL-FORGE-G';
const String kernelForgeWhatsappGroupUrl = 'https://chat.whatsapp.com/IFkGMr4Ev2KCFAKw9EmEde';
const String contactEmail = 'uniflow@kernelforge.codes';

/// Ce qu'est KERNEL FORGE, tel que le propriétaire veut le voir présenté
/// (2026-09-21) : une startup, pas « une communauté tech ».
const String kernelForgeDescription =
    'KERNEL FORGE est une startup fondée à l’Université de Yaoundé I par des étudiants en '
    'informatique de la Faculté des Sciences. UniFlow est son premier produit : construit '
    'd’abord pour sa propre faculté, avec les vrais emplois du temps, les vraies UE et les '
    'vraies contraintes de réseau. L’ambition est plus large : devenir une entreprise de '
    'logiciel qui conçoit et livre des projets pour des clients de tous secteurs, au '
    'Cameroun et partout dans le monde.';
