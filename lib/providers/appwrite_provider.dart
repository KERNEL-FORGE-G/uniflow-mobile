import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/appwrite_service.dart';

final appwriteServiceProvider = Provider<AppwriteService>((ref) {
  return AppwriteService();
});
