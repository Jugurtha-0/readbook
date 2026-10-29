import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bookio/pages/pdf_viewer_page.dart';

class PostDetailPage extends StatelessWidget {
  final Map<String, dynamic> postData;
  final String authorName;

  const PostDetailPage({
    super.key,
    required this.postData,
    required this.authorName,
  });

  // Couleurs statiques comme dans votre demande
  static const Color primary = Color(0xFF4B4231); // Marron foncé
  static const Color secondary = Color(0xFFE7C4A4); // Beige pâle
  static const Color background = Color(0xFF1D1D1D); // Gris très foncé
  static const Color text = Color(0xFFF5F0E6); // Crème clair
  static const Color textSecondary = Color(0xFFD3C1A6); // Beige doré
  static const Color card = Color(0xFF2D2D2D); // Gris foncé

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
      print('Tentative d\'ouverture du PDF : $url');
    } else {
      throw 'Impossible d\'ouvrir le lien PDF : $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLivre = postData['type'] == 'livre';
    final String? pdfUrl = postData['pdfUrl'];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text(
          "Détails du post",
          style: TextStyle(color: text),
        ),
        elevation: 4,
        iconTheme: const IconThemeData(color: text),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: card,
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (postData['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        postData['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    postData['title'] ?? 'Sans titre',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Auteur : $authorName",
                    style: const TextStyle(
                      fontSize: 16,
                      color: textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Divider(height: 24, thickness: 1.2, color: textSecondary),
                  Text(
                    postData['description'] ?? 'Pas de description',
                    style: const TextStyle(fontSize: 16, color: text),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Type : ${postData['type'] ?? 'Inconnu'}",
                    style: const TextStyle(fontSize: 14, color: textSecondary),
                  ),
                  const SizedBox(height: 12),

                  // Bouton PDF
                  if (isLivre && pdfUrl != null && pdfUrl.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfViewerPage(url: pdfUrl),
                          ),
                        );
},
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Ouvrir le PDF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: text,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
