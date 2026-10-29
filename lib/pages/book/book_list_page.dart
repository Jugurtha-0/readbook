import 'package:flutter/material.dart';
import 'package:bookio/google_books_service.dart';
import 'package:bookio/book.dart';
import 'package:bookio/pages/book/shelf_service.dart';
import 'book_details_page.dart';

class BookListPage extends StatefulWidget {
  const BookListPage({super.key});

  @override
  _BookListPageState createState() => _BookListPageState();
}

class _BookListPageState extends State<BookListPage> {
  static const Color primary = Color(0xFF4B4231); // Marron foncé
  static const Color secondary = Color(0xFFE7C4A4); // Beige pâle
  static const Color background = Color(0xFF1D1D1D); // Gris très foncé
  static const Color text = Color(0xFFF5F0E6); // Crème clair
  static const Color textSecondary = Color(0xFFD3C1A6); // Beige doré
  static const Color card = Color(0xFF2D2D2D); // Gris foncé

  List<Book> books = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    fetchRandomBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length > 2) {
      searchBooks(query);
    }
  }

  void fetchRandomBooks() {
    final randomQueries = [
      "novel", "story", "book", "fiction", "adventure",
      "romance", "science", "fantasy", "mystery", "history"
    ];
    final randomQuery = (randomQueries..shuffle()).first;
    searchBooks(randomQuery);
  }

  void searchBooks(String query) async {
    setState(() => isLoading = true);
    try {
      final results = await GoogleBooksService.fetchBooks(query);
      setState(() {
        books = results;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print("Erreur: $e");
    }
  }

  Future<void> saveBookToShelf(Book book, String shelfName) async {
    try {
      switch (shelfName) {
        case 'à_lire':
          await ShelfService.addToRead(book);
          break;
        case 'en_lecture':
          await ShelfService.addCurrentlyReading(book);
          break;
        case 'deja_lu':
          await ShelfService.addRead(book);
          break;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ajouté à l'étagère \"$shelfName\""),
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: text),
            decoration: InputDecoration(
              hintText: "Rechercher un livre...",
              hintStyle: TextStyle(color: textSecondary),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: textSecondary),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: secondary,
            ),
          Expanded(
            child: books.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isLoading ? "Recherche en cours..." : "Aucun livre trouvé",
                          style: TextStyle(
                            fontSize: 18,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookDetailsPage(book: book),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Hero(
                                    tag: 'book-cover-${book.id}',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: book.imageUrl.isNotEmpty
                                          ? Image.network(
                                              book.imageUrl,
                                              width: 80,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 80,
                                              height: 120,
                                              color: primary.withOpacity(0.2),
                                              child: Icon(
                                                Icons.book,
                                                size: 40,
                                                color: textSecondary,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: text,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          book.author,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              _buildShelfButton(
                                                'À lire',
                                                primary.withOpacity(0.2),
                                                text,
                                                () => saveBookToShelf(book, 'à_lire'),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildShelfButton(
                                                'En cours',
                                                secondary.withOpacity(0.2),
                                                text,
                                                () => saveBookToShelf(book, 'en_lecture'),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildShelfButton(
                                                'Terminé',
                                                Colors.brown[700]!,
                                                text,
                                                () => saveBookToShelf(book, 'deja_lu'),
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShelfButton(
      String text, Color bgColor, Color textColor, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}