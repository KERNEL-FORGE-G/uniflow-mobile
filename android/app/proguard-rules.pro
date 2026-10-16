# Règles R8 propres à UniFlow (release : isMinifyEnabled dans build.gradle.kts).
#
# R8 ne voit que le code Java/Kotlin : le moteur Flutter, l'embedding et les
# greffons. Le code Dart est compilé à part (AOT, libapp.so) et n'est jamais
# réduit ni renommé par R8. Les règles du moteur sont fournies par l'outillage
# Flutter (flutter_proguard_rules.pro) ; les greffons suivants livrent les
# leurs (consumer rules) et n'ont rien à ajouter ici : flutter_webrtc /
# livekit_client (org.webrtc), mobile_scanner (ML Kit), workmanager
# (androidx.work), geolocator (services Google Play).
#
# drift et sqlite3 : rien à garder. drift est du Dart pur, sqlite3_flutter_libs
# n'apporte qu'une bibliothèque native (libsqlite3.so) chargée par nom depuis
# Dart ; ni l'un ni l'autre n'a de classe Java que R8 pourrait retirer.

# flutter_local_notifications sérialise ses modèles (notifications planifiées,
# détails de canal) avec Gson, par réflexion sur les noms de champs. Gson livre
# ses propres règles, mais elles ne protègent pas les classes du greffon : des
# champs renommés donneraient une notification planifiée relue vide au
# redémarrage. On garde donc le paquet du greffon intact, comme le fait son
# application d'exemple.
-keep class com.dexterous.** { *; }
