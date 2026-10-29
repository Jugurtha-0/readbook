import 'package:flutter/material.dart';

class ImageViewer extends StatelessWidget {
  final String imageUrl;

  const ImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // ✅ Fond noir pour une meilleure visibilité
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // ✅ Bouton retour
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer( // ✅ Permet de zoomer/dézoomer
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain, // ✅ Affiche l’image sans la couper
          ),
        ),
      ),
    );
  }
}
