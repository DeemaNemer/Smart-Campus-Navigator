import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../models/professor.dart';
import '../models/event.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/details/room_details_screen.dart';
import '../screens/details/professor_details_screen.dart';
import '../screens/details/event_details_screen.dart';
import '../screens/navigation/navigation_screen.dart';
import '../screens/events/create_event_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Splash
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final email = state.extra as String;
          return VerifyEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final token = (state.extra as String?) ?? '';
          return ResetPasswordScreen(prefilledToken: token);
        },
      ),

      // Home (after login)
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
      ),

      // Details
      GoRoute(
        path: '/room',
        builder: (context, state) {
          final room = state.extra as Room;
          return RoomDetailsScreen(room: room);
        },
      ),
      GoRoute(
        path: '/professor',
        builder: (context, state) {
          final professor = state.extra as Professor;
          return ProfessorDetailsScreen(professor: professor);
        },
      ),
      GoRoute(
        path: '/event',
        builder: (context, state) {
          final event = state.extra as Event;
          return EventDetailsScreen(event: event);
        },
      ),
      GoRoute(
        path: '/event-details',
        builder: (context, state) {
          final event = state.extra as Event;
          return EventDetailsScreen(event: event);
        },
      ),
      GoRoute(
        path: '/create-event',
        builder: (context, state) => const CreateEventScreen(),
      ),
      // Navigation
      GoRoute(
        path: '/navigate',
        builder: (context, state) {
          final destination = state.extra as Room;
          return NavigationScreen(destination: destination);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
}
