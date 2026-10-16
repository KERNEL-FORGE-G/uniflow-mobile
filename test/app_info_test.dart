import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/app_info.dart';

void main() {
  test('la version affichée dans « À propos » est celle de pubspec.yaml', () {
    // La version est une constante Dart (pas de greffon natif) ; ce test est
    // ce qui empêche d'oublier de la monter avec le pubspec.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final value = line.substring('version:'.length).trim();
    final parts = value.split('+');
    expect(parts.first, appVersion);
    expect(int.parse(parts.last), appBuildNumber);
    expect(appVersionLabel, contains(appVersion));
  });

  test('les liens publics sont en HTTPS et sans secret', () {
    for (final url in [uniflowWebsiteUrl, kernelForgeGithubUrl, kernelForgeWhatsappGroupUrl]) {
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.hasQuery, isFalse, reason: 'un lien public ne porte ni jeton ni paramètre');
    }
    expect(contactEmail, contains('@'));
  });

  test('KERNEL FORGE est présenté comme une startup, pas comme une communauté', () {
    expect(kernelForgeDescription, contains('startup'));
    expect(kernelForgeDescription, contains('Université de Yaoundé I'));
    expect(kernelForgeDescription, contains('premier produit'));
    expect(kernelForgeDescription.toLowerCase(), isNot(contains('communauté')));
  });
}
