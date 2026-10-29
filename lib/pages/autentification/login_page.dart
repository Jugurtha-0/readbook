import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bookio/componenets/my_button.dart';
import 'package:bookio/componenets/my_textfield.dart';
import 'package:bookio/pages/autentification/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Erreur"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void signUserIn() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      if (e.code == 'user-not-found') {
        showErrorDialog("L'email est incorrect.");
      } else if (e.code == 'wrong-password') {
        showErrorDialog("Le mot de passe est incorrect.");
      } else if (e.code == 'invalid-email') {
        showErrorDialog("Format de l'email invalide.");
      } else if (e.code == 'invalid-credential') {
        showErrorDialog("L'email ou le mot de passe est incorrect.");
      } else {
        showErrorDialog("Erreur : ${e.message}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/assets/images/login_background.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: SingleChildScrollView(
  reverse: true,
  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.book, size: 100, color: Colors.brown),
      const SizedBox(height: 30),
      const Text(
        "Connexion à ReedBook",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              blurRadius: 5,
              color: Colors.black,
              offset: Offset(2, 2),
            ),
          ],
        ),
      ),
      const SizedBox(height: 50),
      MyTextfield(
        controller: emailController,
        hintText: 'E-mail',
        obscuretext: false,
      ),
      const SizedBox(height: 10),
      MyTextfield(
        controller: passwordController,
        hintText: 'Mot de passe',
        obscuretext: true,
      ),
      const SizedBox(height: 10),

      const SizedBox(height: 20),
      MyButton(onTap: signUserIn, text: "Connexion"),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Pas encore membre?", style: TextStyle(color: Colors.white)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterPage()),
              );
            },
            child: const Text(
              "Inscrivez-vous",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
        ],
      ),
    ],
  ),
),

              ),
            ),
          ),
        ],
      ),
    );
  }
}
