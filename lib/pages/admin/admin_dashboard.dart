import 'package:bookio/pages/autentification/auth_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:async/async.dart';
import 'package:bookio/pages/admin/post_detail_page.dart';
import 'package:bookio/pages/pdf_viewer_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Color primary = Color(0xFF4B4231); // Marron foncé
  static const Color secondary = Color(0xFFE7C4A4); // Beige pâle
  static const Color background = Color(0xFF1D1D1D); // Gris très foncé
  static const Color text = Color(0xFFF5F0E6); // Crème clair
  static const Color textSecondary = Color(0xFFD3C1A6); // Beige doré
  static const Color card = Color(0xFF2D2D2D); // Gris foncé

  String _searchQuery = "";
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: const Text('Tableau de Bord Admin'),
          backgroundColor: primary,
          elevation: 4,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearchDialog(context),
            ),
          ],
          bottom: TabBar(
            labelColor: text,
            unselectedLabelColor: textSecondary,
            indicatorColor: secondary,
            tabs: const [
              Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
              Tab(icon: Icon(Icons.post_add), text: 'Publications'),
              Tab(icon: Icon(Icons.report), text: 'Signalements'),
              Tab(icon: Icon(Icons.analytics), text: 'Statistiques'),
              Tab(icon: Icon(Icons.block), text: 'Bannis'),
              Tab(icon: Icon(Icons.logout), text: 'Logout'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersTab(),
            _buildPostsTab(),
            _buildReportsTab(),
            _buildStatsTab(),
            _buildBannedUsersTab(),
            _buildLogout(context),
            
          ],
        ),
      ),
    );
  }

Widget _buildLogout(BuildContext context) {
  return Center(
    child: ElevatedButton.icon(
      icon: Icon(Icons.logout),
      label: Text('Se déconnecter'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async {
        try {
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AuthPage()),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la déconnexion : $e')),
          );
        }
      },
    ),
  );
}


  Widget _buildUsersTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: secondary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: text)));
              }

              final users = snapshot.data!.docs;

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final data = user.data() as Map<String, dynamic>;

                  final firstName = data['firstName'] ?? 'Non renseigné';
                  final lastName = data['lastName'] ?? '';
                  final email = data['email'] ?? 'Non renseigné';
                  final photoUrl = data['profileImageUrl'] ?? data['photoUrl'];
                  final role = data['role'] ?? 'user';
                  final lastLogin = data['lastLogin'] != null 
                      ? DateFormat('dd/MM/yyyy HH:mm').format((data['lastLogin'] as Timestamp).toDate())
                      : 'Jamais';

                  return Card(
                    color: card,
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl.toString()) : null,
                        child: photoUrl == null ? Text(firstName.substring(0, 1)) : null,
                      ),
                      title: Text('$firstName $lastName', style: TextStyle(color: text)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: TextStyle(color: textSecondary)),
                          Text('Rôle: ${role.toUpperCase()}', style: TextStyle(color: _getRoleColor(role))),
                          Text('Dernière connexion: $lastLogin', style: TextStyle(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: text),
                        onSelected: (value) => _handleUserAction(value, user.id, data),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'details',
                            child: Text('Voir détails')),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Modifier rôle')),
                          const PopupMenuItem(
                            value: 'verify',
                            child: Text('Vérifier email')),
                          if (data['isBanned'] != true)
                            const PopupMenuItem(
                              value: 'ban',
                              child: Text('Bannir', style: TextStyle(color: Colors.red))),
                          if (data['isBanned'] == true)
                            const PopupMenuItem(
                              value: 'unban',
                              child: Text('Débannir', style: TextStyle(color: Colors.green))),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBannedUsersTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').where('isBanned', isEqualTo: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: secondary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: text)));
              }

              final users = snapshot.data!.docs;

              if (users.isEmpty) {
                return Center(child: Text('Aucun utilisateur banni.', style: TextStyle(color: text)));
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final data = user.data() as Map<String, dynamic>;

                  final banReason = data['banReason'] ?? 'Raison non spécifiée';
                  final banUntil = data['banUntil'] != null 
                      ? DateFormat('dd/MM/yyyy').format((data['banUntil'] as Timestamp).toDate())
                      : 'Permanent';

                  return Card(
                    color: card,
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text('${data['firstName']} ${data['lastName']}', style: TextStyle(color: text)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['email'] ?? '', style: TextStyle(color: textSecondary)),
                          Text('Raison: $banReason', style: TextStyle(color: Colors.orange)),
                          Text('Jusqu\'à: $banUntil', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () => _unbanUser(user.id),
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Débannir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondary,
                          foregroundColor: primary,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('posts').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: secondary));
              }

              final posts = snapshot.data!.docs;

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final data = post.data() as Map<String, dynamic>;
                  final userId = data['userId'];

                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(userId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      final authorName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';

                      return Card(
                        color: card,
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(data['title'] ?? 'Sans titre', style: TextStyle(color: text)),
                          subtitle: Text('Par: $authorName', style: TextStyle(color: textSecondary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye),
                                color: secondary,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailPage(
                                        postData: data, 
                                        authorName: authorName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                color: Colors.red,
                                onPressed: () => _confirmDeletePost(post.id),
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
        ),
      ],
    );
  }

 Widget _buildReportsTab() {
  return Column(
    children: [
      _buildSearchBar(),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('reports')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: secondary));
            }

            final reports = snapshot.data!.docs;

            return ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final data = report.data() as Map<String, dynamic>;
                final severity = data['severity'] ?? 1;
                final status = data['status'] ?? 'pending';
                final userId = data['userId'];
                final postId = data['postId'];

                return FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait([
                    _firestore.collection('users').doc(userId).get(), // reporter
                    _firestore.collection('posts').doc(postId).get(), // post
                  ]),
                  builder: (context, userPostSnapshot) {
                    if (!userPostSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final userDoc = userPostSnapshot.data![0];
                    final postDoc = userPostSnapshot.data![1];

                    final reporterData = userDoc.data() as Map<String, dynamic>? ?? {};
                    final postData = postDoc.data() as Map<String, dynamic>? ?? {};

                    final reporterName = '${reporterData['firstName'] ?? ''} ${reporterData['lastName'] ?? ''}'.trim().isEmpty
                        ? 'Utilisateur inconnu'
                        : '${reporterData['firstName']} ${reporterData['lastName']}';

                    final postTitle = postData['title'] ?? 'Titre non disponible';
                    final postAuthorId = postData['userId'];

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(postAuthorId).get(),
                      builder: (context, authorSnapshot) {
                        if (!authorSnapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final authorData = authorSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final authorName = '${authorData['firstName'] ?? ''} ${authorData['lastName'] ?? ''}'.trim().isEmpty
                            ? 'Auteur inconnu'
                            : '${authorData['firstName']} ${authorData['lastName']}';

                        return Card(
                          color: _getReportCardColor(status, severity),
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              'Signalement sur: "$postTitle"',
                              style: TextStyle(
                                color: status == 'resolved' ? Colors.grey : text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Par: $reporterName - Gravité: ${'⭐' * severity}',
                              style: TextStyle(color: textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 'pending')
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () => _resolveReport(report.id),
                                  ),
                                if (status == 'pending')
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => _dismissReport(report.id),
                                  ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Raison: ${data['reason'] ?? 'Non spécifiée'}',
                                        style: TextStyle(color: text)),
                                    const SizedBox(height: 8),
                                    Text('Signalé par: $reporterName',
                                        style: TextStyle(color: textSecondary)),
                                    const SizedBox(height: 8),
                                    Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(
                                        (data['timestamp'] as Timestamp).toDate())}',
                                        style: TextStyle(color: textSecondary)),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PostDetailPage(
                                              postData: postData,
                                              authorName: authorName,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primary,
                                        foregroundColor: text,
                                      ),
                                      child: const Text('Voir le contenu signalé'),
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
                );
              },
            );
          },
        ),
      ),
    ],
  );
}


  Widget _buildStatsTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<List<QuerySnapshot>>(
            stream: StreamZip([
              _firestore.collection('users').snapshots(),
              _firestore.collection('posts').snapshots(),
              _firestore.collection('reports').snapshots(),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: secondary));
              }

              final users = snapshot.data![0].docs;
              final posts = snapshot.data![1].docs;
              final reports = snapshot.data![2].docs;

              final userCount = users.length;
              final bannedCount = users.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isBanned'] == true;
              }).length;

              final postCount = posts.length;
              final reportCount = reports.length;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatCard('👤 Utilisateurs', userCount, Colors.blue),
                    const SizedBox(height: 12),
                    _buildStatCard('🔒 Utilisateurs bannis', bannedCount, Colors.orange),
                    const SizedBox(height: 12),
                    _buildStatCard('📝 Publications', postCount, Colors.green),
                    const SizedBox(height: 12),
                    _buildStatCard('🚩 Signalements', reportCount, Colors.red),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher...',
          hintStyle: TextStyle(color: textSecondary),
          prefixIcon: Icon(Icons.search, color: textSecondary),
          filled: true,
          fillColor: card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        style: TextStyle(color: text),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Card(
      color: card,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          child: Text(count.toString()),
        ),
        title: Text(label, style: TextStyle(color: text)),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'moderator':
        return Colors.orange;
      case 'editor':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  Color _getReportCardColor(String status, int severity) {
    if (status == 'resolved') return Colors.grey.withOpacity(0.3);
    if (status == 'dismissed') return Colors.grey.withOpacity(0.5);
    
    switch (severity) {
      case 1:
        return card;
      case 2:
        return Colors.orange.withOpacity(0.3);
      case 3:
        return Colors.red.withOpacity(0.3);
      default:
        return card;
    }
  }

  Future<void> _handleUserAction(String action, String userId, Map<String, dynamic> userData) async {
    switch (action) {
      case 'details':
        _showUserDetails(userId, userData);
        break;
      case 'edit':
        _editUserRole(userId, userData['role'] ?? 'user');
        break;
      case 'verify':
        _verifyUser(userId);
        break;
      case 'ban':
        _banUser(userId);
        break;
      case 'unban':
        _unbanUser(userId);
        break;
    }
  }

  Future<void> _showUserDetails(String userId, Map<String, dynamic> userData) async {
    final postsCount = await _firestore.collection('posts')
        .where('userId', isEqualTo: userId)
        .count()
        .get()
        .then((value) => value.count);

    final reportsCount = await _firestore.collection('reports')
        .where('reportedUserId', isEqualTo: userId)
        .count()
        .get()
        .then((value) => value.count);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          title: Text('Détails utilisateur', style: TextStyle(color: text)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userData['profileImageUrl'] != null)
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(userData['profileImageUrl']),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Nom: ${userData['firstName']} ${userData['lastName']}', 
                    style: TextStyle(color: text)),
                Text('Email: ${userData['email']}', style: TextStyle(color: text)),
                Text('Rôle: ${userData['role'] ?? 'user'}', 
                    style: TextStyle(
                      color: _getRoleColor(userData['role'] ?? 'user'),
                      fontWeight: FontWeight.bold,
                    )),
                const Divider(),
                Text('Statistiques:', style: TextStyle(
                  color: text,
                  fontWeight: FontWeight.bold,
                )),
                Text('Publications: $postsCount', style: TextStyle(color: text)),
                Text('Signalements reçus: $reportsCount', style: TextStyle(color: text)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fermer', style: TextStyle(color: secondary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editUserRole(String userId, String currentRole) async {
    final roles = ['user', 'editor', 'moderator', 'admin'];
    String? newRole = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          title: Text('Modifier le rôle', style: TextStyle(color: text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.map((role) {
              return RadioListTile<String>(
                title: Text(role.toUpperCase(), style: TextStyle(color: text)),
                value: role,
                groupValue: currentRole,
                onChanged: (value) {
                  Navigator.pop(context, value);
                },
              );
            }).toList(),
          ),
        );
      },
    );

    if (newRole != null && newRole != currentRole) {
      try {
        await _firestore.collection('users').doc(userId).update({'role': newRole});
        _showSnackBar('Rôle mis à jour avec succès');
      } catch (e) {
        _showSnackBar('Erreur lors de la mise à jour du rôle: $e');
      }
    }
  }

  Future<void> _banUser(String userId) async {
    final reasonController = TextEditingController();
    final duration = await showDialog<Duration>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          title: Text('Bannir l\'utilisateur', style: TextStyle(color: text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Raison du bannissement',
                  labelStyle: TextStyle(color: textSecondary),
                ),
                style: TextStyle(color: text),
              ),
              const SizedBox(height: 20),
              Text('Durée du bannissement:', style: TextStyle(color: text)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, const Duration(days: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: text,
                    ),
                    child: const Text('1 jour'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, const Duration(days: 7)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: text,
                    ),
                    child: const Text('1 semaine'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, const Duration(days: 30)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: text,
                    ),
                    child: const Text('1 mois'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, Duration(days: 365 * 100)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: text,
                    ),
                    child: const Text('Permanent'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (duration != null) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'isBanned': true,
          'banReason': reasonController.text,
          'banUntil': duration.inDays > 365 * 99 
              ? null 
              : Timestamp.fromDate(DateTime.now().add(duration)),
        });
        _showSnackBar('Utilisateur banni avec succès');
      } catch (e) {
        _showSnackBar('Erreur lors du bannissement: $e');
      }
    }
  }

  Future<void> _unbanUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': false,
        'banReason': null,
        'banUntil': null,
      });
      _showSnackBar('Utilisateur débanni avec succès');
    } catch (e) {
      _showSnackBar('Erreur lors du débannissement: $e');
    }
  }

  Future<void> _verifyUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isEmailVerified': true,
      });
      _showSnackBar('Email vérifié avec succès');
    } catch (e) {
      _showSnackBar('Erreur lors de la vérification: $e');
    }
  }

  Future<void> _confirmDeletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          title: Text('Confirmer la suppression', style: TextStyle(color: text)),
          content: Text('Êtes-vous sûr de vouloir supprimer cette publication?', 
              style: TextStyle(color: text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Annuler', style: TextStyle(color: secondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('posts').doc(postId).delete();
        _showSnackBar('Publication supprimée avec succès');
      } catch (e) {
        _showSnackBar('Erreur lors de la suppression: $e');
      }
    }
  }

  Future<void> _resolveReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': 'admin',
      });
      _showSnackBar('Signalement résolu');
    } catch (e) {
      _showSnackBar('Erreur lors de la résolution: $e');
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'dismissed',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': 'admin',
      });
      _showSnackBar('Signalement ignoré');
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ignorance: $e');
    }
  }

  Future<void> _viewReportedContent(Map<String, dynamic> reportData) async {
    final contentId = reportData['contentId'];
    final contentType = reportData['contentType'] ?? 'post';

    if (contentType == 'post') {
      final postDoc = await _firestore.collection('posts').doc(contentId).get();
      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final userId = postData['userId'];
        
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() as Map<String, dynamic>;
        final authorName = '${userData['firstName']} ${userData['lastName']}';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(
              postData: postData,
              authorName: authorName,
            ),
          ),
        );
      } else {
        _showSnackBar('Le contenu signalé n\'existe plus');
      }
    }
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final searchType = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          title: Text('Recherche avancée', style: TextStyle(color: text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Utilisateurs', style: TextStyle(color: text)),
                onTap: () => Navigator.pop(context, 'users'),
              ),
              ListTile(
                title: Text('Publications', style: TextStyle(color: text)),
                onTap: () => Navigator.pop(context, 'posts'),
              ),
              ListTile(
                title: Text('Livres', style: TextStyle(color: text)),
                onTap: () => Navigator.pop(context, 'books'),
              ),
            ],
          ),
        );
      },
    );

    if (searchType != null) {
      _showSnackBar('Recherche de $searchType');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}