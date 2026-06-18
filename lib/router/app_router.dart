import 'package:fileflow/features/home/home_screen.dart';
import 'package:fileflow/features/onboarding/onboarding_screen.dart';
import 'package:fileflow/features/recycle_bin/recycle_bin_screen.dart';
import 'package:fileflow/features/swipe_cleanup/batch_deletion_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!onboardingDone && state.matchedLocation != '/onboarding') {
      return '/onboarding';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/recycle-bin',
      builder: (context, state) => const RecycleBinScreen(),
    ),
    GoRoute(
      path: '/batch-deletion',
      builder: (context, state) => const BatchDeletionScreen(),
    ),
  ],
);
