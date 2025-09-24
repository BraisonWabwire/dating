import 'package:dating/services/auth_service.dart';
import 'package:dating/services/profile_service.dart'; // Import ProfileService
import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';

class Profiles extends StatefulWidget {
  const Profiles({super.key});

  @override
  State<Profiles> createState() => _ProfilesState();
}

class _ProfilesState extends State<Profiles> {
  final ProfileService _profileService = ProfileService(); // Initialize ProfileService
  List<Map<String, dynamic>> profiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  // Fetch profiles from ProfileService
  Future<void> _fetchProfiles() async {
    setState(() {
      isLoading = true;
    });
    try {
      final fetchedProfiles = await _profileService.getAllUsersForSwiping(
        limit: 20,
        includeDistanceFilter: true,
        maxDistance: 100.0,
      );
      setState(() {
        profiles = fetchedProfiles;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profiles: $e')),
      );
    }
  }

  // Handle like action
  Future<void> _handleLike(String toUserId) async {
    try {
      final success = await _profileService.saveLike(toUserId);
      if (success) {
        final isMutual = await _profileService.checkMutualLike(toUserId);
        if (isMutual) {
          await _profileService.createMatch(toUserId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Match created!')),
          );
        }
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

  // Handle dislike action (optional: can be extended for additional logic)
  void _handleDislike(String toUserId) {
    // Optionally implement logic for disliking (e.g., save to Firestore)
    debugPrint('Disliked user: $toUserId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Swipe For A Match',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFE91E63),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
            onPressed: () async {
              try {
                final authService = AuthService();
                await authService.signOut();
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
          : profiles.isEmpty
              ? const Center(child: Text('No profiles available'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Swiper(
                        itemCount: profiles.length,
                        itemBuilder: (BuildContext context, int index) {
                          final profile = profiles[index];
                          final imageUrl = (profile['images'] as List).isNotEmpty
                              ? profile['images'][0]
                              : 'https://i.pravatar.cc/300'; // Fallback image
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
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey,
                                        child: const Center(
                                          child: Icon(Icons.error, color: Colors.white),
                                        ),
                                      );
                                    },
                                  ),
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
                                        profile['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        profile['bio'] ?? 'No bio available',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        profile['city'] ?? 'Unknown City',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        'Goal: ${profile['relationshipGoal'] ?? 'Not specified'}',
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
                          // Optional: Handle index change if needed
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
                              if (profiles.isNotEmpty) {
                                _handleDislike(profiles[0]['id']);
                                setState(() {
                                  profiles.removeAt(0);
                                });
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
                              if (profiles.isNotEmpty) {
                                _handleLike(profiles[0]['id']);
                                setState(() {
                                  profiles.removeAt(0);
                                });
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
                            onPressed: () {
                              Navigator.pushNamed(context, '/Chat_page');
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
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, color: Colors.white, size: 30),
                  Text(
                    "Likes",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/Chat_page');
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
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, color: Colors.white, size: 30),
                  Text(
                    "Search",
                    style: TextStyle(color: Colors.white, fontSize: 12),
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