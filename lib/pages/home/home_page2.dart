import 'package:bookio/pages/profil/ProfilePage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:bookio/pages/home/comment_page.dart';
import 'package:bookio/pages/chat%20and%20friend%20requests/friendlist_page.dart';
import 'package:bookio/pages/home/search_page.dart';
import 'package:bookio/pages/chat%20and%20friend%20requests/notification_page.dart';
import 'package:bookio/pages/book/book_list_page.dart';
import 'package:bookio/pages/book/my_shelves_page.dart';
import 'package:bookio/componenets/home_page_methodes.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:bookio/pages/pdf_viewer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
 
  @override
  State<HomePage> createState() => _HomePageState();
  
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final HomePageMethods _homePageMethods = HomePageMethods();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;
  int _notificationCount = 0;

  // Color constants
  static const Color primary = Color(0xFF4B4231);
  static const Color secondary = Color(0xFFE7C4A4);
  static const Color background = Color(0xFF1D1D1D);
  static const Color text = Color(0xFFF5F0E6);
  static const Color textSecondary = Color(0xFFD3C1A6);
  static const Color card = Color(0xFF2D2D2D);






  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
    _loadNotificationCount();
  }



  Future<void> _loadNotificationCount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(currentUser.uid)
        .collection('user_notifications')
        .where('read', isEqualTo: false)
        .get();

    if (mounted) {
      setState(() {
        _notificationCount = snapshot.size;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String> _getUserFullName(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        String firstName = userDoc['firstName'] ?? '';
        String lastName = userDoc['lastName'] ?? '';
        return '$firstName $lastName';
      }
    } catch (e) {
      debugPrint("Error getting user name: $e");
    }
    return "Unknown User";
  }

  Widget _buildPostShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 300,
            color: Colors.grey,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const CircleAvatar(radius: 20, backgroundColor: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 10,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 150,
                        height: 10,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildPostItem(DocumentSnapshot post) {
    var postData = post.data() as Map<String, dynamic>;
    final timestamp = postData['timestamp'] as Timestamp?;
    final dateTime = timestamp?.toDate();
    final formattedDate = dateTime != null 
        ? DateFormat('MMM d, yyyy · h:mm a').format(dateTime)
        : '';
    final type = postData['type']?.toString().toLowerCase();
final isPdfPost = type == 'pdf' || type == 'livre';
 final isCritique = type == 'critique';
    return FutureBuilder<String>(
      future: _getUserFullName(postData['userId']),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildPostShimmer();
        }

        String fullName = userSnapshot.data ?? "Unknown User";

        return GestureDetector(
          onDoubleTap: () => _homePageMethods.toggleLike(
              post.id, postData['likes'] ?? {}),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            color: card,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Post header with user info
                ListTile(
                  leading: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(postData['userId'])
                        .get(),
                    builder: (context, userDataSnapshot) {
                      if (userDataSnapshot.connectionState == ConnectionState.waiting) {
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[800],
                          child: const Icon(Icons.person, color: Colors.white),
                        );
                      }
                      
                      if (!userDataSnapshot.hasData || !userDataSnapshot.data!.exists) {
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[800],
                          child: const Icon(Icons.person, color: Colors.white),
                        );
                      }
                      
                      var userData = userDataSnapshot.data!.data() as Map<String, dynamic>;
                      String profileImageUrl = userData['profileImageUrl'] ?? '';
                      
                      return CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[800],
                        child: ClipOval(
                          child: profileImageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: profileImageUrl,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.person, color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white),
                                  fit: BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                )
                              : const Icon(Icons.person, color: Colors.white),
                        ),
                      );
                    },
                  ),
                  title: Text(
                    fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: text,
                    ),
                  ),
                  subtitle: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 12, 
                      color: textSecondary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert, color: textSecondary),
                    onPressed: () => _homePageMethods.showPostOptions(
                        context, post.id, postData['userId']),
                  ),
                ),
                
                // Post content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    postData['text'] ?? "",
                    style: const TextStyle(fontSize: 14, color: text),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Post media (PDF or Image)
                // Bouton "Lire" pour les publications PDF
           // Affiche le bouton pour lire le PDF si disponible
if (isPdfPost && postData['pdfUrl'] != null && postData['pdfUrl'].isNotEmpty)
  ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(url: postData['pdfUrl']),
        ),
      );
    },
    icon: const Icon(Icons.picture_as_pdf, size: 20),
    label: const Text("Lire PDF"),
    style: ElevatedButton.styleFrom(
      backgroundColor: secondary,
      foregroundColor: primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  ),

// Affiche l’image si disponible
if (postData['imageUrl'] != null && postData['imageUrl'].isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: isCritique
        ? Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
              image: DecorationImage(
                image: CachedNetworkImageProvider(postData['imageUrl']),
                fit: BoxFit.contain,
              ),
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: postData['imageUrl'],
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
              placeholder: (context, url) => Container(
                height: 300,
                color: Colors.grey[800],
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(secondary),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 300,
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
  ),



                
                // Post actions (like, comment, read)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              (postData['likes'] is Map<String, dynamic> &&
                                  postData['likes'].containsKey(
                                      FirebaseAuth.instance.currentUser?.uid))
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () => _homePageMethods.toggleLike(
                                post.id, postData['likes'] ?? {}),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${(postData['likes'] is Map) ? postData['likes'].length : 0}",
                            style: const TextStyle(fontSize: 14, color: text),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(FeatherIcons.messageSquare, color: text),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommentPage(postId: post.id),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${postData['commentCount'] ?? 0}",
                            style: const TextStyle(fontSize: 14, color: text),
                          ),
                        ],
                      ),
                      // Bouton "Lire" pour les publications PDF
                      if (isPdfPost && postData['pdfUrl'] != null && postData['pdfUrl'].isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.book, color: Colors.white),
                          label: const Text(
                            'Lire',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                           onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(url: postData['pdfUrl']),
        ),
      );
    },


                          
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, int index) {
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _navigateToPage(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _currentIndex == index ? secondary.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _currentIndex == index ? activeIcon : icon,
              color: _currentIndex == index ? secondary : Colors.grey,
              size: 24,
            ),
          ),
          if (_currentIndex == index)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 3,
              width: 20,
              decoration: BoxDecoration(
                color: secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToPage(int index) {
    switch (index) {
      case 0:
        // Already on home page
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyShelvesPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BookListPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FriendsListPage()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: text, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Search books or friends...",
                  style: TextStyle(color: text, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        actions: [
          badges.Badge(
            position: badges.BadgePosition.topEnd(top: -10, end: -5),
            badgeContent: Text(
              _notificationCount > 0 ? _notificationCount.toString() : '',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            showBadge: _notificationCount > 0,
            child: IconButton(
              icon: const Icon(Icons.notifications_none, size: 24, color: text),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsPage()),
                ).then((_) => _loadNotificationCount());
              },
            ),
          ),
        ],
      ),
      
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(seconds: 1));
            _loadNotificationCount();
          },
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) => _buildPostShimmer(),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.feed, size: 50, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "No posts found",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _homePageMethods.showCreatePostDialog(context),
                        child: const Text("Create your first post"),
                      ),
                    ],
                  ),
                );
              }

              var posts = snapshot.data!.docs;

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.easeOut,
                    )),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildPostItem(posts[index]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: primary,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_outlined, Icons.home, 0),
              _buildNavItem(Icons.menu_book_outlined, Icons.menu_book, 1),
              _buildNavItem(Icons.explore_outlined, Icons.explore, 2),
              _buildNavItem(Icons.people_outlined, Icons.people, 3),
              _buildNavItem(Icons.person_outlined, Icons.person, 4),
            ],
          ),
        ),
      ),
    );
  }
}