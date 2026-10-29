import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bookio/book.dart';
import 'package:bookio/pages/book/shelf_service.dart';
import 'book_details_page.dart';

class AppColors {
  static const Color primary = Color(0xFF4B4231); // Marron foncé
  static const Color secondary = Color(0xFFE7C4A4); // Beige pâle
  static const Color background = Color(0xFF1D1D1D); // Gris très foncé
  static const Color text = Color(0xFFF5F0E6); // Crème clair
  static const Color textSecondary = Color(0xFFD3C1A6); // Beige doré
  static const Color card = Color(0xFF2D2D2D); // Gris foncé
}

class MyShelvesPage extends StatefulWidget {
  const MyShelvesPage({super.key});

  @override
  State<MyShelvesPage> createState() => _MyShelvesPageState();
}

class _MyShelvesPageState extends State<MyShelvesPage> {
  late Future<List<Book>> _booksFuture;
  int _selectedIndex = 0;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _booksFuture = _selectedIndex == 0
          ? ShelfService.getReadBooks()
          : _selectedIndex == 1
              ? ShelfService.getCurrentlyReadingBooks()
              : ShelfService.getToReadBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          "ÉTAGÈRES",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Mettre à jour votre progression de lecture",
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
          _buildShelfSelector(),
          const Divider(color: Colors.brown),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TOUT AFFICHER",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.text),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text("BALISES", style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBookList()),
        ],
      ),
    );
  }

  Widget _buildShelfSelector() {
    return FutureBuilder<List<List<Book>>>(
      future: Future.wait([
        ShelfService.getReadBooks(),
        ShelfService.getCurrentlyReadingBooks(),
        ShelfService.getToReadBooks(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();

        final readCount = snapshot.data![0].length;
        final readingCount = snapshot.data![1].length;
        final toReadCount = snapshot.data![2].length;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
              ),
            ],
          ),
          child: Column(
            children: [
              _buildShelfItem("Déjà lu", readCount, 0),
              const Divider(height: 1, color: Colors.brown),
              _buildShelfItem("En train de lire", readingCount, 1),
              const Divider(height: 1, color: Colors.brown),
              _buildShelfItem("À lire", toReadCount, 2),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShelfItem(String title, int count, int index) {
    return ListTile(
      tileColor: AppColors.card,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _selectedIndex == index ? AppColors.secondary : AppColors.text,
        ),
      ),
      subtitle: Text(
        "$count ${count == 1 ? 'livre' : 'livres'}",
        style: TextStyle(color: AppColors.textSecondary),
      ),
      trailing: _selectedIndex == index
          ? Icon(Icons.check, color: AppColors.secondary)
          : null,
      onTap: () => setState(() {
        _selectedIndex = index;
        _loadBooks();
      }),
    );
  }

  Widget _buildBookList() {
    return FutureBuilder<List<Book>>(
      future: _booksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text("Erreur: ${snapshot.error}", style: TextStyle(color: AppColors.text)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Vous n'avez encore aucune balise.", style: TextStyle(color: AppColors.text)),
                const SizedBox(height: 8),
                Text("Ajoutez autant de BALISES CONSIDÉRENTE", style: TextStyle(color: AppColors.text)),
                Text("DES DÉCOUVREUSES DE L'EXISTENCE", style: TextStyle(color: AppColors.text)),
                Text("DE VOTRE PROFESSIONNEL", style: TextStyle(color: AppColors.text)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final book = snapshot.data![index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: book.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          book.imageUrl,
                          width: 50,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.book, size: 50, color: AppColors.secondary),
                        ),
                      )
                    : Icon(Icons.book, size: 50, color: AppColors.secondary),
                title: Text(book.title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                subtitle: Text(book.author, style: TextStyle(color: AppColors.textSecondary)),
                trailing: IconButton(
                  icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onPressed: () => _showBookOptions(book),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BookDetailsPage(book: book)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBookOptions(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.secondary),
              title: Text("Retirer de l'étagère", style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                _removeBook(book);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit, color: AppColors.secondary),
              title: Text("Modifier le statut", style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                _showStatusChangeDialog(book);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeBook(Book book) async {
    try {
      switch (_selectedIndex) {
        case 0: await ShelfService.removeFromRead(book.id); break;
        case 1: await ShelfService.removeFromCurrentlyReading(book.id); break;
        case 2: await ShelfService.removeFromToRead(book.id); break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Livre retiré"), backgroundColor: AppColors.primary),
      );
      _loadBooks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showStatusChangeDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text("Changer le statut", style: TextStyle(color: AppColors.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.bookmark_add, color: AppColors.secondary),
                title: Text("À lire", style: TextStyle(color: AppColors.text)),
                onTap: () {
                  Navigator.pop(context);
                  _moveBook(book, 'toRead');
                },
              ),
              ListTile(
                leading: Icon(Icons.book, color: AppColors.secondary),
                title: Text("En train de lire", style: TextStyle(color: AppColors.text)),
                onTap: () {
                  Navigator.pop(context);
                  _moveBook(book, 'currentlyReading');
                },
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: AppColors.secondary),
                title: Text("Déjà lu", style: TextStyle(color: AppColors.text)),
                onTap: () {
                  Navigator.pop(context);
                  _moveBook(book, 'read');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _moveBook(Book book, String newShelf) async {
    try {
      switch (_selectedIndex) {
        case 0: await ShelfService.removeFromRead(book.id); break;
        case 1: await ShelfService.removeFromCurrentlyReading(book.id); break;
        case 2: await ShelfService.removeFromToRead(book.id); break;
      }

      switch (newShelf) {
        case 'toRead': await ShelfService.addToRead(book); break;
        case 'currentlyReading': await ShelfService.addCurrentlyReading(book); break;
        case 'read': await ShelfService.addRead(book); break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Livre déplacé vers ${newShelf == 'toRead' ? 'À lire' : newShelf == 'currentlyReading' ? 'En train de lire' : 'Déjà lu'}"),
          backgroundColor: AppColors.primary,
        ),
      );
      _loadBooks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    }
  }
}
