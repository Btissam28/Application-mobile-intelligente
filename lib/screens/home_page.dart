import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.teal),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage(
                      'assets/images/avatar.png',
                    ), // Replace with your asset path
                  ),

                  Text(
                    'Bakkar Btissam',
                    style: TextStyle(
                      color: Colors.white,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Btissam@gmail.com',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('classification'),
              onTap: () {
                // Navigate to Home Page
                Navigator.pop(context);
                Navigator.pushNamed(context, "/fruitsclassifier");
              },
            ),
            // Dans HomePage, modifiez le ListTile du chatbot
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Emsi CHATBOT'),
              onTap: () {
                Navigator.pop(context); // Fermer le drawer
                Navigator.pushNamed(
                  context,
                  "/chatbot",
                ); // Naviguer vers le chatbot
              },
            ),
            Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Profile'),
              onTap: () {
                // Navigate to Profile Page
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              trailing: const Icon(Icons.arrow_forward),
              title: const Text('Settings'),
              onTap: () {
                // Navigate to Settings Page
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                // Handle logout action
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text(
          'Welcome to the Home Page!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
