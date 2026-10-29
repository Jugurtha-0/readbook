import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';


class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendAvatar;
  final bool isGroup;

  const ChatPage({
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
    this.isGroup = false,
    super.key,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Palette de couleurs
  final Color _primaryColor = const Color(0xFF4B4231);
  final Color _secondaryColor = const Color(0xFFE7C4A4);
  final Color _backgroundColor = const Color(0xFF1D1D1D);
  final Color _messageSentColor = const Color(0xFF4B4231);
  final Color _messageReceivedColor = const Color(0xFFE7C4A4);
  final Color _textSentColor = const Color(0xFFF5F0E6);
  final Color _textReceivedColor = const Color(0xFF000000);
  final Color _inputBackgroundColor = const Color(0xFF2D2D2D);
  final Color _appBarColor = const Color(0xFF1D1D1D);
  final Color _appBarTextColor = const Color(0xFFF5F0E6);
  final Color _indicatorColor = const Color(0xFFD3C1A6);

  @override
  void initState() {
    super.initState();
    if (!widget.isGroup) {
      _markMessagesAsRead();
      _setupPresenceDetection();
    }
  
  }


  Future<void> _sendCallNotification(String receiverId) async {
    final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
    final receiverToken = receiverDoc['fcmToken'];

    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=VOTRE_CLE_SERVEUR_FCM',
      },
      body: jsonEncode({
        'to': receiverToken,
        'notification': {
          'title': 'Appel entrant',
          'body': '${_auth.currentUser?.displayName ?? "Quelqu'un"} vous appelle',
        },
        'data': {
          'type': 'call',
          'callerId': _auth.currentUser?.uid,
          'channelId': 'chat_${_auth.currentUser?.uid}_$receiverId',
        },
      }),
    );
  }

  // MARK: - Méthodes de chat
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _markMessagesAsRead() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final query = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: widget.friendId)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking messages as read: $e");
    }
  }

  void _setupPresenceDetection() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore.collection('users').doc(userId).update({
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': true,
    });
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final userId = _auth.currentUser?.uid;
    final messageText = _messageController.text.trim();

    if ((messageText.isEmpty && imageUrl == null) || userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (widget.isGroup) {
        await _firestore.collection('group_messages').add({
          'groupId': widget.friendId,
          'senderId': userId,
          'message': messageText.isNotEmpty ? messageText : null,
          'imageUrl': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('messages').add({
          'senderId': userId,
          'receiverId': widget.friendId,
          'message': messageText.isNotEmpty ? messageText : null,
          'imageUrl': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        await _updateLastConversation(userId, messageText, imageUrl);
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackbar("Erreur lors de l'envoi du message");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLastConversation(String userId, String message, String? imageUrl) async {
    final lastMessage = imageUrl != null ? "[Image]" : message;
    final timestamp = FieldValue.serverTimestamp();

    await _firestore.collection('conversations').doc('$userId-${widget.friendId}').set({
      'userId': userId,
      'friendId': widget.friendId,
      'friendName': widget.friendName,
      'friendAvatar': widget.friendAvatar,
      'lastMessage': lastMessage,
      'timestamp': timestamp,
      'unreadCount': 0,
    }, SetOptions(merge: true));

    await _firestore.collection('conversations').doc('${widget.friendId}-$userId').set({
      'userId': widget.friendId,
      'friendId': userId,
      'friendName': _auth.currentUser?.displayName ?? "Utilisateur",
      'friendAvatar': _auth.currentUser?.photoURL ?? "",
      'lastMessage': lastMessage,
      'timestamp': timestamp,
      'unreadCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> _sendImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    File imageFile = File(pickedFile.path);
    String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_indicatorColor),
          ),
        ),
      );

      String fileName = "chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      Navigator.pop(context);
      await _sendMessage(imageUrl: downloadUrl);
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackbar("Erreur lors de l'envoi de l'image");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Stream<QuerySnapshot> _getMessages() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    if (widget.isGroup) {
      return _firestore
          .collection('group_messages')
          .where('groupId', isEqualTo: widget.friendId)
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else {
      return _firestore
          .collection('messages')
          .where(Filter.or(
            Filter.and(
              Filter('senderId', isEqualTo: userId),
              Filter('receiverId', isEqualTo: widget.friendId),
            ),
            Filter.and(
              Filter('senderId', isEqualTo: widget.friendId),
              Filter('receiverId', isEqualTo: userId),
            ),
          ))
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  Future<Map<String, dynamic>> _getUserStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return {
        'isOnline': doc['isOnline'] ?? false,
        'lastSeen': doc['lastSeen'] != null 
            ? (doc['lastSeen'] as Timestamp).toDate() 
            : DateTime.now(),
      };
    } catch (e) {
      return {'isOnline': false, 'lastSeen': DateTime.now()};
    }
  }

  // MARK: - UI Components
  Widget _buildMessageBubble(String messageId, Map<String, dynamic> message) {
    bool isMe = message['senderId'] == _auth.currentUser?.uid;
    String? text = message['message'];
    String? imageUrl = message['imageUrl'];
    Timestamp? timestamp = message['timestamp'];
    bool isRead = message['isRead'] ?? false;

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(message['senderId']).get(),
      builder: (context, snapshot) {
        String senderName = "Utilisateur";
        String senderAvatar = "";
        
        if (snapshot.hasData) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            senderName = "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}";
            senderAvatar = userData['avatarUrl'] ?? "";
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            top: 8,
            bottom: 8,
            left: isMe ? 50 : 10,
            right: isMe ? 10 : 50,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (widget.isGroup && !isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                  child: Text(
                    senderName,
                    style: TextStyle(
                      color: _appBarTextColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe)
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _secondaryColor,
                      backgroundImage: senderAvatar.isNotEmpty 
                          ? NetworkImage(senderAvatar) 
                          : null,
                      child: senderAvatar.isEmpty
                          ? Icon(Icons.person, color: _textSentColor)
                          : null,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? _messageSentColor : _messageReceivedColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GestureDetector(
                                onTap: () => _showFullImage(imageUrl),
                                child: Image.network(
                                  imageUrl,
                                  width: 200,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 200,
                                      height: 150,
                                      color: _secondaryColor.withOpacity(0.1),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(_indicatorColor),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          if (text != null)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: imageUrl != null ? 8 : 0,
                                top: imageUrl != null ? 8 : 0,
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: isMe ? _textSentColor : _textReceivedColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTimestamp(timestamp),
                                style: TextStyle(
                                  color: isMe
                                      ? _textSentColor.withOpacity(0.7)
                                      : _textReceivedColor.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                              if (isMe && !widget.isGroup) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isRead ? Icons.done_all : Icons.done,
                                  size: 14,
                                  color: isRead ? _indicatorColor : _textSentColor.withOpacity(0.7),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: _appBarColor,
      child: Row(
        children: [
          
          IconButton(
            icon: Icon(Icons.image, color: _secondaryColor),
            onPressed: _isLoading ? null : _sendImage,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _inputBackgroundColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Écrire un message...",
                  hintStyle: TextStyle(color: _appBarTextColor.withOpacity(0.6)),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: _appBarTextColor),
                maxLines: 3,
                minLines: 1,
                enabled: !_isLoading,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _textSentColor,
                      ),
                    )
                  : Icon(Icons.send, color: _textSentColor),
              onPressed: _isLoading ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: InkWell(
          onTap: widget.isGroup ? _showGroupMembers : _showProfile,
          child: Row(
            children: [
              Hero(
                tag: 'profile_${widget.friendId}',
                child: CircleAvatar(
                  backgroundColor: _secondaryColor,
                  backgroundImage: widget.friendAvatar.isNotEmpty 
                      ? NetworkImage(widget.friendAvatar) 
                      : null,
                  radius: 20,
                  child: widget.friendAvatar.isEmpty
                      ? Icon(widget.isGroup ? Icons.group : Icons.person, 
                          color: _textSentColor)
                      : null,
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friendName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _appBarTextColor,
                    ),
                  ),
                  if (!widget.isGroup)
                    FutureBuilder(
                      future: _getUserStatus(widget.friendId),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final isOnline = snapshot.data!['isOnline'];
                          final lastSeen = snapshot.data!['lastSeen'];
                          return Text(
                            isOnline 
                                ? "En ligne" 
                                : "Vu dernièrement à ${_formatTime(lastSeen)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: _appBarTextColor.withOpacity(0.7),
                            ),
                          );
                        }
                        return Text(
                          "Chargement...", 
                          style: TextStyle(
                            fontSize: 12,
                            color: _appBarTextColor.withOpacity(0.7),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        backgroundColor: _appBarColor,
        foregroundColor: _appBarTextColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: _appBarTextColor),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_indicatorColor),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Erreur: ${snapshot.error}",
                      style: TextStyle(color: _appBarTextColor),
                    ),
                  );
                }
                
                var messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      widget.isGroup 
                          ? "Envoyez le premier message dans ${widget.friendName} !"
                          : "Dites bonjour à ${widget.friendName} !",
                      style: TextStyle(color: _appBarTextColor.withOpacity(0.6)),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index].data() as Map<String, dynamic>;
                    return _buildMessageBubble(messages[index].id, message);
                  },
                );
              },
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(_indicatorColor),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // MARK: - Méthodes utilitaires
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showProfile() async {
    final status = await _getUserStatus(widget.friendId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _backgroundColor,
        title: Text(
          widget.friendName,
          style: TextStyle(color: _appBarTextColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: _secondaryColor,
              backgroundImage: NetworkImage(widget.friendAvatar),
              child: widget.friendAvatar.isEmpty
                  ? Icon(Icons.person, color: _textSentColor)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              status['isOnline'] ? "En ligne" : "Hors ligne",
              style: TextStyle(color: _appBarTextColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Fermer",
              style: TextStyle(color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupMembers() async {
    final groupDoc = await _firestore.collection('groups').doc(widget.friendId).get();
    if (!groupDoc.exists) return;

    final groupData = groupDoc.data() as Map<String, dynamic>;
    final members = groupData['members'] as List<dynamic>;
    final adminId = groupData['admin'] as String;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _backgroundColor,
        title: Text(
          "Membres du groupe",
          style: TextStyle(color: _appBarTextColor),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final memberId = members[index];
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(memberId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  
                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return const SizedBox();
                  
                  final fullName = "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}";
                  final isAdmin = memberId == adminId;
                  final isMe = memberId == _auth.currentUser?.uid;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _secondaryColor,
                      backgroundImage: userData['avatarUrl'] != null
                          ? NetworkImage(userData['avatarUrl'])
                          : null,
                      child: userData['avatarUrl'] == null
                          ? Icon(Icons.person, color: _textSentColor)
                          : null,
                    ),
                    title: Text(
                      isMe ? "$fullName (Vous)" : fullName,
                      style: TextStyle(color: _appBarTextColor),
                    ),
                    trailing: isAdmin
                        ? Text(
                            "Admin",
                            style: TextStyle(
                              color: _indicatorColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Fermer",
              style: TextStyle(color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    final isGroup = widget.isGroup;
    final userId = _auth.currentUser?.uid;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _backgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGroup) ...[
              ListTile(
                leading: Icon(Icons.people, color: _secondaryColor),
                title: Text(
                  "Voir les membres",
                  style: TextStyle(color: _appBarTextColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupMembers();
                },
              ),
              ListTile(
                leading: Icon(Icons.exit_to_app, color: _secondaryColor),
                title: Text(
                  "Quitter le groupe",
                  style: TextStyle(color: _appBarTextColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _leaveGroup();
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.block, color: _secondaryColor),
                title: Text(
                  "Bloquer l'utilisateur",
                  style: TextStyle(color: _appBarTextColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser();
                },
              ),
              ListTile(
                leading: Icon(Icons.report, color: _secondaryColor),
                title: Text(
                  "Signaler l'utilisateur",
                  style: TextStyle(color: _appBarTextColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reportUser();
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.clear_all, color: _secondaryColor),
              title: Text(
                "Effacer la conversation",
                style: TextStyle(color: _appBarTextColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _clearConversation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _backgroundColor,
        title: Text(
          "Quitter le groupe",
          style: TextStyle(color: _appBarTextColor),
        ),
        content: Text(
          "Voulez-vous vraiment quitter ${widget.friendName} ?",
          style: TextStyle(color: _appBarTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Annuler",
              style: TextStyle(color: _primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Quitter",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final groupDoc = await _firestore.collection('groups').doc(widget.friendId).get();
        if (!groupDoc.exists) return;

        final groupData = groupDoc.data() as Map<String, dynamic>;
        final members = List<String>.from(groupData['members']);
        final adminId = groupData['admin'] as String;

        if (adminId == userId) {
          await _firestore.collection('groups').doc(widget.friendId).delete();
          
          final conversations = await _firestore
              .collection('conversations')
              .where('groupId', isEqualTo: widget.friendId)
              .get();
          
          final batch = _firestore.batch();
          for (var doc in conversations.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } else {
          await _firestore.collection('groups').doc(widget.friendId).update({
            'members': FieldValue.arrayRemove([userId]),
          });
          
          await _firestore
              .collection('conversations')
              .doc('$userId-${widget.friendId}')
              .delete();
        }

        Navigator.pop(context);
      } catch (e) {
        _showErrorSnackbar("Erreur lors de la sortie du groupe");
      }
    }
  }

  Future<void> _blockUser() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _backgroundColor,
        title: Text(
          "Bloquer l'utilisateur",
          style: TextStyle(color: _appBarTextColor),
        ),
        content: Text(
          "Voulez-vous vraiment bloquer ${widget.friendName} ?",
          style: TextStyle(color: _appBarTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Annuler",
              style: TextStyle(color: _primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Bloquer",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'blockedUsers': FieldValue.arrayUnion([widget.friendId]),
        });
        Navigator.pop(context);
      } catch (e) {
        _showErrorSnackbar("Erreur lors du blocage de l'utilisateur");
      }
    }
  }

  Future<void> _reportUser() async {
    _showErrorSnackbar("Fonctionnalité de signalement non implémentée");
  }

  Future<void> _clearConversation() async {
    _showErrorSnackbar("Fonctionnalité de suppression non implémentée");
  }

  void _showFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: _textSentColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: _backgroundColor,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_indicatorColor),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _formatTime(DateTime date) {
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}