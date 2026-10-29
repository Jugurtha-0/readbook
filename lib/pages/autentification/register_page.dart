import 'dart:io';
import 'package:bookio/pages/autentification/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  XFile? _profileImage;

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    _profileImage = await picker.pickImage(source: ImageSource.gallery);
    setState(() {});
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_profileImage == null) return null;
    final ref = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
    await ref.putFile(File(_profileImage!.path));
    return await ref.getDownloadURL();
  }

  void _signUp() async {
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas!")),
      );
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String? imageUrl = await _uploadProfileImage(userCredential.user!.uid);

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'dateOfBirth': _dateOfBirthController.text.trim(),
        'email': _emailController.text.trim(),
        'bio': _bioController.text.trim(),
        'profileImageUrl': imageUrl ?? '',
        'role': 'user', // Rôle ajouté automatiquement
        'createdAt': FieldValue.serverTimestamp(),
      });

      await userCredential.user!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email de vérification envoyé!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const  AuthPage()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Erreur")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("lib/assets/images/login_background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildNamePage(),
                  _buildBirthDatePage(),
                  _buildEmailPage(),
                  _buildPasswordPage(),
                  _buildProfilePage(),
                  _buildFinalPage(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return _buildPage([
      _buildTextField(_firstNameController, "Prénom"),
      _buildTextField(_lastNameController, "Nom"),
      _nextButton(),
    ]);
  }

  Widget _buildBirthDatePage() {
    return _buildPage([
      _buildTextField(_dateOfBirthController, "Date de naissance", readOnly: true, onTap: _selectDate),
      _nextButton(),
    ]);
  }

  Widget _buildEmailPage() {
    return _buildPage([
      _buildTextField(_emailController, "Email"),
      _nextButton(),
    ]);
  }

  Widget _buildPasswordPage() {
    return _buildPage([
      _buildTextField(_passwordController, "Mot de passe", obscureText: true),
      _buildTextField(_confirmPasswordController, "Confirmer", obscureText: true),
      _nextButton(),
    ]);
  }

  Widget _buildProfilePage() {
    return _buildPage([
      ElevatedButton(
        onPressed: _pickImage,
        child: const Text("Choisir une photo de profil"),
      ),
      if (_profileImage != null) Image.file(File(_profileImage!.path), height: 100),
      _buildTextField(_bioController, "Biographie"),
      _nextButton(),
    ]);
  }

  Widget _buildFinalPage() {
    return _buildPage([
      const Text("Appuyez pour créer un compte", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ElevatedButton(
        onPressed: _signUp,
        child: const Text("Créer un compte"),
      ),
    ]);
  }

  Widget _buildPage(List<Widget> children) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildTextField(TextEditingController controller, String hintText,
      {bool obscureText = false, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _nextButton() {
    return ElevatedButton(
      onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
      child: const Text("Suivant"),
    );
  }
}