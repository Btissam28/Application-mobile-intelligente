import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/chatbot_page.dart';
import 'screens/fruitsclassifier_page.dart'; // ✅ Ajoute cet import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Bakkar_App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/chatbot': (context) => const ChatbotPage(),
        '/fruitsclassifier': (context) =>
            const FruitsClassifierPage(), // ✅ Ajoute cette ligne
      },
    );
  }
}
