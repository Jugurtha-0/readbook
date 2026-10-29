import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bookio/book.dart';

class ShelfService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Méthodes pour "À lire"
  static Future<List<Book>> getToReadBooks() async {
    return _getBooksFromShelf('toRead');
  }

  static Future<void> addToRead(Book book) async {
    await _addBookToShelf('toRead', book);
  }

  static Future<void> removeFromToRead(String bookId) async {
    await _removeBookFromShelf('toRead', bookId);
  }

  // Méthodes pour "En train de lire"
  static Future<List<Book>> getCurrentlyReadingBooks() async {
    return _getBooksFromShelf('currentlyReading');
  }

  static Future<void> addCurrentlyReading(Book book) async {
    await _addBookToShelf('currentlyReading', book);
  }

  static Future<void> removeFromCurrentlyReading(String bookId) async {
    await _removeBookFromShelf('currentlyReading', bookId);
  }

  // Méthodes pour "Déjà lu"
  static Future<List<Book>> getReadBooks() async {
    return _getBooksFromShelf('read');
  }

  static Future<void> addRead(Book book) async {
    await _addBookToShelf('read', book);
  }

  static Future<void> removeFromRead(String bookId) async {
    await _removeBookFromShelf('read', bookId);
  }

  // Méthodes génériques privées
  static Future<List<Book>> _getBooksFromShelf(String shelfName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw "Utilisateur non connecté";

      final snapshot = await _firestore
          .collection('userShelves')
          .doc(user.uid)
          .collection(shelfName)
          .orderBy('lastUpdated', descending: true)
          .get();

      return snapshot.docs.map((doc) => Book.fromFirestore(doc)).toList();
    } catch (e) {
      print("Erreur Firestore ($shelfName): $e");
      throw "Impossible de charger les livres";
    }
  }

  static Future<void> _addBookToShelf(String shelfName, Book book) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw "Utilisateur non connecté";

      await _firestore
          .collection('userShelves')
          .doc(user.uid)
          .collection(shelfName)
          .doc(book.id)
          .set({
            ...book.toFirestore(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Erreur ajout livre ($shelfName): $e");
      throw "Impossible d'ajouter le livre";
    }
  }

  static Future<void> _removeBookFromShelf(String shelfName, String bookId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw "Utilisateur non connecté";

      await _firestore
          .collection('userShelves')
          .doc(user.uid)
          .collection(shelfName)
          .doc(bookId)
          .delete();
    } catch (e) {
      print("Erreur suppression livre ($shelfName): $e");
      throw "Impossible de supprimer le livre";
    }
  }
}