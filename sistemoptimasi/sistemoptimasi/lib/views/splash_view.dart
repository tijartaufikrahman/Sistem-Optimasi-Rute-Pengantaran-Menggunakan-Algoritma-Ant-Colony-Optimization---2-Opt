import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'login_view.dart';
import 'main_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {

  final StorageService storage = StorageService();

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  void checkLogin() async {

    String? token = await storage.getToken();

    if (token != null) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainView()),
      );

    } else {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginView()),
      );

    }

  }

  @override
  Widget build(BuildContext context) {

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );

  }
}
