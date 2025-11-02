import 'dart:convert'; // Required for base64 decoding
import 'package:dating/ChatsListPage.dart';
import 'package:dating/chat_page.dart';
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
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> profiles = [];
  List<Map<String, dynamic>> swiperItems = []; // Flattened list for Swiper
  bool isLoading = true;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
    _loadUnreadNotifications();
  }

  // Fetch profiles and prepare swiper items
  Future<void> _fetchProfiles() async {
    if (!mounted) return; // Check before starting
    setState(() {
      isLoading = true;
    });
    try {
      final fetchedProfiles = await _profileService.getAllUsersForSwiping(
        limit: 20,
        includeDistanceFilter: true,
        maxDistance: 100.0,
      );

      List<Map<String, dynamic>> tempSwiperItems = [];
      for (var profile in fetchedProfiles) {
        final images = (profile['images'] as List?) ?? [];
        final profileImages = images.isNotEmpty
            ? images.take(3).toList()
            : ['https://i.pravatar.cc/300'];
        for (var image in profileImages) {
          tempSwiperItems.add({
            'image': image,
            'profileId': profile['id'],
            'name': profile['name'],
            'bio': profile['bio'],
            'city': profile['city'],
            'relationshipGoal': profile['relationshipGoal'],
            'imageCount': profileImages.length,
          });
        }
      }

      if (!mounted) return; // Check before updating state
      setState(() {
        profiles = fetchedProfiles;
        swiperItems = tempSwiperItems;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
      if (!mounted) return; // Check before updating state
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profiles: $e')),
      );
    }
  }

  // Load unread notifications count
  Future<void> _loadUnreadNotifications() async {
    try {
      final notifications = await _profileService.getUserNotifications();
      final unreadCount = notifications.where((n) => n['seen'] == false).length;
      if (mounted) {
        setState(() {
          _unreadNotifications = unreadCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  // Handle like action for the entire profile
  Future<void> _handleLike(String toUserId) async {
    if (_authService.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like profiles')),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }

    try {
      final success = await _profileService.saveLike(toUserId);
      if (success) {
        final isMutual = await _profileService.checkMutualLike(toUserId);
        if (isMutual) {
          // Match notification will be handled automatically by saveLike
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('It\'s a match! You can now chat.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Like saved! They\'ll be notified.')),
          );
        }
        _removeProfile(toUserId);
        // Refresh notifications count
        _loadUnreadNotifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save like')),
        );
      }
    } catch (e) {
      debugPrint('Error handling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Handle dislike action for the entire profile
  void _handleDislike(String toUserId) {
    debugPrint('Disliked user: $toUserId');
    _removeProfile(toUserId);
  }

  // Remove all images for a profile from swiperItems
  void _removeProfile(String profileId) {
    if (!mounted) return; // Check before updating state
    setState(() {
      swiperItems.removeWhere((item) => item['profileId'] == profileId);
      profiles.removeWhere((profile) => profile['id'] == profileId);
    });
  }

  // Navigate to likes page
  void _navigateToLikesPage() {
    Navigator.pushNamed(context, '/likes');
  }

  // Navigate to notifications page
  void _navigateToNotificationsPage() {
    Navigator.pushNamed(context, '/notifications');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Swipe For A Match',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFE91E63),
        centerTitle: true,
        actions: [
          // Notifications icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                tooltip: 'Notifications',
                onPressed: _navigateToNotificationsPage,
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
            onPressed: () async {
              try {
                await _authService.signOut();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logout failed: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : swiperItems.isEmpty
              ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text(
                        'No more profiles to show',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Check back later for new profiles',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchProfiles,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                        ),
                        child: const Text('Refresh Profiles', style: TextStyle(color: Colors.white),),
                      ),
                    ],
                  ),
              )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Swiper(
                        itemCount: swiperItems.length,
                        itemBuilder: (BuildContext context, int index) {
                          final item = swiperItems[index];
                          final imageUrl = item['image'];
                          debugPrint('Loading image for ${item['name']}: $imageUrl');

                          Widget imageWidget;
                          if (imageUrl.startsWith('data:image/')) {
                            try {
                              final base64Data = imageUrl.split(',').last;
                              final imageBytes = base64Decode(base64Data);
                              imageWidget = Image.memory(
                                imageBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Base64 image load error for ${item['name']}: $error');
                                  return Container(
                                    color: Colors.grey,
                                    child: const Center(
                                      child: Icon(Icons.error, color: Colors.white),
                                    ),
                                  );
                                },
                              );
                            } catch (e) {
                              debugPrint('Base64 decode error for ${item['name']}: $e');
                              imageWidget = Container(
                                color: Colors.grey,
                                child: const Center(
                                  child: Icon(Icons.error, color: Colors.white),
                                ),
                              );
                            }
                          } else {
                            imageWidget = Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('Network image load error for $imageUrl: $error');
                                return Container(
                                  color: Colors.grey,
                                  child: const Center(
                                    child: Icon(Icons.error, color: Colors.white),
                                  ),
                                );
                              },
                            );
                          }

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
                                  child: imageWidget,
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
                                      Text(
                                        item['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item['bio'] ?? 'No bio available',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item['city'] ?? 'Unknown City',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        'Goal: ${item['relationshipGoal'] ?? 'Not specified'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        itemWidth: MediaQuery.of(context).size.width * 0.9,
                        itemHeight: MediaQuery.of(context).size.height * 0.6,
                        layout: SwiperLayout.STACK,
                        onIndexChanged: (index) {
                          if (index < swiperItems.length) {
                            final item = swiperItems[index];
                            final profileId = item['profileId'];
                            final imageCount = item['imageCount'];
                            final shownImages = swiperItems
                                .sublist(0, index + 1)
                                .where((i) => i['profileId'] == profileId)
                                .length;
                            if (shownImages >= imageCount) {
                              debugPrint('Reached last image for profile $profileId');
                            }
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              if (swiperItems.isNotEmpty) {
                                final profileId = swiperItems[0]['profileId'];
                                _handleDislike(profileId);
                                _removeProfile(profileId);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (swiperItems.isNotEmpty) {
                                final profileId = swiperItems[0]['profileId'];
                                _handleLike(profileId);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF06292),
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              if (swiperItems.isNotEmpty) {
                                final profileId = swiperItems[0]['profileId'];
                                final isMutual = await _profileService.checkMutualLike(profileId);
                                if (isMutual) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatPage(
                                        toUserId: profileId,
                                        matchName: swiperItems[0]['name'],
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('You can only chat with mutual matches')),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF06292),
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                            ),
                            child: const Icon(
                              Icons.mail_outline,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 30),
                    Text(
                      "Profile",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _navigateToLikesPage,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatsListPage(),
                    ),
                  );
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat, color: Colors.white, size: 30),
                    Text(
                      "Chats",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _navigateToNotificationsPage,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        const Icon(Icons.notifications, color: Colors.white, size: 30),
                        if (_unreadNotifications > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 12,
                                minHeight: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Text(
                      "Alerts",
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
}