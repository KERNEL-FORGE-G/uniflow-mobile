import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../providers/appwrite_provider.dart';

/// Présence sécurisée par QR et proximité (service `/attendance-secure` du
/// routeur `uniflow-api`).
///
/// Le contrat est celui du web (`uniflow-we/src/lib/api.ts`,
/// `attendanceApi.openQrSession` / `scan`) : un QR porte
/// `{"type":"uniflow-attendance","version":1,"token":"…"}`, et l'émargement
/// exige la position de l'apprenant (précision ≤ 100 m) pour vérifier qu'il
/// est bien dans la salle. Un QR d'un autre client (web, desktop) se scanne
/// donc depuis le mobile, et inversement.
class AttendanceRepository {
  static const String servicePath = '/attendance-secure';

  final AppwriteService _service;
  AttendanceRepository(this._service);

  Future<Map<String, dynamic>> _call(Map<String, dynamic> payload) async {
    final Map<String, dynamic> response;
    try {
      response = await _service.callService(servicePath, payload);
    } on AppwriteException catch (error) {
      throw AttendanceException(error.message ?? 'Le service de présence est injoignable (code ${error.code}).');
    }
    if (response['ok'] != true) {
      throw AttendanceException(
        response['message']?.toString() ?? 'Le contrôle de présence a échoué.',
        code: response['code']?.toString(),
        distanceMeters: (response['distanceMeters'] as num?)?.toInt(),
      );
    }
    return response;
  }

  /// Ouvre (ou retrouve) la séance du jour pour le cours, puis émet un QR
  /// valable quinze minutes autour de la position de l'émetteur.
  Future<IssuedQr> openQrSession({
    required String courseId,
    required GeoPosition origin,
    int radiusMeters = 80,
    DateTime? date,
  }) async {
    final session = await _call({
      'action': 'roll',
      'courseId': courseId,
      'date': (date ?? DateTime.now()).toUtc().toIso8601String(),
      'rows': const [],
    });
    final sessionId = session['sessionId']?.toString() ?? '';
    if (sessionId.isEmpty) throw AttendanceException('La Function n\'a pas retourné la séance de présence.');
    final qr = await _call({
      'action': 'issue',
      'sessionId': sessionId,
      'courseId': courseId,
      'origin': origin.toJson(),
      'radiusMeters': radiusMeters,
    });
    final token = qr['token']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(qr['expiresAt']?.toString() ?? '');
    if (token.isEmpty || expiresAt == null) throw AttendanceException('La Function n\'a pas retourné de jeton QR exploitable.');
    return IssuedQr(
      token: token,
      sessionId: sessionId,
      courseId: courseId,
      expiresAt: expiresAt.toLocal(),
      radiusMeters: (qr['radiusMeters'] as num?)?.toInt() ?? radiusMeters,
    );
  }

  Future<void> revoke(String token) => _call({'action': 'revoke', 'token': token});

  /// Émarge avec le contenu brut d'un QR scanné.
  Future<ScanResult> scan({required String qrContent, required GeoPosition position}) async {
    final token = decodeAttendanceQr(qrContent);
    if (token == null) {
      throw AttendanceException('Ce QR n\'est pas un QR de présence UniFlow.', code: 'QR_FORMAT');
    }
    final response = await _call({'action': 'scan', 'token': token, 'position': position.toJson()});
    return ScanResult(
      alreadyRecorded: response['idempotent'] == true,
      message: response['message']?.toString() ?? 'Présence vérifiée.',
    );
  }
}

/// Position GPS telle que la Function la lit (`positionFrom`).
class GeoPosition {
  final double latitude;
  final double longitude;
  final double accuracy;

  const GeoPosition({required this.latitude, required this.longitude, required this.accuracy});

  Map<String, dynamic> toJson() => {'latitude': latitude, 'longitude': longitude, 'accuracy': accuracy};
}

class IssuedQr {
  final String token;
  final String sessionId;
  final String courseId;
  final DateTime expiresAt;
  final int radiusMeters;

  const IssuedQr({
    required this.token,
    required this.sessionId,
    required this.courseId,
    required this.expiresAt,
    required this.radiusMeters,
  });

  /// Contenu à dessiner dans le QR, identique au web.
  String get payload => encodeAttendanceQr(token);
}

class ScanResult {
  final bool alreadyRecorded;
  final String message;
  const ScanResult({required this.alreadyRecorded, required this.message});
}

class AttendanceException implements Exception {
  final String message;
  final String? code;
  final int? distanceMeters;
  AttendanceException(this.message, {this.code, this.distanceMeters});
  @override
  String toString() => message;
}

/// Contenu du QR : le format du web, à l'octet près.
String encodeAttendanceQr(String token) => jsonEncode({'type': 'uniflow-attendance', 'version': 1, 'token': token});

/// Jeton contenu dans un QR, ou `null` si ce n'est pas un QR de présence
/// UniFlow (autre application, version inconnue, jeton manquant).
String? decodeAttendanceQr(String content) {
  try {
    final decoded = jsonDecode(content.trim());
    if (decoded is! Map) return null;
    if (decoded['type'] != 'uniflow-attendance' || decoded['version'] != 1) return null;
    final token = decoded['token'];
    if (token is! String || token.trim().isEmpty) return null;
    return token.trim();
  } catch (_) {
    return null;
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(appwriteServiceProvider));
});
