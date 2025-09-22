import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class Message {
  final String text;
  final bool isSentByMe;
  final DateTime timestamp;

  Message({required this.text, required this.isSentByMe, required this.timestamp});
}

class _ChatPageState extends State<ChatPage> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      setState(() {
        _messages.add(Message(
          text: _controller.text.trim(), 
          isSentByMe: true, 
          timestamp: DateTime.now()
        ));
        _controller.clear();
      });
      // Simulate a response from the other user after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _messages.add(Message(
              text: 'This is a simulated reply!', 
              isSentByMe: false, 
              timestamp: DateTime.now()
            ));
          });
        }
      });
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
                child: const CircleAvatar(
                  radius: 22,
                  backgroundImage: AssetImage('assets/images/welcome.png'),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Match Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Online',
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
          // Messages List - FIXED: Removed nested Expanded
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: _messages.isEmpty
                  ? const Center(
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
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra bottom padding for input
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: message.isSentByMe 
                                ? MainAxisAlignment.end 
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!message.isSentByMe) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey[300],
                                  child: const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Color(0xFF666666),
                                  ),
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
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFE91E63),
                                  child: const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          // Input Container - FIXED: Removed SafeArea and simplified structure
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
                
                // Text input
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
                
                // Send button - FIXED: Corrected shadow color syntax
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
                        color: Color(0x4DE91E63), // Fixed: Used hex alpha value
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, size: 24, color: Colors.white),
                    onPressed: _controller.text.trim().isEmpty ? null : _sendMessage,
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