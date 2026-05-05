import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),

              const Text(
                'Smart Campus Navigator',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),
              const Text(
                'Find rooms, navigate easily, and explore your campus',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Guest
              ElevatedButton(
                onPressed: () {
                  // نروح مباشرة للتطبيق
                  context.go('/');
                },
                child: const Text('Continue as Guest'),
              ),

              const SizedBox(height: 16),

              // Login
              OutlinedButton(
                onPressed: () {
                  context.push('/login');
                },
                child: const Text('Login'),
              ),

              const SizedBox(height: 12),

              // Sign Up
              TextButton(
                onPressed: () {
                  context.push('/register');
                },
                child: const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}