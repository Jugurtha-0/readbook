// home_page_methods.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class HomePageMethods {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;


  void showReportDialog(BuildContext context, String postId) {
  TextEditingController reasonController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Pourquoi voulez-vous signaler cette publication ?"),
      content: TextField(
        controller: reasonController,
        maxLines: 3,
        decoration: InputDecoration(hintText: "Décrivez la raison du signalement"),
      ),
      actions: [
        TextButton(
          child: Text("Annuler"),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text("Envoyer"),
          onPressed: () async {
            String reason = reasonController.text.trim();
            if (reason.isNotEmpty) {
              await FirebaseFirestore.instance.collection('reports').add({
                'postId': postId,
                'userId': FirebaseAuth.instance.currentUser?.uid,
                'reason': reason,
                'timestamp': FieldValue.serverTimestamp(),
              });
              print("🚩 Signalement envoyé pour le post $postId");
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Merci, votre signalement a été envoyé.")),
              );
            }
          },
        ),
      ],
    ),
  );
}




  void showPostOptions(BuildContext context, String postId, String postOwnerId) {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            if (currentUserId == postOwnerId) // Si c'est l'auteur du post
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text("Supprimer"),
                onTap: () {
                  Navigator.pop(context);
                  confirmDeletePost(context, postId);
                },
              )
              
            else // Si c'est un autre utilisateur
              ListTile(
                leading: Icon(Icons.visibility_off, color: Colors.grey),
                title: Text("Masquer"),
                onTap: () {
                  Navigator.pop(context);
                hidePostForUser(postId);
                },
              ),
           
           ListTile(
  leading: Icon(Icons.flag, color: Colors.red),
  title: Text("Signaler"),
  onTap: () {
    Navigator.pop(context);
    showReportDialog(context, postId);
  },
),






          ],
        );
      },
    );
  }

  void hidePostForUser(String postId) {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'hiddenPosts': FieldValue.arrayUnion([postId])
    });
  }

  Future<void> addComment(String postId, String commentText) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
      'userId': userId,
      'text': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    print("✅ Commentaire ajouté !");
  }

  void _showCommentDialog(BuildContext context, String postId) {
    TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Ajouter un commentaire"),
        content: TextField(
          controller: commentController,
          decoration: InputDecoration(hintText: "Écrire un commentaire..."),
        ),
        actions: [
          TextButton(
            child: Text("Annuler"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Publier"),
            onPressed: () async {
              String commentText = commentController.text.trim();
              if (commentText.isNotEmpty) {
                await addComment(postId, commentText);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

Future<void> toggleLike(String postId, Map<String, dynamic> likes) async {
  String? userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return;

  bool isLiked = likes.containsKey(userId);

  await FirebaseFirestore.instance.collection('posts').doc(postId).update({
    "likes.$userId": isLiked ? FieldValue.delete() : true,
  }).catchError((error) {
    print("❌ Erreur lors du like: $error");
  });
}

  Future<String?> uploadImage(File imageFile) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName.jpg');

      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String imageUrl = await snapshot.ref.getDownloadURL();

      print("✅ Image uploadée avec succès : $imageUrl");
      return imageUrl;
    } catch (e) {
      print("❌ Erreur lors de l'upload Firebase Storage : $e");
      return null;
    }
  }

  Future<void> publishPost(String text, File? image) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    String? imageUrl;
    if (image != null) {
      print("🔄 Upload de l'image en cours...");
      imageUrl = await uploadImage(image);

      if (imageUrl == null) {
        print("⚠️ L'upload de l'image a échoué, la publication ne contiendra pas d'image.");
      }
    }

    if (text.isNotEmpty || imageUrl != null) {
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': userId,
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': {},
      });
      print("✅ Publication enregistrée avec succès dans Firebase.");
    } else {
      print("❌ Erreur : Aucun texte ni image à publier.");
    }
  }

  void confirmDeletePost(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Supprimer la publication"),
        content: Text("Voulez-vous vraiment supprimer cette publication ?"),
        actions: [
          TextButton(
            child: Text("Annuler"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Supprimer"),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void showCreatePostDialog(BuildContext context) {
    TextEditingController postController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text("Créer une publication"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: postController,
                decoration: InputDecoration(hintText: "Écrire une publication..."),
              ),
              SizedBox(height: 10),
              _selectedImage != null
                  ? Image.file(_selectedImage!, height: 100)
                  : TextButton.icon(
                      icon: Icon(Icons.image),
                      label: Text("Ajouter une image"),
                      onPressed: () async {
                        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setStateDialog(() {
                            _selectedImage = File(pickedFile.path);
                          });
                        }
                      },
                    ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Annuler"),
              onPressed: () {
                _selectedImage = null;
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text("Publier"),
              onPressed: () async {
                await publishPost(postController.text.trim(), _selectedImage);
                _selectedImage = null;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}