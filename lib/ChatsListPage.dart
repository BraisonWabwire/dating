import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() {
      isLoading = true;
    });
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        debugPrint('No user logged in');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view matches')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      final fetchedMatches = await _profileService.getMutualMatches();
      setState(() {
        matches = fetchedMatches;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching matches: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load matches: $e')));
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : matches.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Color(0xFFCCCCCC),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No matches yet. Keep swiping!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                final imageUrl = match['image'] ?? 'https://i.pravatar.cc/300';

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
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint(
                        'Network image load error for $imageUrl: $error',
                      );
                      return const Icon(Icons.error, color: Colors.grey);
                    },
                  );
                }

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      child: ClipOval(child: imageWidget),
                      backgroundColor: Colors.grey[200],
                    ),
                    title: Text(
                      match['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      match['lastMessage'] ?? 'Start a conversation',
                      style: TextStyle(
                        fontSize: 14,
                        color: match['lastMessage'] != null
                            ? Colors.black54
                            : Colors.grey,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            toUserId: match['userId'],
                            matchName: match['name'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
