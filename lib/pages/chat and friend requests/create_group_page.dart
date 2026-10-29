import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bookio/pages/chat%20and%20friend%20requests/chat_page.dart';
import 'package:bookio/pages/chat%20and%20friend%20requests/friendlist_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _groupNameController = TextEditingController();
  final Map<String, bool> _selectedFriends = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  File? _groupImage;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FriendsListPage.background,
      appBar: AppBar(
        title: const Text("Nouveau groupe", 
            style: TextStyle(color: FriendsListPage.text)),
        backgroundColor: FriendsListPage.primary,
        actions: [_buildCreateButton()],
      ),
      body: Column(
        children: [
          _buildGroupImagePicker(),
          _buildGroupNameField(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(color: FriendsListPage.secondary),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Sélectionnez les membres:",
                style: TextStyle(
                  color: FriendsListPage.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                )),
          ),
          Expanded(child: _buildFriendsList()),
        ],
      ),
    );
  }

  Widget _buildGroupImagePicker() {
    return GestureDetector(
      onTap: _pickGroupImage,
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: FriendsListPage.secondary,
                backgroundImage: _groupImage != null
                    ? FileImage(_groupImage!)
                    : null,
                child: _groupImage == null
                    ? Icon(Icons.group_add, 
                        size: 50, 
                        color: FriendsListPage.primary)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: FriendsListPage.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickGroupImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _groupImage = File(pickedFile.path);
      });
    }
  }

  Widget _buildCreateButton() {
    return IconButton(
      icon: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FriendsListPage.secondary,
              ),
            )
          : Icon(Icons.check, color: FriendsListPage.secondary),
      onPressed: _isLoading ? null : _createGroup,
    );
  }

  Widget _buildGroupNameField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _groupNameController,
          style: TextStyle(color: FriendsListPage.text),
          decoration: InputDecoration(
            labelText: "Nom du groupe",
            labelStyle: TextStyle(color: FriendsListPage.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: FriendsListPage.secondary),
            ),
          ),
          validator: (value) => value!.isEmpty ? "Champ obligatoire" : null,
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    final userId = _auth.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').doc(userId).collection('friends').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: FriendsListPage.secondary));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) => _buildFriendItem(snapshot.data!.docs[index]),
        );
      },
    );
  }

  Widget _buildFriendItem(DocumentSnapshot friend) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(friend['friendId']).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final user = snapshot.data!;
        final userData = user.data() as Map<String, dynamic>;
        final fullName = "${userData['firstName']} ${userData['lastName']}";

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: FriendsListPage.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: CheckboxListTile(
            title: Text(fullName, style: TextStyle(color: FriendsListPage.text)),
            secondary: CircleAvatar(
              backgroundColor: FriendsListPage.secondary,
              backgroundImage: userData['avatarUrl'] != null
                  ? NetworkImage(userData['avatarUrl'])
                  : null,
              child: userData['avatarUrl'] == null
                  ? Text(
                      '${userData['firstName']?[0] ?? ''}${userData['lastName']?[0] ?? ''}',
                      style: TextStyle(color: FriendsListPage.primary),
                    )
                  : null,
            ),
            value: _selectedFriends[user.id] ?? false,
            activeColor: FriendsListPage.secondary,
            checkColor: FriendsListPage.primary,
            onChanged: (value) => setState(() => _selectedFriends[user.id] = value!),
          ),
        );
      },
    );
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final members = _selectedFriends.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sélectionnez au moins un membre", 
              style: TextStyle(color: FriendsListPage.text)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_groupImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('group_avatars/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(_groupImage!);
        imageUrl = await storageRef.getDownloadURL();
      }

      final groupRef = await _firestore.collection('groups').add({
        'name': _groupNameController.text,
        'members': [...members, _auth.currentUser!.uid],
        'admin': _auth.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'avatarUrl': imageUrl ?? '',
      });

      // Create a conversation entry for each member
      final batch = _firestore.batch();
      final allMembers = [...members, _auth.currentUser!.uid];
      
      for (final memberId in allMembers) {
        final conversationRef = _firestore
            .collection('conversations')
            .doc('$memberId-${groupRef.id}');
        
        batch.set(conversationRef, {
          'userId': memberId,
          'groupId': groupRef.id,
          'groupName': _groupNameController.text,
          'groupAvatar': imageUrl ?? '',
          'lastMessage': 'Groupe créé',
          'timestamp': FieldValue.serverTimestamp(),
          'unreadCount': 0,
          'isGroup': true,
        }, SetOptions(merge: true));
      }

      await batch.commit();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            friendId: groupRef.id,
            friendName: _groupNameController.text,
            friendAvatar: imageUrl ?? '',
            isGroup: true,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur de création: ${e.toString()}", 
              style: TextStyle(color: FriendsListPage.text)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}