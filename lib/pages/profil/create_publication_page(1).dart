import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../app_colors.dart';

class CreatePublicationPage extends StatefulWidget {
  final String type;

  const CreatePublicationPage({super.key, required this.type});

  @override
  _CreatePublicationPageState createState() => _CreatePublicationPageState();
}

class _CreatePublicationPageState extends State<CreatePublicationPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  File? _imageFile;
  File? _pdfFile;
  bool _isLoading = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() => _pdfFile = File(result.files.single.path!));
    }
  }

  Future<void> _submitPublication() async {
    if (titleController.text.trim().isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Titre et image sont obligatoires")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload image
      String imageName = '${DateTime.now().millisecondsSinceEpoch}_${widget.type}.jpg';
      Reference imageRef = FirebaseStorage.instance.ref().child('publications/${widget.type}/$imageName');
      await imageRef.putFile(_imageFile!);
      String imageUrl = await imageRef.getDownloadURL();

      // Upload PDF if book
      String? pdfUrl;
      if (widget.type == 'livre' && _pdfFile != null) {
        String pdfName = '${DateTime.now().millisecondsSinceEpoch}_${widget.type}.pdf';
        Reference pdfRef = FirebaseStorage.instance.ref().child('publications/${widget.type}/$pdfName');
        await pdfRef.putFile(_pdfFile!);
        pdfUrl = await pdfRef.getDownloadURL();
      }

      // Save to Firestore
      Map<String, dynamic> publicationData = {
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'type': widget.type,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': {},
        'likedBy': [],
      };

      if (pdfUrl != null) publicationData['pdfUrl'] = pdfUrl;

      await FirebaseFirestore.instance.collection('posts').add(publicationData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Publication créée avec succès")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Nouvelle ${widget.type == 'livre' ? 'publication de livre' : 'publication'}",
          style: TextStyle(color: AppColors.text),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.secondary))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  // Image picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
                        image: _imageFile != null
                            ? DecorationImage(
                                image: FileImage(_imageFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageFile == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 50, color: AppColors.textSecondary),
                                  const SizedBox(height: 8),
                                  Text('Ajouter une image', style: TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PDF picker for books
                  if (widget.type == 'livre') ...[
                    GestureDetector(
                      onTap: _pickPDF,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, color: AppColors.secondary),
                            const SizedBox(width: 10),
                            Text(
                              _pdfFile?.path.split('/').last ?? 'Ajouter un fichier PDF',
                              style: TextStyle(color: AppColors.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Title field
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: "Titre",
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description field
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    style: TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: "Description",
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Submit button
                  ElevatedButton(
                    onPressed: _submitPublication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('PUBLIER'),
                  ),
                ],
              ),
            ),
    );
  }
}