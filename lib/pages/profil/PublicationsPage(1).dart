import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_colors.dart';

class PublicationsPage extends StatefulWidget {
  const PublicationsPage({super.key});

  @override
  _PublicationsPageState createState() => _PublicationsPageState();
}

class _PublicationsPageState extends State<PublicationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? user;
  String profileImageUrl = '';
  String firstName = '';
  String lastName = '';

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user!.uid).get();
      setState(() {
        firstName = userDoc.get('firstName') ?? '';
        lastName = userDoc.get('lastName') ?? '';
        profileImageUrl = userDoc.get('profileImageUrl') ?? '';
      });
    }
  }

  Future<void> _toggleLike(String postId, Map<String, dynamic> postData, bool isLiked) async {
    final postRef = _firestore.collection('posts').doc(postId);
    List likedBy = postData['likedBy'] ?? [];

    if (isLiked) {
      likedBy.remove(user!.uid);
    } else {
      likedBy.add(user!.uid);
    }

    await postRef.update({
      'likedBy': likedBy,
      'likes': likedBy.length,
    });
  }

  void _showComments(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        TextEditingController commentController = TextEditingController();

        return Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('posts')
                    .doc(postId)
                    .collection('comments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: AppColors.secondary));
                  }
                  var comments = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      var comment = comments[index];
                      var data = comment.data() as Map<String, dynamic>;

                      return ListTile(
                        title: Text(data['comment'], style: TextStyle(color: AppColors.text)),
                        subtitle: Text(data['username'] ?? '', style: TextStyle(color: AppColors.textSecondary)),
                      );
                    },
                  );
                },
              ),
            ),
            Divider(color: AppColors.textSecondary.withOpacity(0.3)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      style: TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: AppColors.secondary),
                    onPressed: () async {
                      if (commentController.text.isNotEmpty) {
                        await _firestore.collection('posts').doc(postId).collection('comments').add({
                          'comment': commentController.text.trim(),
                          'username': '$firstName $lastName',
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        commentController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mes Publications', style: TextStyle(color: AppColors.text)),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppColors.secondary));
          }

          final posts = snapshot.data!.docs;
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'Aucune publication trouvée',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final postData = post.data() as Map<String, dynamic>;
              final isLiked = (postData['likedBy'] ?? []).contains(user?.uid);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondary,
                        backgroundImage: profileImageUrl.isNotEmpty
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl.isEmpty
                            ? Icon(Icons.person, color: AppColors.primary)
                            : null,
                      ),
                      title: Text(
                        '$firstName $lastName',
                        style: TextStyle(color: AppColors.text),
                      ),
                    ),
                    if (postData['imageUrl'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          postData['imageUrl'],
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (postData['title'] != null)
                            Text(
                              postData['title'],
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (postData['description'] != null)
                            Text(
                              postData['description'],
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : AppColors.textSecondary,
                                ),
                                onPressed: () => _toggleLike(post.id, postData, isLiked),
                              ),
                              Text(
                                '${postData['likes'] ?? 0}',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: Icon(Icons.comment, color: AppColors.textSecondary),
                                onPressed: () => _showComments(context, post.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}