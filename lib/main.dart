import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/providers.dart';

void main() {
  runApp(const ProviderScope(child: UniFlowApp()));
}

class UniFlowApp extends ConsumerStatefulWidget {
  const UniFlowApp({super.key});

  @override
  ConsumerState<UniFlowApp> createState() => _UniFlowAppState();
}

class _UniFlowAppState extends ConsumerState<UniFlowApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(gatewaySyncProvider.future));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'UniFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
