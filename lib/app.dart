import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/biometrics/presentation/views/biometric_enrollment_prompt.dart';

class UmkmManagerApp extends ConsumerWidget {
  const UmkmManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final config = ref.watch(appConfigProvider);

    return MaterialApp.router(
      title: 'UMKM Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        final page = child ?? const SizedBox.shrink();
        if (!config.isSupabaseConfigured) return page;
        return BiometricEnrollmentPrompt(child: page);
      },
    );
  }
}
