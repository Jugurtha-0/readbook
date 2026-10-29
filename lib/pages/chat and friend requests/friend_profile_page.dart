import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';

class FriendProfilePage extends StatelessWidget {
  final String userId;

  const FriendProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Profil de l'ami"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.text,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}";
          final bio = data['pio'] ?? '';
          final email = data['email'] ?? '';
          final dob = data['dateOfBirth'] ?? '';
          final isOnline = data['isOnline'] == true;
          final photoUrl = data['profileImageUrl'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(name,
                      style: const TextStyle(fontSize: 24, color: AppColors.text)),
                ),
                const SizedBox(height: 10),
                _infoLine("Bio", bio),
                _infoLine("Email", email),
                _infoLine("Date de naissance", dob),
                _infoLine("Statut", isOnline ? "En ligne" : "Hors ligne"),

                const SizedBox(height: 30),
                const Text(
                  "Publications",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 10),
                _buildPosts(userId),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label : ",
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
          Flexible(child: Text(value, style: const TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildPosts(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text("Aucune publication", style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return Column(
          children: posts.map((post) {
            final postData = post.data() as Map<String, dynamic>;
            final content = postData['content'] ?? '';
            final createdAt = (postData['createdAt'] as Timestamp?)?.toDate();

            return Card(
              color: AppColors.card,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(content, style: const TextStyle(color: AppColors.text)),
                subtitle: createdAt != null
                    ? Text(
                        "${createdAt.day}/${createdAt.month}/${createdAt.year}",
                        style: const TextStyle(color: AppColors.textSecondary),
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}