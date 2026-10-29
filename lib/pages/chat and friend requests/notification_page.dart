import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart'; // ← importe ta palette
import 'friend_profile_page.dart'; // ← à créer

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> _acceptFriendRequest(BuildContext context, String requestId, String senderId, String receiverId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(receiverId).collection('friends').doc(senderId).set({
        'friendId': senderId,
        'addedAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance.collection('users').doc(senderId).collection('friends').doc(receiverId).set({
        'friendId': receiverId,
        'addedAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({'status': 'accepted'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ami ajouté avec succès")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    }
  }

  Future<void> _declineFriendRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();
  }

  @override
  Widget build(BuildContext context) {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.text,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('friend_requests')
            .where('receiverId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucune invitation", style: TextStyle(color: AppColors.text)));
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final senderId = request['senderId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(title: Text("Chargement...", style: TextStyle(color: AppColors.text)));
                  }

                  final data = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}";
                  final photoUrl = data['profileImageUrl'];

                  return Card(
                    color: AppColors.card,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FriendProfilePage(userId: senderId)),
                          );
                        },
                        child: CircleAvatar(
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
                        ),
                      ),
                      title: Text(name, style: const TextStyle(color: AppColors.text)),
                      subtitle: const Text("Vous a envoyé une demande d'ami", style: TextStyle(color: AppColors.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () {
                              _acceptFriendRequest(context, request.id, senderId, userId!);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              _declineFriendRequest(request.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
