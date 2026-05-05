import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_campus_app/screens/auth/auth_gate_screen.dart';
import '../models/room.dart';
import '../models/professor.dart';
import '../models/event.dart';
import '../screens/home/home_shell.dart';
import '../screens/details/room_details_screen.dart';
import '../screens/details/professor_details_screen.dart';
import '../screens/details/event_details_screen.dart';
import '../screens/navigation/navigation_screen.dart';
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    
    initialLocation: '/auth',
    routes: [
      // Main shell with bottom navigation
      GoRoute(
  path: '/auth',
  builder: (context, state) => const AuthGateScreen(),
),
GoRoute(
  path: '/',
  builder: (context, state) => const HomeShell(),
),
//مؤقتا حطينا صفحة تسجيل الدخول والتسجيل كصفحات مستقلة، لكن ممكن ندمجهم في صفحة واحدة فيها تبويبين أو أزرار للتبديل بينهما
GoRoute(
  path: '/login',
  builder: (context, state) => const Scaffold(
    body: Center(child: Text('Login Screen')),
  ),
),

GoRoute(
  path: '/register',
  builder: (context, state) => const Scaffold(
    body: Center(child: Text('Register Screen')),
  ),
),


      // Room details
      GoRoute(
        path: '/room',
        builder: (context, state) {
          final room = state.extra as Room;
          return RoomDetailsScreen(room: room);
        },
      ),

      // Professor details
      GoRoute(
        path: '/professor',
        builder: (context, state) {
          final professor = state.extra as Professor;
          return ProfessorDetailsScreen(professor: professor);
        },
      ),

      // Event details
      GoRoute(
        path: '/event',
        builder: (context, state) {
          final event = state.extra as Event;
          return EventDetailsScreen(event: event);
        },
      ),
      // Navigation screen
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