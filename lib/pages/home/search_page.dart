import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bookio/book.dart';
import 'package:bookio/google_books_service.dart';
import 'package:bookio/pages/book/book_details_page.dart';
import '../chat and friend requests/friend_profile_page.dart';
import 'dart:async';

class AppColors {
  static const Color primary = Color(0xFF4B4231); // Marron foncé
  static const Color secondary = Color(0xFFE7C4A4); // Beige pâle
  static const Color background = Color(0xFF1D1D1D); // Gris très foncé
  static const Color text = Color(0xFFF5F0E6); // Crème clair
  static const Color textSecondary = Color(0xFFD3C1A6); // Beige doré
  static const Color card = Color(0xFF2D2D2D); // Gris foncé
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _userResults = [];
  List<Book> _bookResults = [];
  bool _isLoading = false;
  SearchType _searchType = SearchType.user;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _userResults.clear());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Recherche par fullName, firstName et lastName
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('firstName', isGreaterThanOrEqualTo: query)
          .where('firstName', isLessThan: '${query}z')
          .get();

      QuerySnapshot snapshotLastName = await FirebaseFirestore.instance
          .collection('users')
          .where('lastName', isGreaterThanOrEqualTo: query)
          .where('lastName', isLessThan: '${query}z')
          .get();

      Set<Map<String, dynamic>> allResults = {};
      allResults.addAll(snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id; // Ajouter l'UID de l'utilisateur
        return data;
      }));
      allResults.addAll(snapshotLastName.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id; // Ajouter l'UID de l'utilisateur
        return data;
      }));

      setState(() {
        _userResults = allResults.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Erreur: $e");
    }
  }

  Future<void> _searchBooks(String query) async {
    if (query.isEmpty) {
      setState(() => _bookResults.clear());
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final results = await GoogleBooksService.fetchBooks(query);
      setState(() {
        _bookResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Erreur lors de la recherche');
      debugPrint("Search error: $e");
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchType == SearchType.user) {
        _searchUsers(query.trim());
      } else {
        _searchBooks(query.trim());
      }
    });
  }

  Future<void> _sendFriendRequest(String friendId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId == friendId) return;

    try {
      final existingRequest = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('senderId', isEqualTo: userId)
          .where('receiverId', isEqualTo: friendId)
          .where('status', whereIn: ['pending', 'accepted'])
          .limit(1)
          .get();

      if (existingRequest.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('friend_requests').add({
          'senderId': userId,
          'receiverId': friendId,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Demande envoyée'),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Demande déjà existante'),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Erreur lors de l\'envoi');
      }
      debugPrint("Friend request error: $e");
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSearchTypeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: SegmentedButton<SearchType>(
        segments: const [
          ButtonSegment<SearchType>(
            value: SearchType.user,
            icon: Icon(Icons.person_outline),
            label: Text('Utilisateurs'),
          ),
          ButtonSegment<SearchType>(
            value: SearchType.book,
            icon: Icon(Icons.menu_book_outlined),
            label: Text('Livres'),
          ),
        ],
        selected: <SearchType>{_searchType},
        onSelectionChanged: (Set<SearchType> newSelection) {
          setState(() {
            _searchType = newSelection.first;
            _onSearchChanged(_searchController.text);
          });
          _searchFocusNode.requestFocus();
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.card,
          selectedBackgroundColor: AppColors.primary,
          foregroundColor: AppColors.text,
          selectedForegroundColor: AppColors.text,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          hintText: 'Rechercher ${_searchType == SearchType.user ? 'un utilisateur...' : 'un livre...'}',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildUserResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Aucun utilisateur trouvé',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12.0),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == user['uid'];
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FriendProfilePage(userId: user['uid']),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ListTile(
              leading: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FriendProfilePage(userId: user['uid']),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  backgroundImage: user['profileImageUrl'] != null
                      ? NetworkImage(user['profileImageUrl'])
                      : null,
                  child: user['profileImageUrl'] == null
                      ? Text(
                          user['firstName']?.isNotEmpty == true 
                              ? user['firstName'][0].toUpperCase() 
                              : '?',
                          style: TextStyle(color: AppColors.text),
                        )
                      : null,
                ),
              ),
              title: Text(
                "${user['firstName'] ?? ''} ${user['lastName'] ?? ''}".trim(),
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                user['email'] ?? '',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              trailing: !isCurrentUser
                  ? IconButton(
                      icon: Icon(Icons.person_add_alt_1, color: AppColors.secondary),
                      onPressed: () => _sendFriendRequest(user['uid']),
                      tooltip: 'Ajouter en ami',
                    )
                  : Chip(
                      label: Text('Vous', style: TextStyle(color: AppColors.text)),
                      backgroundColor: AppColors.primary.withOpacity(0.3),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_online_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Aucun livre trouvé',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: _bookResults.length,
      itemBuilder: (context, index) {
        final book = _bookResults[index];
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookDetailsPage(book: book),
              ),
            );
          },
          child: Card(
            color: AppColors.card,
            clipBehavior: Clip.antiAlias,
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: book.imageUrl.isNotEmpty
                      ? Image.network(
                          book.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              Icons.book_outlined,
                              size: 60,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.book_outlined,
                            size: 60,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (book.author.isNotEmpty)
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Recherche',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchTypeToggle(),
          _buildSearchField(),
          const SizedBox(height: 8.0),
          Expanded(
            child: _searchType == SearchType.user
                ? _buildUserResults()
                : _buildBookResults(),
          ),
        ],
      ),
    );
  }
}

enum SearchType { user, book }