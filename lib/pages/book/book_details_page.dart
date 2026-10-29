import 'package:flutter/material.dart';
import 'package:bookio/book.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class BookDetailsPage extends StatefulWidget {
  final Book book;

  const BookDetailsPage({super.key, required this.book});

  @override
  _BookDetailsPageState createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  static const Color primary = Color(0xFF4B4231); // Marron foncé
  static const Color secondary = Color(0xFFE7C4A4); // Beige pâle
  static const Color background = Color(0xFF1D1D1D); // Gris très foncé
  static const Color text = Color(0xFFF5F0E6); // Crème clair
  static const Color textSecondary = Color(0xFFD3C1A6); // Beige doré
  static const Color card = Color(0xFF2D2D2D); // Gris foncé

  double _rating = 0;
  String _readingStatus = "À lire";

  void _showCritiqueDialog(BuildContext context) {
  final TextEditingController critiqueController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Écrire une critique"),
      content: TextField(
        controller: critiqueController,
        maxLines: 5,
        decoration: InputDecoration(hintText: "Votre avis sur ce livre..."),
      ),
      actions: [
        TextButton(
          child: Text("Annuler"),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text("Publier"),
          onPressed: () async {
            final critique = critiqueController.text.trim();
            if (critique.isNotEmpty) {
              await FirebaseFirestore.instance.collection('posts').add({
                'userId': FirebaseAuth.instance.currentUser?.uid,
                'text': critique,
                'imageUrl': widget.book.imageUrl,
                'timestamp': FieldValue.serverTimestamp(),
                'likes': {},
                'type': 'critique',
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Critique publiée avec succès !")),
              );
            }
          },
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(widget.book.title, style: TextStyle(color: text)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: text),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'book-cover-${widget.book.id}',
              child: Container(
                width: double.infinity,
                height: 300,
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  image: widget.book.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(widget.book.imageUrl),
                          fit: BoxFit.contain,
                        )
                      : null,
                  color: card,
                ),
                child: widget.book.imageUrl.isEmpty
                    ? Center(
                        child: Icon(Icons.book, size: 100, color: textSecondary),
                      )
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Par ${widget.book.author}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Résumé",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.book.description.isNotEmpty
                        ? widget.book.description
                        : "Aucun résumé disponible",
                    style: TextStyle(
                      fontSize: 16,
                      color: textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Notez ce livre",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: secondary,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Statut de lecture",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary),
                    ),
                    child: DropdownButton<String>(
                      value: _readingStatus,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: text),
                      style: TextStyle(
                        fontSize: 16,
                        color: text,
                      ),
                      dropdownColor: card,
                      onChanged: (String? newValue) {
                        setState(() {
                          _readingStatus = newValue!;
                        });
                      },
                      items: ["À lire", "En train de lire", "Déjà lu"]
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: TextStyle(color: text)),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () => _showCritiqueDialog(context),
    icon: Icon(Icons.edit, color: text),
    label: Text(
      "Critiquer ce livre",
      style: TextStyle(color: text, fontWeight: FontWeight.bold),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: secondary,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
),
const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Enregistrer",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}