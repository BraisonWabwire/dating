import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating/chat_page.dart';
import 'package:dating/services/auth_service.dart';
import 'package:dating/services/profile_service.dart';
import 'package:flutter/material.dart';

class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> matches = [];
  bool isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      _hasError = false;
    });
    
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        debugPrint('No user logged in');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to view matches')),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
        return;
      }

      final fetchedMatches = await _profileService.getMutualMatches();
      if (!mounted) return;
      
      setState(() {
        matches = fetchedMatches;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching matches: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load matches: $e')),
      );
    }
  }

  void _refreshMatches() {
    _fetchMatches();
  }

  String _formatLastMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      DateTime time;
      if (timestamp is Timestamp) {
        time = timestamp.toDate();
      } else if (timestamp is DateTime) {
        time = timestamp;
      } else {
        return '';
      }
      
      final now = DateTime.now();
      final difference = now.difference(time);
      
      if (difference.inMinutes < 1) return 'Now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m';
      if (difference.inHours < 24) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}d';
      
      return '${time.month}/${time.day}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Matches',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFE91E63),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshMatches,
            tooltip: 'Refresh matches',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load matches',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshMatches,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : matches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Color(0xFFCCCCCC),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No matches yet',
                            style: TextStyle(
                              fontSize: 20,
                              color: Color(0xFF999999),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Keep swiping to find matches!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF999999),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                            ),
                            child: const Text('Start Swiping'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchMatches,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final match = matches[index];
                          final imageUrl = match['image'] ?? 'https://i.pravatar.cc/300';
                          final lastMessage = match['lastMessage'];
                          final lastMessageTime = match['lastMessageTime'];

                          Widget imageWidget;
                          if (imageUrl.startsWith('data:image/')) {
                            try {
                              final base64Data = imageUrl.split(',').last;
                              final imageBytes = base64Decode(base64Data);
                              imageWidget = Image.memory(
                                imageBytes,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint(
                                    'Base64 image load error for ${match['name']}: $error',
                                  );
                                  return const Icon(Icons.error, color: Colors.grey);
                                },
                              );
                            } catch (e) {
                              debugPrint('Base64 decode error for ${match['name']}: $e');
                              imageWidget = const Icon(Icons.error, color: Colors.grey);
                            }
                          } else {
                            imageWidget = Image.network(
                              imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint(
                                  'Network image load error for $imageUrl: $error',
                                );
                                return Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                );
                              },
                            );
                          }

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE91E63),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(child: imageWidget),
                              ),
                              title: Text(
                                match['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    lastMessage ?? 'Start a conversation',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: lastMessage != null
                                          ? Colors.black54
                                          : Colors.grey,
                                      fontWeight: lastMessage != null 
                                          ? FontWeight.normal 
                                          : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: lastMessageTime != null
                                  ? Text(
                                      _formatLastMessageTime(lastMessageTime),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      toUserId: match['userId'],
                                      matchName: match['name'],
                                    ),
                                  ),
                                ).then((_) {
                                  // Refresh matches when returning from chat
                                  _fetchMatches();
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}