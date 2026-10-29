import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String imageUrl;
  final String description;
  final double rating;
  final int ratingsCount;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.imageUrl,
    required this.description,
    required this.rating,
    required this.ratingsCount,
  });

  // Conversion depuis Firestore
  factory Book.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Book(
      id: doc.id,
      title: data['title'] ?? 'Titre inconnu',
      author: data['author'] ?? 'Auteur inconnu',
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? 'Pas de description',
      rating: (data['rating'] ?? 0).toDouble(),
      ratingsCount: data['ratingsCount'] ?? 0,
    );
  }

  // Conversion vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'author': author,
      'imageUrl': imageUrl,
      'description': description,
      'rating': rating,
      'ratingsCount': ratingsCount,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Conversion depuis l'API Google Books
  factory Book.fromJson(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] ?? {};
    
    final authors = volumeInfo['authors'] as List?;
    final authorName = (authors != null && authors.isNotEmpty)
        ? authors.join(', ')
        : 'Auteur inconnu';

    final imageLinks = volumeInfo['imageLinks'] ?? {};
    final imageUrl = imageLinks['thumbnail']?.replaceAll('http://', 'https://') ?? '';

    return Book(
      id: json['id'] ?? '',
      title: volumeInfo['title'] ?? 'Titre inconnu',
      author: authorName,
      imageUrl: imageUrl,
      description: volumeInfo['description'] ?? 'Pas de description disponible',
      rating: (volumeInfo['averageRating'] ?? 0).toDouble(),
      ratingsCount: volumeInfo['ratingsCount'] ?? 0,
    );
  }

  // Conversion vers JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'imageUrl': imageUrl,
    'description': description,
    'rating': rating,
    'ratingsCount': ratingsCount,
  };

  @override
  String toString() {
    return 'Book(id: $id, title: $title, author: $author)';
  }
}