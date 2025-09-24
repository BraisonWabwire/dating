import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating/services/auth_service.dart';
import 'package:dating/services/profile_service.dart'; // Add ProfileService
import 'package:flutter/material.dart';
import 'dart:convert'; // For base64 image decoding

class ChatPage extends StatefulWidget {
  final String toUserId; // ID of the matched user
  final String matchName; // Name of the matched user

  const ChatPage({super.key, required this.toUserId, required this.matchName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class Message {
  final String text;
  final bool isSentByMe;
  final DateTime timestamp;
  final String messageId;

  Message({
    required this.text,
    required this.isSentByMe,
    required this.timestamp,
    required this.messageId,
  });

  factory Message.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      messageId: doc.id,
      text: data['text'] ?? '',
      isSentByMe: data['senderId'] == currentUserId,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  late final String _currentUserId;
  late final String _chatId;
  bool _isMutualMatch = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_authService.currentUserId == null) {
      debugPrint('Error: User is not authenticated');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    _currentUserId = _authService.currentUserId!;
    _chatId = _generateChatId(_currentUserId, widget.toUserId);
    debugPrint('Chat ID: $_chatId, Current User: $_currentUserId, To User: ${widget.toUserId}');

    try {
      _isMutualMatch = await _profileService.checkMutualLike(widget.toUserId);
      if (!_isMutualMatch) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only chat with mutual matches')),
        );
      }
      setState(() {}); // Update UI for match status
    } catch (e) {
      debugPrint('Error checking mutual match: $e');
    }
  }

  // Generate a unique chat ID by sorting user IDs
  String _generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Send a message to Firestore
  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    if (!_isMutualMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only chat with mutual matches')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .set({}); // Create chat document if it doesn't exist
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'senderId': _currentUserId,
        'receiverId': widget.toUserId,
        'text': _controller.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('Message sent: ${_controller.text.trim()}');
      _controller.clear();

      // Simulate a reply (remove in production)
      await Future.delayed(const Duration(seconds: 1));
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'senderId': widget.toUserId,
        'receiverId': _currentUserId,
        'text': 'This is a simulated reply!',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  // Fetch user image for app bar and message bubbles
  Future<String> _getUserImage(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final images = doc.data()?['images'] as List?;
      return images?.isNotEmpty ?? false ? images![0] : 'https://i.pravatar.cc/300';
    } catch (e) {
      debugPrint('Error fetching user image: $e');
      return 'https://i.pravatar.cc/300';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF06292),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: const Color(0xFFF06292),
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF06292),
                  Color(0xFFE91E63),
                ],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: FutureBuilder<String>(
                  future: _getUserImage(widget.toUserId),
                  builder: (context, snapshot) {
                    final imageUrl = snapshot.data ?? 'https://i.pravatar.cc/300';
                    return CircleAvatar(
                      radius: 22,
                      backgroundImage: imageUrl.startsWith('data:image/')
                          ? MemoryImage(base64Decode(imageUrl.split(',').last))
                          : NetworkImage(imageUrl) as ImageProvider,
                      backgroundColor: Colors.white,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.matchName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _isMutualMatch ? 'Online' : 'Match Required',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white, size: 28),
              onPressed: () {
                // Video call functionality
              },
            ),
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white, size: 28),
              onPressed: () {
                // Voice call functionality
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
              onSelected: (value) {
                // Handle menu item selection
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Mute notifications', child: Text('Mute notifications')),
                const PopupMenuItem(value: 'Block', child: Text('Block')),
                const PopupMenuItem(value: 'Report', child: Text('Report')),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(_chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    debugPrint('StreamBuilder error: ${snapshot.error}');
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 64,
                            color: Color(0xFFCCCCCC),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Start a conversation',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF999999),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs
                      .map((doc) => Message.fromFirestore(doc, _currentUserId))
                      .toList();

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: message.isSentByMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!message.isSentByMe) ...[
                              FutureBuilder<String>(
                                future: _getUserImage(widget.toUserId),
                                builder: (context, snapshot) {
                                  final imageUrl = snapshot.data ?? 'https://i.pravatar.cc/300';
                                  return CircleAvatar(
                                    radius: 16,
                                    backgroundImage: imageUrl.startsWith('data:image/')
                                        ? MemoryImage(base64Decode(imageUrl.split(',').last))
                                        : NetworkImage(imageUrl) as ImageProvider,
                                    backgroundColor: Colors.grey[300],
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                margin: EdgeInsets.only(
                                  left: message.isSentByMe ? 50 : 0,
                                  right: message.isSentByMe ? 0 : 50,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: message.isSentByMe
                                        ? [
                                            const Color(0xFFE91E63),
                                            const Color(0xFFF06292),
                                          ]
                                        : [
                                            Color(0xFFF5F5F5),
                                            Color(0xFFE8E8E8),
                                          ],
                                    begin: message.isSentByMe
                                        ? Alignment.centerLeft
                                        : Alignment.topLeft,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(message.isSentByMe ? 20 : 0),
                                    topRight: Radius.circular(message.isSentByMe ? 0 : 20),
                                    bottomLeft: const Radius.circular(20),
                                    bottomRight: const Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: message.isSentByMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        message.text,
                                        style: TextStyle(
                                          color: message.isSentByMe
                                              ? Colors.white
                                              : const Color(0xFF333333),
                                          fontSize: 15,
                                          height: 1.3,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(message.timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: message.isSentByMe
                                            ? Colors.white.withOpacity(0.8)
                                            : const Color(0xFF999999),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (message.isSentByMe) ...[
                              const SizedBox(width: 8),
                              FutureBuilder<String>(
                                future: _getUserImage(_currentUserId),
                                builder: (context, snapshot) {
                                  final imageUrl = snapshot.data ?? 'https://i.pravatar.cc/300';
                                  return CircleAvatar(
                                    radius: 16,
                                    backgroundImage: imageUrl.startsWith('data:image/')
                                        ? MemoryImage(base64Decode(imageUrl.split(',').last))
                                        : NetworkImage(imageUrl) as ImageProvider,
                                    backgroundColor: const Color(0xFFE91E63),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.attach_file, size: 20, color: Color(0xFFE91E63)),
                          onPressed: () {
                            // Attachment functionality
                          },
                        ),
                      ),
                      maxLines: null,
                      minLines: 1,
                      expands: false,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x4DE91E63),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, size: 24, color: Colors.white),
                    onPressed: _controller.text.trim().isEmpty || !_isMutualMatch
                        ? null
                        : _sendMessage,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}