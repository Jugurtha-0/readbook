import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bookio/pages/chat%20and%20friend%20requests/chat_page.dart';
import 'package:bookio/pages/chat%20and%20friend%20requests/create_group_page.dart';

class FriendsListPage extends StatelessWidget {
  static const Color primary = Color(0xFF4B4231);
  static const Color secondary = Color(0xFFE7C4A4);
  static const Color background = Color(0xFF1D1D1D);
  static const Color text = Color(0xFFF5F0E6);
  static const Color textSecondary = Color(0xFFD3C1A6);
  static const Color card = Color(0xFF2D2D2D);

  const FriendsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text("Messages", 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: text,
              fontSize: 24,
            )),
        backgroundColor: primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: text),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGroupPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: secondary,
              labelColor: text,
              unselectedLabelColor: textSecondary,
              tabs: [
                Tab(text: 'Amis'),
                Tab(text: 'Groupes'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildFriendsList(userId),
                  _buildGroupsList(userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(String? userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(secondary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text("Erreur de chargement des amis",
                style: TextStyle(color: textSecondary)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text("Aucun ami pour l'instant",
                style: TextStyle(color: textSecondary)),
          );
        }

        var friends = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          separatorBuilder: (context, index) => Divider(
            color: card.withOpacity(0.5),
            height: 16,
          ),
          itemBuilder: (context, index) {
            var friend = friends[index];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friend['friendId'])
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return ListTile(
                    title: Text("Chargement...",
                        style: TextStyle(color: textSecondary)),
                  );
                }

                if (userSnapshot.hasError) {
                  return ListTile(
                    title: Text("Erreur de chargement",
                        style: TextStyle(color: textSecondary)),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return ListTile(
                    title: Text("Utilisateur introuvable",
                        style: TextStyle(color: textSecondary)),
                  );
                }

                var user = userSnapshot.data!;
                Map<String, dynamic>? userData =
                    user.data() as Map<String, dynamic>?;

                String firstName = userData?['firstName'] ?? 'Inconnu';
                String lastName = userData?['lastName'] ?? '';
                String fullName = "$firstName $lastName";

                String avatarUrl = (userData != null &&
                        userData.containsKey('avatarUrl') &&
                        userData['avatarUrl'] != null)
                    ? userData['avatarUrl']
                    : "https://ui-avatars.com/api/?name=$firstName+$lastName&background=4B4231&color=E7C4A4";

                return Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: primary,
                      backgroundImage: NetworkImage(avatarUrl),
                      child: userData?['avatarUrl'] == null
                          ? Text(
                              '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                              style: const TextStyle(
                                  color: text, fontSize: 18),
                            )
                          : null,
                    ),
                    title: Text(
                      fullName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: text,
                          fontSize: 16),
                    ),
                    subtitle: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(friend['friendId'])
                          .snapshots(),
                      builder: (context, statusSnapshot) {
                        if (!statusSnapshot.hasData) {
                          return Text(
                            "Statut inconnu",
                            style: TextStyle(color: textSecondary),
                          );
                        }
                        final statusData = statusSnapshot.data!.data() as Map<String, dynamic>?;
                        final isOnline = statusData?['isOnline'] ?? false;
                        final lastSeen = statusData?['lastSeen'] as Timestamp?;
                        
                        return Text(
                          isOnline 
                              ? "En ligne" 
                              : "Vu dernièrement à ${_formatTime(lastSeen?.toDate() ?? DateTime.now())}",
                          style: TextStyle(color: textSecondary),
                        );
                      },
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.chat_bubble_outline,
                          color: secondary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              friendId: friend['friendId'],
                              friendName: fullName,
                              friendAvatar: avatarUrl,
                            ),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            friendId: friend['friendId'],
                            friendName: fullName,
                            friendAvatar: avatarUrl,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsList(String? userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('userId', isEqualTo: userId)
          .where('isGroup', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(secondary)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text("Erreur de chargement des groupes",
                style: TextStyle(color: textSecondary)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text("Aucun groupe pour l'instant",
                style: TextStyle(color: textSecondary)),
          );
        }

        var groups = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          separatorBuilder: (context, index) => Divider(
            color: card.withOpacity(0.5),
            height: 16,
          ),
          itemBuilder: (context, index) {
            var group = groups[index];
            var groupData = group.data() as Map<String, dynamic>;

            return Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: primary,
                  backgroundImage: groupData['groupAvatar'] != null
                      ? NetworkImage(groupData['groupAvatar'])
                      : null,
                  child: groupData['groupAvatar'] == null
                      ? Icon(Icons.group, color: text, size: 28)
                      : null,
                ),
                title: Text(
                  groupData['groupName'] ?? 'Groupe sans nom',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: text,
                      fontSize: 16),
                ),
                subtitle: Text(
                  groupData['lastMessage'] ?? '',
                  style: TextStyle(color: textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: groupData['unreadCount'] > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: secondary,
                        child: Text(
                          groupData['unreadCount'].toString(),
                          style: TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        friendId: groupData['groupId'],
                        friendName: groupData['groupName'],
                        friendAvatar: groupData['groupAvatar'] ?? '',
                        isGroup: true,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}