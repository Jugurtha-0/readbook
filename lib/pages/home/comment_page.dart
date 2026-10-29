import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppColors {
  static const Color primary = Color(0xFF4B4231); // Marron foncé
  static const Color secondary = Color(0xFFE7C4A4); // Beige pâle
  static const Color background = Color(0xFF1D1D1D); // Gris très foncé
  static const Color text = Color(0xFFF5F0E6); // Crème clair
  static const Color textSecondary = Color(0xFFD3C1A6); // Beige doré
  static const Color card = Color(0xFF2D2D2D); // Gris foncé
}

class CommentPage extends StatefulWidget {
  final String postId;

  const CommentPage({super.key, required this.postId});

  @override
  _CommentPageState createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final TextEditingController _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final commentText = _commentController.text.trim();
    
    if (userId == null || commentText.isEmpty) return;

    try {
     await FirebaseFirestore.instance
    .collection('posts')
    .doc(widget.postId)
    .collection('comments')
    .add({
  'userId': userId,
  'text': commentText,
  'timestamp': FieldValue.serverTimestamp(),
});

// Mettre à jour le compteur
await FirebaseFirestore.instance
    .collection('posts')
    .doc(widget.postId)
    .update({
  'commentCount': FieldValue.increment(1),
});

     

      _commentController.clear();
      // Scroll vers le bas pour voir le nouveau commentaire
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi du commentaire: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
   

   
     

  }

  Future<Map<String, String>> _getUserInfo(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return {
          'fullName': '${userDoc['firstName'] ?? ''} ${userDoc['lastName'] ?? ''}',
          'profileImageUrl': userDoc['profileImageUrl'] ?? '',
        };
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération des informations de l'utilisateur: $e");
    }
    return {
      'fullName': "Utilisateur inconnu",
      'profileImageUrl': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Commentaires",
          style: TextStyle(color: AppColors.text),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.secondary),
      ),
      body: Column(
        children: [
          // Liste des commentaires
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun commentaire pour le moment',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                final comments = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Pour avoir les nouveaux commentaires en bas
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index].data() as Map<String, dynamic>;
                    final userId = comment['userId'];

                    return FutureBuilder<Map<String, String>>(
                      future: _getUserInfo(userId),
                      builder: (context, userSnapshot) {
                        final fullName = userSnapshot.data?['fullName'] ?? "Chargement...";
                        final profileImageUrl = userSnapshot.data?['profileImageUrl'] ?? '';

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              backgroundImage: profileImageUrl.isNotEmpty
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                              child: profileImageUrl.isEmpty
                                  ? const Icon(Icons.person, color: AppColors.secondary)
                                  : null,
                            ),
                            title: Text(
                              comment['text'],
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              fullName,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Text(
                              _formatTimestamp(comment['timestamp']),
                              style: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Champ d'écriture pour ajouter un commentaire
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.primary.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: "Écrire un commentaire...",
                      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.primary.withOpacity(0.2),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: AppColors.secondary),
                    onPressed: _addComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'À l\'instant';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min';
    if (difference.inHours < 24) return '${difference.inHours} h';
    if (difference.inDays < 7) return '${difference.inDays} j';

    return '${date.day}/${date.month}/${date.year}';
  }
}