import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for auth check to complete, then navigate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    // Show splash for at least 1.5s
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final state = ref.read(authProvider);

    // Wait until status is determined
    if (state.status == AuthStatus.initial) {
      // Listen for changes
      ref.listenManual(authProvider, (prev, next) {
        if (next.status != AuthStatus.initial && mounted) {
          _navigate(next.status);
        }
      });
    } else {
      _navigate(state.status);
    }
  }

  void _navigate(AuthStatus status) {
    if (status == AuthStatus.authenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                size: 70,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Smart Campus',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Navigator',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: AppColors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Birzeit University',
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
