import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';

// --- Auth User Model ---
class AuthUser {
  final String id;
  final String email;
  final String role;
  final String firstName;
  final String lastName;
  final String? matricule;
  final String? level;

  AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.matricule,
    this.level,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? json;
    // The nested role-specific object (student, teacher, etc.)
    final roleData = user['student'] ?? user['teacher'] ?? user['admin'] ?? user['delegue'] ?? {};

    return AuthUser(
      id: user['id'] ?? '',
      email: user['email'] ?? '',
      role: user['role'] ?? '',
      firstName: roleData['firstName'] ?? user['firstName'] ?? '',
      lastName: roleData['lastName'] ?? user['lastName'] ?? '',
      matricule: roleData['matricule'],
      level: roleData['level'],
    );
  }

  String get fullName => '$firstName $lastName';

  /// Maps the backend role string to a GoRouter path prefix.
  String get dashboardRoute {
    switch (role) {
      case 'ENSEIGNANT':
        return '/teacher/dashboard';
      case 'DELEGUE':
        return '/delegate/dashboard';
      case 'ADMIN':
      case 'SUPER_ADMIN':
      case 'DIRECTION':
      case 'SECRETARIAT':
        return '/admin/dashboard';
      case 'ETUDIANT':
      default:
        return '/student/dashboard';
    }
  }
}

// --- Auth Service ---
class AuthService {
  final Dio dio;
  AuthService(this.dio);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data['data'] ?? response.data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final response = await dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
    });
    return response.data['data'] ?? response.data;
  }

  Future<Map<String, dynamic>> me() async {
    final response = await dio.get('/auth/me');
    return response.data['data'] ?? response.data;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

// --- Auth State ---
class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({AuthUser? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// --- Auth Notifier ---
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AuthState());

  Future<String?> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = ref.read(authServiceProvider);
      final data = service.login(email, password);
      final result = await data;

      // Save the token
      final accessToken = result['accessToken'] as String?;
      if (accessToken != null) {
        ref.read(tokenProvider.notifier).state = accessToken;
      }

      // Parse the user
      final user = AuthUser.fromJson(result);
      state = state.copyWith(user: user, isLoading: false);

      return user.dashboardRoute;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? 'Erreur de connexion';
      final errorMessage = msg is List ? msg.join(', ') : msg.toString();
      state = state.copyWith(isLoading: false, error: errorMessage);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<String?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = ref.read(authServiceProvider);
      final result = await service.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );

      // Save the token
      final accessToken = result['accessToken'] as String?;
      if (accessToken != null) {
        ref.read(tokenProvider.notifier).state = accessToken;
      }

      // Parse the user
      final user = AuthUser.fromJson(result);
      state = state.copyWith(user: user, isLoading: false);

      return user.dashboardRoute;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? 'Erreur d\'inscription';
      final errorMessage = msg is List ? msg.join(', ') : msg.toString();
      state = state.copyWith(isLoading: false, error: errorMessage);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  void logout() {
    ref.read(tokenProvider.notifier).state = null;
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
