import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_presets.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    debugPrint('--- [Splash] 页面 initState 开始 ---');

    Future.delayed(const Duration(milliseconds: 2000), () {
      debugPrint('--- [Splash] 2秒延时结束，检查 mounted 状态：$mounted ---');
      if (mounted) {
        debugPrint('--- [Splash] 准备执行 context.go ---');
        context.go('/');
        debugPrint('--- [Splash] context.go 执行完毕 ---');
      }
    });

    debugPrint('--- [Splash] 页面 initState 同步逻辑执行完毕 ---');
  }

  @override
  Widget build(BuildContext context) {
    final nyan = resolveNyanTheme(Theme.of(context));
    final splashAsset = nyan.brightness == Brightness.dark
        ? 'assets/images/splash_screen_dark.png'
        : 'assets/images/splash_screen.png';

    return Scaffold(
      backgroundColor: nyan.background,
      body: Center(
        child: Image.asset(
          splashAsset,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
