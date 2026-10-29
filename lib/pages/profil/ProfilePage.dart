import 'package:bookio/pages/autentification/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bookio/pages/profil/edit_profile_page(1).dart';
import 'package:bookio/pages/app_colors.dart';
import 'package:bookio/pages/profil/create_publication_page(1).dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Dio _dio = Dio();

  User? user;
  String profileImageUrl = '';
  String firstName = '';
  String lastName = '';
  String dateOfBirth = '';
  String pio = '';

  int friendsCount = 0;
  int likesCount = 0;
  int postsCount = 0;

  int selectedTabIndex = 0;
  bool isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    _loadUserProfile();
    _loadUserStats();
  }

Future<void> _loadUserProfile() async {
  if (user != null) {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user!.uid).get();
      if (userDoc.exists) {
        setState(() {
          firstName = userDoc.get('firstName') ?? '';
          lastName = userDoc.get('lastName') ?? '';
          dateOfBirth = userDoc.get('dateOfBirth') ?? '';
          pio = userDoc.get('bio') ?? ''; // Champ corrigé ici
          profileImageUrl = userDoc.get('profileImageUrl') ?? '';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Erreur Firestore: $e");
      setState(() => isLoading = false);
    }
  }
}

  Future<void> _loadUserStats() async {
    if (user != null) {
      final friendsSnapshot = 
          await _firestore.collection('users').doc(user!.uid).collection('friends').get();
      final likesSnapshot = 
          await _firestore.collection('posts').where('likedBy', arrayContains: user!.uid).get();
      final postsSnapshot = 
          await _firestore.collection('posts').where('userId', isEqualTo: user!.uid).get();

      setState(() {
        friendsCount = friendsSnapshot.docs.length;
        likesCount = likesSnapshot.docs.length;
        postsCount = postsSnapshot.docs.length;
      });
    }
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      children: [
        Text('$count', 
             style: TextStyle(
               color: AppColors.text, 
               fontWeight: FontWeight.bold, 
               fontSize: 16)),
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildTabNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: Icon(Icons.grid_on, 
                 color: selectedTabIndex == 0 ? AppColors.text : AppColors.textSecondary),
          onPressed: () => setState(() => selectedTabIndex = 0),
        ),
        IconButton(
          icon: Icon(Icons.book, 
                 color: selectedTabIndex == 1 ? AppColors.text : AppColors.textSecondary),
          onPressed: () => setState(() => selectedTabIndex = 1),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (selectedTabIndex) {
      case 1:
        return _buildBooksTab();
      default:
        return _buildNormalPostsTab();
    }
  }

  Widget _buildNormalPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('userId', isEqualTo: user!.uid)
          .where('type', isEqualTo: 'normal')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.secondary));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('Aucune publication normale !', 
                   style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final postData = post.data() as Map<String, dynamic>;
            final isLiked = (postData['likedBy'] ?? []).contains(user!.uid);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.secondary,
                      backgroundImage: NetworkImage(profileImageUrl),
                    ),
                    title: Text('$firstName $lastName', 
                           style: TextStyle(color: AppColors.text)),
                  ),
                  if (postData['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        postData['imageUrl'],
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _toggleLike(post.id, postData, isLiked),
                          child: AnimatedScale(
                            scale: isLiked ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : AppColors.text,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(Icons.comment, color: AppColors.text),
                          onPressed: () => _showComments(context, post.id),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text('${postData['likes'] ?? 0} likes', 
                           style: TextStyle(color: AppColors.text)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, 
                      vertical: 8.0),
                    child: Text(postData['description'] ?? '', 
                           style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBooksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('userId', isEqualTo: user!.uid)
          .where('type', isEqualTo: 'livre')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.secondary));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book, size: 50, color: AppColors.textSecondary),
                const SizedBox(height: 10),
                Text('Aucun livre partagé !', 
                       style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _showAddPublicationOptions,
                  child: Text('Ajouter un livre', 
                         style: TextStyle(color: AppColors.secondary)),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data!.docs;

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 0.7,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final postData = post.data() as Map<String, dynamic>;
            
            return GestureDetector(
              onTap: () => _showBookDetails(postData),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          postData['imageUrl'],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => 
                            Container(
                              color: AppColors.card, 
                              child: Icon(Icons.book, color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        postData['title'] ?? 'Sans titre',
                        style: TextStyle(
                          color: AppColors.text, 
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    isScrollControlled: true,
    builder: (BuildContext context) {
      TextEditingController commentController = TextEditingController();

      return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    return Center(
                        child: CircularProgressIndicator(
                            color: AppColors.secondary));
                  }
                  var comments = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      var comment = comments[index];
                      var data = comment.data() as Map<String, dynamic>;

                      return ListTile(
                        title: Text(data['comment'],
                            style: const TextStyle(color: AppColors.text)),
                        subtitle: Text(data['username'] ?? '',
                            style:
                                const TextStyle(color: AppColors.textSecondary)),
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
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        hintStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.secondary),
                    onPressed: () async {
                      if (commentController.text.isNotEmpty) {
                        await _firestore
                            .collection('posts')
                            .doc(postId)
                            .collection('comments')
                            .add({
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
        ),
      );
    },
  );
}



  void _showBookDetails(Map<String, dynamic> postData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 120,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: postData['imageUrl'] != null
                          ? Image.network(
                              postData['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                Icon(Icons.book, color: AppColors.textSecondary, size: 50),
                            )
                          : Icon(Icons.book, color: AppColors.textSecondary, size: 50),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          postData['title'] ?? 'Sans titre',
                          style: TextStyle(
                            color: AppColors.text, 
                            fontSize: 20, 
                            fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        if (postData['pdfUrl'] != null) ...[
                          ElevatedButton(
                            onPressed: _isDownloading 
                                ? null 
                                : () => _openPdf(postData['pdfUrl']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.text,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isDownloading
                                ? CircularProgressIndicator(color: AppColors.text)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.picture_as_pdf, size: 24),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Ouvrir le PDF',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (postData['description'] != null && postData['description'].isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        color: AppColors.text, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        postData['description'],
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPdf(String pdfUrl) async {
    if (_isDownloading) return;
    
    setState(() {
      _isDownloading = true;
    });

    try {
      if (await canLaunchUrl(Uri.parse(pdfUrl))) {
        await launchUrl(
          Uri.parse(pdfUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      final googleDocsUrl = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(pdfUrl)}';
      if (await canLaunchUrl(Uri.parse(googleDocsUrl))) {
        await launchUrl(
          Uri.parse(googleDocsUrl),
          mode: LaunchMode.inAppWebView,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Téléchargement du PDF en cours..."),
          duration: Duration(seconds: 2),
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      await _dio.download(pdfUrl, filePath);
      
      final openResult = await OpenFile.open(filePath);
      
      if (openResult.type != ResultType.done) {
        throw "Aucune application disponible pour ouvrir le PDF";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _showAddPublicationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.text_fields, color: AppColors.text),
              title: Text("Publication normale", style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreatePublicationPage(type: 'normal'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.book, color: AppColors.text),
              title: Text("Livre", style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreatePublicationPage(type: 'livre'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          userId: user!.uid,
          initialFirstName: firstName,
          initialLastName: lastName,
          initialDateOfBirth: dateOfBirth,
          initialPio: pio,
          initialProfileImageUrl: profileImageUrl,
        ),
      ),
    );

    if (result == true) {
      await _loadUserProfile();
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text('$firstName $lastName', 
               style: TextStyle(color: AppColors.text)),
        actions: [
        PopupMenuButton<String>(
  color: AppColors.card,
  onSelected: (value) async {
    if (value == 'logout') {
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
    }
  },
  itemBuilder: (context) => [
    PopupMenuItem(
      value: 'logout',
      child: Text('Déconnexion', style: TextStyle(color: AppColors.text)),
    ),
  ],
  icon: Icon(Icons.more_vert, color: AppColors.text),
)

        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.secondary,
            backgroundImage: profileImageUrl.isNotEmpty
                ? NetworkImage(profileImageUrl)
                : null,
            child: profileImageUrl.isEmpty
                ? Icon(Icons.person, size: 50, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: 10),
          Text('$firstName $lastName',
              style: TextStyle(
                color: AppColors.text, 
                fontWeight: FontWeight.bold, 
                fontSize: 16)),
          const SizedBox(height: 5),
          Text(pio, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 5),
          Text(dateOfBirth, style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatColumn(friendsCount, 'Amis'),
              const SizedBox(width: 24),
              _buildStatColumn(likesCount, 'Likes'),
              const SizedBox(width: 24),
              _buildStatColumn(postsCount, 'Posts'),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _navigateToEditProfile,
            icon: Icon(Icons.edit, color: AppColors.primary),
            label: Text('Modifier le profil', 
                   style: TextStyle(color: AppColors.primary)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildTabNavigation(),
          Divider(color: AppColors.textSecondary.withOpacity(0.3)),
          Expanded(child: _buildTabContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPublicationOptions,
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: AppColors.text),
      ),
    );
  }
}