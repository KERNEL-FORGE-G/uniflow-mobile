import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration centrale du backend Appwrite auto-hébergé (VPS KERNEL FORGE).
class AppwriteConfig {
  static const String defaultEndpoint = 'https://vps.kernelforge.codes/v1';
  static const String defaultProjectId = 'uniflow';
  static const String defaultDatabaseId = 'uniflow';
  static const String defaultIndependantDatabaseId = 'independant';
  static const String defaultStorageBucketId = 'uniflow_assets';
  static const String defaultApiFunctionId = 'uniflow-api';

  static String get endpoint =>
      dotenv.isInitialized ? (dotenv.maybeGet('APPWRITE_ENDPOINT') ?? defaultEndpoint) : defaultEndpoint;

  static String get projectId =>
      dotenv.isInitialized ? (dotenv.maybeGet('APPWRITE_PROJECT_ID') ?? defaultProjectId) : defaultProjectId;

  static String get databaseId =>
      dotenv.isInitialized ? (dotenv.maybeGet('APPWRITE_DATABASE_ID') ?? defaultDatabaseId) : defaultDatabaseId;

  static String get independantDatabaseId => dotenv.isInitialized
      ? (dotenv.maybeGet('INDEPENDANT_DATABASE_ID') ?? defaultIndependantDatabaseId)
      : defaultIndependantDatabaseId;

  static String get storageBucketId => dotenv.isInitialized
      ? (dotenv.maybeGet('APPWRITE_STORAGE_BUCKET_ID') ?? defaultStorageBucketId)
      : defaultStorageBucketId;

  static String get apiFunctionId => dotenv.isInitialized
      ? (dotenv.maybeGet('APPWRITE_API_FUNCTION_ID') ?? defaultApiFunctionId)
      : defaultApiFunctionId;
}
