import 'package:go_router/go_router.dart';
import '../../modules/bookshelf/home_screen.dart';
import '../../modules/reader/reader_page.dart';
import '../../modules/home/splash_page.dart';
import '../../modules/admin/admin_panel.dart';

// 全局唯一的 Router 配置
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/reader/:bookId',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId']!;
        return ReaderPage(bookId: bookId);
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminPanel(),
    ),
  ],
);
