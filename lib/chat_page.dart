import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating/services/auth_service.dart';
import 'package:dating/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class ChatPage extends StatefulWidget {
  final String toUserId;
  final String matchName;

  const ChatPage({super.key, required this.toUserId, required this.matchName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class Message {
  final String text;
  final bool isSentByMe;
  final DateTime timestamp;
  final String messageId;
  final String senderId;

  Message({
    required this.text,
    required this.isSentByMe,
    required this.timestamp,
    required this.messageId,
    required this.senderId,
  });

  factory Message.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      messageId: doc.id,
      text: data['text'] ?? '',
      isSentByMe: data['senderId'] == currentUserId,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      senderId: data['senderId'] ?? '',
    );
  }
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  
  late String _currentUserId;
  late String _chatId;
  bool _isMutualMatch = false;
  bool _isInitialized = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final currentUser = _authService.currentUserId;
      if (currentUser == null) {
        _showErrorAndNavigate('Please log in to continue');
        return;
      }

      _currentUserId = currentUser;
      _chatId = _generateChatId(_currentUserId, widget.toUserId);
      debugPrint('Chat initialized - ID: $_chatId, Current User: $_currentUserId, To User: ${widget.toUserId}');

      // Check if mutual match exists
      _isMutualMatch = await _profileService.checkMutualLike(widget.toUserId);
      debugPrint('Mutual match check: $_isMutualMatch');
      
      if (!_isMutualMatch) {
        _showError('You can only chat with mutual matches');
      }

      // Ensure chat document exists
      await _ensureChatExists();
      
      setState(() {
        _isInitialized = true;
      });

      // Scroll to bottom after initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      _showError('Failed to initialize chat: $e');
    }
  }

  String _generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _ensureChatExists() async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(_chatId).get();
      if (!chatDoc.exists) {
        // Create chat document with basic info
        await _firestore.collection('chats').doc(_chatId).set({
          'userIds': [_currentUserId, widget.toUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageTime': null,
        });
        debugPrint('Chat document created: $_chatId');
      }
    } catch (e) {
      debugPrint('Error ensuring chat exists: $e');
      throw e;
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    if (!_isMutualMatch) {
      _showError('You can only chat with mutual matches');
      return;
    }
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    final messageText = _controller.text.trim();
    
    try {
      // Create the message
      final messageData = {
        'senderId': _currentUserId,
        'receiverId': widget.toUserId,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add message to subcollection
      await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add(messageData);

      // Update last message in chat document
      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _currentUserId,
      });

      debugPrint('Message sent successfully: $messageText');
      _controller.clear();
      
      // Scroll to bottom after sending
      _scrollToBottom();
      
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showError('Failed to send message: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorAndNavigate(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<String> _getUserImage(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final images = doc.data()?['images'] as List?;
        return images?.isNotEmpty ?? false ? images![0] : 'https://i.pravatar.cc/300';
      }
      return 'https://i.pravatar.cc/300';
    } catch (e) {
      debugPrint('Error fetching user image: $e');
      return 'https://i.pravatar.cc/300';
    }
  }

  Widget _buildMessageBubble(Message message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: message.isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isSentByMe) ...[
            FutureBuilder<String>(
              future: _getUserImage(widget.toUserId),
              builder: (context, snapshot) {
                final imageUrl = snapshot.data ?? 'https://i.pravatar.cc/300';
                return CircleAvatar(
                  radius: 16,
                  backgroundImage: _getImageProvider(imageUrl),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: message.isSentByMe
                      ? [const Color(0xFFE91E63), const Color(0xFFF06292)]
                      : [Color(0xFFF5F5F5), Color(0xFFE8E8E8)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: message.isSentByMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: message.isSentByMe ? const Radius.circular(4) : const Radius.circular(20),
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
                crossAxisAlignment: message.isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isSentByMe ? Colors.white : const Color(0xFF333333),
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: message.isSentByMe ? Colors.white.withOpacity(0.8) : const Color(0xFF999999),
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
                  backgroundImage: _getImageProvider(imageUrl),
                  backgroundColor: const Color(0xFFE91E63),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  ImageProvider _getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64Data = imageUrl.split(',').last;
        final imageBytes = base64Decode(base64Data);
        return MemoryImage(imageBytes);
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return const AssetImage('assets/default_avatar.png');
      }
    } else {
      return NetworkImage(imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF06292),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF06292),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF06292),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            FutureBuilder<String>(
              future: _getUserImage(widget.toUserId),
              builder: (context, snapshot) {
                return CircleAvatar(
                  radius: 20,
                  backgroundImage: _getImageProvider(snapshot.data ?? 'https://i.pravatar.cc/300'),
                  backgroundColor: Colors.white,
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                stream: _firestore
                    .collection('chats')
                    .doc(_chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    debugPrint('Chat stream error: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading messages',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _initialize,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
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
                            'Start a conversation!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF999999),
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
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(messages[index]);
                    },
                  );
                },
              ),
            ),
          ),
          // Message input area remains the same as your original code
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
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _controller.text.trim().isEmpty || !_isMutualMatch || _isSending
                        ? null
                        : _sendMessage,
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
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return 'Now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${timestamp.day}/${timestamp.month}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}