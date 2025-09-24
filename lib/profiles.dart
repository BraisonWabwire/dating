import 'package:dating/services/auth_service.dart';
import 'package:dating/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';

class Profiles extends StatefulWidget {
  const Profiles({super.key});

  @override
  State<Profiles> createState() => _ProfilesState();
}

class _ProfilesState extends State<Profiles> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final SwiperController _swiperController = SwiperController();
  
  List<Map<String, dynamic>> profiles = [];
  bool isLoading = true;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndProfiles();
  }

  // Load current user and fetch profiles
  Future<void> _loadCurrentUserAndProfiles() async {
    try {
      setState(() {
        isLoading = true;
      });

      currentUserId = _authService.currentUser?.uid;
      debugPrint('Current user ID: $currentUserId');

      if (currentUserId != null) {
        await _fetchUserProfiles();
      }
    } catch (e) {
      debugPrint('Error loading profiles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profiles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Fetch user profiles with matching criteria
  Future<void> _fetchUserProfiles() async {
    try {
      debugPrint('Fetching user profiles from Firestore...');
      
      final userProfiles = await _profileService.getAllUsersForSwiping(
        limit: 50,
        includeDistanceFilter: true,
        maxDistance: 100.0, // 100km radius
      );

      debugPrint('Loaded ${userProfiles.length} matching profiles');
      
      if (mounted) {
        setState(() {
          profiles = userProfiles;
        });
      }

    } catch (e) {
      debugPrint('Error fetching profiles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profiles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Refresh profiles
  Future<void> _refreshProfiles() async {
    await _loadCurrentUserAndProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF06292),
      appBar: AppBar(
        title: const Text(
          'Swipe For A Match',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFE91E63),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Profiles',
            onPressed: _refreshProfiles,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
            onPressed: () async {
              try {
                await _authService.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: profiles.isEmpty && !isLoading
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refreshProfiles,
              color: const Color(0xFFE91E63),
              child: Column(
                children: [
                  if (isLoading)
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF06292),
                              Color(0xFFE91E63),
                              Color(0xFFAD1457),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading profiles...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Swiper(
                          controller: _swiperController,
                          itemCount: profiles.length,
                          itemBuilder: (BuildContext context, int index) {
                            final profile = profiles[index];
                            return _buildProfileCard(profile);
                          },
                          itemWidth: MediaQuery.of(context).size.width * 0.9,
                          itemHeight: MediaQuery.of(context).size.height * 0.65,
                          layout: SwiperLayout.STACK,
                          onIndexChanged: (index) {
                            debugPrint('Swiped to profile ${index + 1}/${profiles.length}');
                          },
                          onTap: (index) {
                            _showProfileDetails(profiles[index]);
                          },
                        ),
                      ),
                    ),
                  
                  if (!isLoading && profiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: Icons.close,
                            color: Colors.red,
                            onPressed: () => _onSwipe(0, 'reject'),
                          ),
                          _buildActionButton(
                            icon: Icons.favorite,
                            color: const Color(0xFFF06292),
                            onPressed: () => _onSwipe(0, 'like'),
                          ),
                          _buildActionButton(
                            icon: Icons.mail_outline,
                            color: const Color(0xFFF06292),
                            onPressed: () => _onSwipe(0, 'message'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFE91E63),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/update_profile');
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.person, color: Colors.white, size: 30),
                    Text(
                      "Profile",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/likes');
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.favorite, color: Colors.white, size: 30),
                    Text(
                      "Likes",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/chats');
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.chat, color: Colors.white, size: 30),
                    Text(
                      "Chats",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/search');
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.search, color: Colors.white, size: 30),
                    Text(
                      "Search",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build empty state
  Widget _buildEmptyState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF06292),
            Color(0xFFE91E63),
            Color(0xFFAD1457),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No profiles available',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text(
              'Pull down to refresh or complete your profile',
              style: TextStyle(fontSize: 14, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build profile card
  Widget _buildProfileCard(Map<String, dynamic> profile) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _buildProfileImage(profile['images']?.isNotEmpty == true ? profile['images'][0] : 'https://i.pravatar.cc/300'),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color.fromRGBO(0, 0, 0, 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        profile['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile['city'] != null && profile['city'] != 'Unknown')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          profile['city'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile['bio'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (profile['relationshipGoal']?.isNotEmpty == true)
                  Text(
                    'Looking for: ${profile['relationshipGoal']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (profile['distance'] != null && (profile['distance'] as double) < 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${profile['distance']?.toStringAsFixed(1)} km away',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build profile image with error handling
  Widget _buildProfileImage(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.person,
            size: 80,
            color: Colors.grey,
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
            ),
          ),
        );
      },
    );
  }

  // Build action button
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        elevation: 4,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  // Handle swipe actions
  void _onSwipe(int index, String action) {
    if (profiles.isEmpty) return;

    final profile = profiles[index];
    final userId = profile['id'];
    
    debugPrint('Action "$action" on user: $userId');

    switch (action) {
      case 'like':
        _handleLike(userId, profile);
        break;
      case 'reject':
        _handleReject(userId, profile);
        break;
      case 'message':
        _handleMessage(userId, profile);
        break;
    }
  }

  // Handle like action
  Future<void> _handleLike(String userId, Map<String, dynamic> profile) async {
    try {
      if (currentUserId == null) return;

      // Save like
      final success = await _profileService.saveLike(userId);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to like profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check for mutual like
      final mutualLike = await _profileService.checkMutualLike(userId);
      
      if (mutualLike) {
        await _profileService.createMatch(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('It\'s a match with ${profile['name']}!'),
              backgroundColor: const Color(0xFFF06292),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You liked ${profile['name']}!'),
              backgroundColor: const Color(0xFFF06292),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      
      // Swipe to next card
      if (_swiperController.index < profiles.length - 1) {
        _swiperController.next();
      } else {
        setState(() {
          profiles.removeAt(0);
        });
      }
      
    } catch (e) {
      debugPrint('Error handling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error liking profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle reject action
  Future<void> _handleReject(String userId, Map<String, dynamic> profile) async {
    try {
      debugPrint('Rejected user: $userId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile skipped'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      if (_swiperController.index < profiles.length - 1) {
        _swiperController.next();
      } else {
        setState(() {
          profiles.removeAt(0);
        });
      }
      
    } catch (e) {
      debugPrint('Error handling reject: $e');
    }
  }

  // Handle message action
  Future<void> _handleMessage(String userId, Map<String, dynamic> profile) async {
    try {
      debugPrint('Message user: $userId');
      
      // Check if there's a match before allowing messaging
      final mutualLike = await _profileService.checkMutualLike(userId);
      if (!mutualLike) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You need to match before messaging'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'userId': userId,
            'userName': profile['name'],
            'userProfile': profile['fullProfile'],
          },
        );
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show profile details on tap
  void _showProfileDetails(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF06292),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  profile['images']?.isNotEmpty == true 
                    ? profile['images'][0] 
                    : 'https://i.pravatar.cc/300',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  profile['name'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile['bio'] ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                if (profile['city'] != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white54, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'From ${profile['city']}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                if (profile['relationshipGoal'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.white54, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Looking for: ${profile['relationshipGoal']}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                if (profile['distance'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.map, color: Colors.white54, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${profile['distance']?.toStringAsFixed(1)} km away',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _onSwipe(0, 'like');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE91E63),
              ),
              child: const Text('Like'),
            ),
          ],
        );
      },
    );
  }
}