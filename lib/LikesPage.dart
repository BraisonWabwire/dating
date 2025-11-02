import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dating/services/profile_service.dart';
import 'package:dating/services/auth_service.dart';
import 'package:dating/chat_page.dart';

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _likers = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadLikers();
  }

  Future<void> _loadLikers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final likers = await _profileService.getUsersWhoLikedMe();
      if (!mounted) return;
      
      setState(() {
        _likers = likers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading likers: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _handleLikeBack(String userId) async {
    try {
      final success = await _profileService.saveLike(userId);
      if (success) {
        final isMutual = await _profileService.checkMutualLike(userId);
        if (isMutual) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('It\'s a match! You can now chat.'),
              backgroundColor: Colors.green,
            ),
          );
          // Remove from list since it's now a match
          setState(() {
            _likers.removeWhere((liker) => liker['userId'] == userId);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Like sent! Waiting for their response.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send like'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error liking back: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewProfile(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => ProfileDialog(
        userId: userId,
        userName: userName,
        profileService: _profileService,
        onLike: () => _handleLikeBack(userId),
      ),
    );
  }

  void _startChat(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          toUserId: userId,
          matchName: userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'People Who Liked You',
          style: TextStyle(
            fontSize: 20,
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
            onPressed: _loadLikers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load likes',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLikers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _likers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No likes yet',
                            style: TextStyle(fontSize: 20, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When someone likes you, they\'ll appear here',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                            ),
                            child: const Text('Keep Swiping', style: TextStyle(color: Colors.white),),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLikers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _likers.length,
                        itemBuilder: (context, index) {
                          final liker = _likers[index];
                          final userId = liker['userId'];
                          final userName = liker['name'];
                          final userImage = liker['image'];
                          final userBio = liker['bio'];
                          final userCity = liker['city'];
                          final timestamp = liker['timestamp'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Profile Image
                                  GestureDetector(
                                    onTap: () => _viewProfile(userId, userName),
                                    child: CircleAvatar(
                                      radius: 30,
                                      backgroundImage: NetworkImage(userImage),
                                      onBackgroundImageError: (exception, stackTrace) {
                                        debugPrint('Image load error: $exception');
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // User Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (userBio.isNotEmpty)
                                          Text(
                                            userBio,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          userCity,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        if (timestamp != null)
                                          Text(
                                            _formatTimestamp(timestamp),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Action Buttons
                                  Column(
                                    children: [
                                      // Like Back Button
                                      IconButton(
                                        onPressed: () => _handleLikeBack(userId),
                                        icon: const Icon(Icons.favorite),
                                        color: const Color(0xFFE91E63),
                                        tooltip: 'Like Back',
                                      ),
                                      const SizedBox(height: 8),
                                      // Chat Button (only if mutual match)
                                      FutureBuilder<bool>(
                                        future: _profileService.checkMutualLike(userId),
                                        builder: (context, snapshot) {
                                          final isMutual = snapshot.data ?? false;
                                          if (isMutual) {
                                            return IconButton(
                                              onPressed: () => _startChat(userId, userName),
                                              icon: const Icon(Icons.chat),
                                              color: Colors.blue,
                                              tooltip: 'Start Chat',
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return '';
      
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
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      
      return '${time.day}/${time.month}/${time.year}';
    } catch (e) {
      return '';
    }
  }
}

// Profile Dialog for viewing liker's full profile
class ProfileDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final ProfileService profileService;
  final VoidCallback onLike;

  const ProfileDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.profileService,
    required this.onLike,
  });

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.profileService.getUserProfileWithVisibility(widget.userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : _profile == null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Profile Not Available',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This user\'s profile is no longer available',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with name and close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _profile!['fullName'] ?? widget.userName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Profile Images
                        if ((_profile!['images'] as List?)?.isNotEmpty == true)
                          SizedBox(
                            height: 200,
                            child: PageView.builder(
                              itemCount: _profile!['images'].length,
                              itemBuilder: (context, index) {
                                final imageUrl = _profile!['images'][index];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(Icons.error, color: Colors.grey),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        
                        const SizedBox(height: 20),
                        
                        // Bio
                        if (_profile!['bio'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'About',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _profile!['bio'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        
                        // Relationship Goal
                        if (_profile!['relationshipGoal'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Relationship Goal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _profile!['relationshipGoal'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        
                        // City
                        if (_profile!['city'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _profile!['city'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        
                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.onLike,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE91E63),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.favorite),
                                label: const Text('Like Back'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FutureBuilder<bool>(
                              future: widget.profileService.checkMutualLike(widget.userId),
                              builder: (context, snapshot) {
                                final isMutual = snapshot.data ?? false;
                                return Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: isMutual
                                        ? () {
                                            Navigator.pop(context); // Close dialog
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatPage(
                                                  toUserId: widget.userId,
                                                  matchName: _profile!['fullName'] ?? widget.userName,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isMutual ? Colors.blue : Colors.grey,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.chat),
                                    label: const Text('Chat'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}