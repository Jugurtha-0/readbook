import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bookio/book.dart';
class GoogleBooksService {
  static const String apiKey = "AIzaSyBLvTirDtaJE9newdORBpWjnUqDIGUOh7k"; // Remplace par ta clé API
  static const String baseUrl = "https://www.googleapis.com/books/v1/volumes";

  // Fonction pour récupérer les livres depuis Google Books API
  static Future<List<Book>> fetchBooks(String query) async {
    final response = await http.get(Uri.parse("$baseUrl?q=$query&key=$apiKey"));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> items = data["items"] ?? [];

      return items.map((item) => Book.fromJson(item)).toList();
    } else {
      throw Exception("Erreur lors de la récupération des livres");
    }
  }
}
