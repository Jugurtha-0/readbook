import 'package:bookio/pages/home/home_page2.dart';
import 'package:bookio/pages/autentification/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookio/pages/admin/page_ban.dart';
import 'package:bookio/pages/admin/admin_dashboard.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            final uid = snapshot.data!.uid;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return Center(child: Text('Erreur : ${userSnapshot.error ?? "Utilisateur non trouvé"}'));
                }

                final rawData = userSnapshot.data!.data();
                print("User data: $rawData");

                if (rawData == null) {
                  return const Center(child: Text('Données utilisateur manquantes.'));
                }

                final data = rawData as Map<String, dynamic>;
                final isBanned = data['isBanned'] == true;
                final banUntil = (data['banUntil'] as Timestamp?)?.toDate();
                final role = data['role'] ?? 'user';

                if (isBanned && (banUntil == null || banUntil.isAfter(DateTime.now()))) {
                  return const BannedScreen();
                }

                if (role == 'admin') {
                  return const AdminDashboard();
                } else {
                  return const HomePage();
                }
              },
            );
          }

          return const LoginPage();
        },
      ),
    );
  }
}
