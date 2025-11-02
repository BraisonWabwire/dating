import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ProfileService {
  // Firebase Instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current User ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ==================================================================
  // LOCATION: Get current location + city name
  // ==================================================================
  Future<Map<String, dynamic>?> getCurrentLocationWithCity() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? cityName = 'Unknown City';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          cityName = place.locality ?? place.administrativeArea ?? cityName;
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': cityName,
      };
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  // ==================================================================
  // IMAGE UPLOAD: Upload single image to Firebase Storage
  // ==================================================================
  Future<String?> _uploadImage(File imageFile, String userId) async {
    try {
      if (!await imageFile.exists()) {
        debugPrint('Image file does not exist: ${imageFile.path}');
        return null;
      }

      final fileName = 'profile_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);

      debugPrint('Uploading image: ${imageFile.path} to $fileName');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});

      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Image uploaded: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage Error [${e.code}]: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected upload error: $e');
      return null;
    }
  }

  // ==================================================================
  // IMAGE UPLOAD: Upload up to 3 images
  // ==================================================================
  Future<List<String>> _uploadImages(List<File?> images, String userId) async {
    final List<String> urls = [];

    for (int i = 0; i < images.length && i < 3; i++) {
      final file = images[i];
      if (file != null && await file.exists()) {
        final url = await _uploadImage(file, userId);
        if (url != null) {
          urls.add(url);
        }
      }
    }

    // Always return at least one image
    if (urls.isEmpty) {
      final defaultUrl = 'https://i.pravatar.cc/300?u=$userId';
      debugPrint('No images uploaded to using default: $defaultUrl');
      urls.add(defaultUrl);
    }

    return urls;
  }

  // ==================================================================
  // SAVE PROFILE: Create or update user profile
  // ==================================================================
  Future<bool> saveProfile({
    required String firstName,
    required String lastName,
    required String bio,
    required String relationshipGoal,
    required List<File?> images,
    Map<String, dynamic>? locationWithCity,
    String? city,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('saveProfile: No user logged in');
        return false;
      }

      debugPrint('Saving profile for user: $userId');

      // Upload images
      final imageUrls = await _uploadImages(images, userId);

      // Build profile data with fallbacks
      final cleanFirstName = firstName.trim().isNotEmpty ? firstName.trim() : 'User';
      final cleanLastName = lastName.trim();
      final fullName = '$cleanFirstName $cleanLastName'.trim();

      final profileData = {
        'userId': userId,
        'firstName': cleanFirstName,
        'lastName': cleanLastName,
        'fullName': fullName.isNotEmpty ? fullName : 'User',
        'bio': bio.trim().isNotEmpty ? bio.trim() : 'Hey, I\'m using the app!',
        'relationshipGoal':
            relationshipGoal.trim().isNotEmpty ? relationshipGoal.trim() : 'Open to anything',
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'privacySettings': {
          'showProfileToLikedUsers': true, // Default: allow profile visibility to liked users
          'showOnlineStatus': true,
        }
      };

      // Add location
      if (locationWithCity != null) {
        profileData['location'] = {
          'latitude': locationWithCity['latitude'],
          'longitude': locationWithCity['longitude'],
        };
        profileData['city'] = locationWithCity['city'] ?? city ?? 'Unknown City';
      } else {
        profileData['city'] = city ?? 'Unknown City';
      }

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .set(profileData, SetOptions(merge: true));

      debugPrint('Profile saved: $fullName | Images: ${imageUrls.length}');
      return true;
    } catch (e) {
      debugPrint('saveProfile error: $e');
      return false;
    }
  }

  // ==================================================================
  // GET USER PROFILE
  // ==================================================================
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      debugPrint('Profile not found: $userId');
      return null;
    } catch (e) {
      debugPrint('getUserProfile error: $e');
      return null;
    }
  }

  // ==================================================================
  // GET USER PROFILE WITH VISIBILITY CHECK
  // ==================================================================
  Future<Map<String, dynamic>?> getUserProfileWithVisibility(String userId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) return null;

      // Users can always see their own profile
      if (userId == currentUserId) {
        return await getUserProfile(userId);
      }

      final profile = await getUserProfile(userId);
      if (profile == null) return null;

      // Check if current user has liked this profile OR if this profile has liked current user
      final hasLiked = await _checkLikeExists(currentUserId, userId);
      final hasBeenLiked = await _checkLikeExists(userId, currentUserId);

      // Get privacy settings
      final privacySettings = profile['privacySettings'] as Map<String, dynamic>? ?? {};
      final showProfileToLikedUsers = privacySettings['showProfileToLikedUsers'] ?? true;

      // Allow profile visibility if:
      // 1. User has liked this profile OR this profile has liked current user
      // 2. AND the profile owner allows visibility to liked users
      if ((hasLiked || hasBeenLiked) && showProfileToLikedUsers) {
        return profile;
      }

      // Check if it's a mutual match
      final isMutualMatch = await checkMutualLike(userId);
      if (isMutualMatch) {
        return profile;
      }

      debugPrint('Profile access denied for $userId - no like relationship');
      return null;
    } catch (e) {
      debugPrint('getUserProfileWithVisibility error: $e');
      return null;
    }
  }

  // ==================================================================
  // UPDATE PROFILE FIELD
  // ==================================================================
  Future<bool> updateProfileField({
    required String field,
    required dynamic value,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      await _firestore.collection('users').doc(userId).update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Updated $field for $userId');
      return true;
    } catch (e) {
      debugPrint('updateProfileField error: $e');
      return false;
    }
  }

  // ==================================================================
  // UPDATE PRIVACY SETTINGS
  // ==================================================================
  Future<bool> updatePrivacySettings(Map<String, dynamic> settings) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      await _firestore.collection('users').doc(userId).update({
        'privacySettings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Privacy settings updated for $userId');
      return true;
    } catch (e) {
      debugPrint('updatePrivacySettings error: $e');
      return false;
    }
  }

  // ==================================================================
  // SAVE LIKE (with notification and visibility)
  // ==================================================================
  Future<bool> saveLike(String toUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final likeId = _generateSortedId(userId, toUserId);
      final likeData = {
        'fromUserId': userId,
        'toUserId': toUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false, // Track if the like has been seen by the recipient
      };

      // Save the like
      await _firestore.collection('likes').doc(likeId).set(likeData);

      // Create notification for the liked user
      await _createLikeNotification(userId, toUserId);

      // Check for mutual like and create match if needed
      final mutualLike = await checkMutualLike(toUserId);
      if (mutualLike) {
        await createMatch(toUserId);
        await _createMatchNotification(userId, toUserId);
      }

      debugPrint('Like saved: $userId to $toUserId | Mutual: $mutualLike');
      return true;
    } catch (e) {
      debugPrint('saveLike error: $e');
      return false;
    }
  }

  // ==================================================================
  // CREATE LIKE NOTIFICATION
  // ==================================================================
  Future<void> _createLikeNotification(String fromUserId, String toUserId) async {
    try {
      final fromUserProfile = await getUserProfile(fromUserId);
      if (fromUserProfile == null) return;

      final notificationId = '${DateTime.now().millisecondsSinceEpoch}_$fromUserId';
      final notificationData = {
        'type': 'like',
        'fromUserId': fromUserId,
        'fromUserName': fromUserProfile['fullName'] ?? 'Someone',
        'fromUserImage': (fromUserProfile['images'] as List?)?.isNotEmpty == true
            ? fromUserProfile['images'][0]
            : 'https://i.pravatar.cc/300?u=$fromUserId',
        'toUserId': toUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
        'mutual': false,
      };

      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notificationData);

      debugPrint('Like notification created for $toUserId from $fromUserId');
    } catch (e) {
      debugPrint('_createLikeNotification error: $e');
    }
  }

  // ==================================================================
  // CREATE MATCH NOTIFICATION
  // ==================================================================
  Future<void> _createMatchNotification(String user1Id, String user2Id) async {
    try {
      final user1Profile = await getUserProfile(user1Id);
      final user2Profile = await getUserProfile(user2Id);

      if (user1Profile == null || user2Profile == null) return;

      // Create notification for user1
      final notification1Id = '${DateTime.now().millisecondsSinceEpoch}_match_$user2Id';
      await _firestore.collection('notifications').doc(notification1Id).set({
        'type': 'match',
        'fromUserId': user2Id,
        'fromUserName': user2Profile['fullName'] ?? 'Someone',
        'fromUserImage': (user2Profile['images'] as List?)?.isNotEmpty == true
            ? user2Profile['images'][0]
            : 'https://i.pravatar.cc/300?u=$user2Id',
        'toUserId': user1Id,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
        'mutual': true,
      });

      // Create notification for user2
      final notification2Id = '${DateTime.now().millisecondsSinceEpoch}_match_$user1Id';
      await _firestore.collection('notifications').doc(notification2Id).set({
        'type': 'match',
        'fromUserId': user1Id,
        'fromUserName': user1Profile['fullName'] ?? 'Someone',
        'fromUserImage': (user1Profile['images'] as List?)?.isNotEmpty == true
            ? user1Profile['images'][0]
            : 'https://i.pravatar.cc/300?u=$user1Id',
        'toUserId': user2Id,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
        'mutual': true,
      });

      debugPrint('Match notifications created for $user1Id and $user2Id');
    } catch (e) {
      debugPrint('_createMatchNotification error: $e');
    }
  }

  // ==================================================================
  // GET USER NOTIFICATIONS
  // ==================================================================
  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('getUserNotifications error: $e');
      return [];
    }
  }

  // ==================================================================
  // MARK NOTIFICATION AS SEEN
  // ==================================================================
  Future<bool> markNotificationAsSeen(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'seen': true,
      });
      return true;
    } catch (e) {
      debugPrint('markNotificationAsSeen error: $e');
      return false;
    }
  }

  // ==================================================================
  // GET USERS WHO LIKED ME - SIMPLIFIED VERSION
  // ==================================================================
  Future<List<Map<String, dynamic>>> getUsersWhoLikedMe() async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      debugPrint('Fetching likes for user: $userId');

      // Get ALL likes for this user
      final snapshot = await _firestore
          .collection('likes')
          .where('toUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint('Found ${snapshot.docs.length} likes for user $userId');

      final List<Map<String, dynamic>> likers = [];

      for (var doc in snapshot.docs) {
        final likeData = doc.data();
        final likerId = likeData['fromUserId'];
        final seen = likeData['seen'] ?? false;
        
        debugPrint('Processing like from $likerId');

        // Get the liker's profile directly without visibility checks
        final profile = await getUserProfile(likerId);
        
        if (profile != null) {
          likers.add({
            'likeId': doc.id,
            'userId': likerId,
            'name': profile['fullName'] ?? 'Unknown',
            'image': (profile['images'] as List?)?.isNotEmpty == true
                ? profile['images'][0]
                : 'https://i.pravatar.cc/300?u=$likerId',
            'bio': profile['bio'] ?? '',
            'city': profile['city'] ?? 'Unknown',
            'relationshipGoal': profile['relationshipGoal'] ?? '',
            'timestamp': likeData['timestamp'],
            'seen': seen,
          });
          debugPrint('Added liker: ${profile['fullName']}');
        } else {
          debugPrint('Profile not found for liker: $likerId');
        }
      }

      // Mark unseen likes as seen
      final unseenLikes = likers.where((liker) => liker['seen'] == false).toList();
      for (var liker in unseenLikes) {
        try {
          await _firestore.collection('likes').doc(liker['likeId']).update({
            'seen': true,
          });
          debugPrint('Marked like ${liker['likeId']} as seen');
        } catch (e) {
          debugPrint('Error marking like as seen: $e');
        }
      }

      debugPrint('Returning ${likers.length} likers');
      return likers;
    } catch (e) {
      debugPrint('getUsersWhoLikedMe error: $e');
      return [];
    }
  }

  // ==================================================================
  // GET UNSEEN LIKES COUNT (for badges)
  // ==================================================================
  Future<int> getUnseenLikesCount() async {
    try {
      final userId = currentUserId;
      if (userId == null) return 0;

      final snapshot = await _firestore
          .collection('likes')
          .where('toUserId', isEqualTo: userId)
          .where('seen', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('getUnseenLikesCount error: $e');
      return 0;
    }
  }

  // ==================================================================
  // CHECK MUTUAL LIKE
  // ==================================================================
  Future<bool> checkMutualLike(String otherUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final userLike = await _firestore
          .collection('likes')
          .doc(_generateSortedId(userId, otherUserId))
          .get();

      if (!userLike.exists) return false;

      final otherLike = await _firestore
          .collection('likes')
          .doc(_generateSortedId(otherUserId, userId))
          .get();

      return otherLike.exists;
    } catch (e) {
      debugPrint('checkMutualLike error: $e');
      return false;
    }
  }

  // ==================================================================
  // CREATE MATCH
  // ==================================================================
  Future<bool> createMatch(String otherUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final matchId = _generateSortedId(userId, otherUserId);
      final matchData = {
        'userIds': [userId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
      };

      await _firestore.collection('matches').doc(matchId).set(matchData);
      debugPrint('Match created: $matchId');
      return true;
    } catch (e) {
      debugPrint('createMatch error: $e');
      return false;
    }
  }

  // ==================================================================
  // GET MUTUAL MATCHES (for ChatsListPage)
  // ==================================================================
  Future<List<Map<String, dynamic>>> getMutualMatches() async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('matches')
          .where('userIds', arrayContains: userId)
          .get();

      final List<Map<String, dynamic>> matches = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final otherId = (data['userIds'] as List).firstWhere((id) => id != userId);
        final profile = await getUserProfile(otherId);

        if (profile != null) {
          matches.add({
            'userId': otherId,
            'name': profile['fullName'] ?? 'Unknown',
            'image': (profile['images'] as List?)?.isNotEmpty == true
                ? profile['images'][0]
                : 'https://i.pravatar.cc/300?u=$otherId',
            'lastMessage': data['lastMessage'],
            'lastMessageTime': data['lastMessageTime'],
          });
        }
      }

      debugPrint('Loaded ${matches.length} mutual matches');
      return matches;
    } catch (e) {
      debugPrint('getMutualMatches error: $e');
      return [];
    }
  }

  // ==================================================================
  // GET USERS FOR SWIPING – DEBUG-FRIENDLY & ROBUST
  // ==================================================================
  Future<List<Map<String, dynamic>>> getAllUsersForSwiping({
    int limit = 20,
    bool includeDistanceFilter = false,   // DEFAULT OFF
    double maxDistance = 100.0,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('getAllUsersForSwiping: no logged-in user');
        return [];
      }

      debugPrint('Fetching swipes for $userId (limit: $limit)');

      // 1. Current profile (optional for distance)
      final currentProfile = await getUserProfile(userId);
      if (currentProfile == null) {
        debugPrint('Current user has NO profile to distance filter disabled');
      } else {
        debugPrint('Current profile: ${currentProfile['fullName']}');
      }

      // 2. Query all other users
      final snapshot = await _firestore
          .collection('users')
          .where('userId', isNotEqualTo: userId)
          .limit(limit)
          .get();

      debugPrint('Firestore returned ${snapshot.docs.length} other users');

      final List<Map<String, dynamic>> result = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final otherId = doc.id;

        debugPrint('\n--- Checking $otherId ---');
        debugPrint('  fullName: ${data['fullName']}');
        debugPrint('  images count: ${(data['images'] as List?)?.length ?? 0}');
        debugPrint('  city: ${data['city']}');
        debugPrint('  location: ${data['location']}');

        // Mandatory fields
        final images = (data['images'] as List?) ?? [];
        if (data['fullName'] == null || images.isEmpty) {
          debugPrint('  SKIPPED – missing name or image');
          continue;
        }

        // Already liked?
        bool alreadyLiked = false;
        try {
          final likeDoc = await _firestore
              .collection('likes')
              .doc(_generateSortedId(userId, otherId))
              .get();
          alreadyLiked = likeDoc.exists;
        } catch (_) {
          // collection missing → treat as not liked
        }
        if (alreadyLiked) {
          debugPrint('  SKIPPED – already liked');
          continue;
        }

        // Distance (only if enabled)
        double distance = 999;
        if (currentProfile != null && includeDistanceFilter) {
          distance = _calculateDistance(
            data['location']?['latitude'],
            data['location']?['longitude'],
            currentProfile['location']?['latitude'],
            currentProfile['location']?['longitude'],
          );
          debugPrint('  Distance: $distance km');
          if (distance > maxDistance) {
            debugPrint('  SKIPPED – too far');
            continue;
          }
        }

        // Add to result
        result.add({
          'id': otherId,
          'name': data['fullName'],
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'bio': data['bio'] ?? 'No bio',
          'city': data['city'] ?? 'Unknown',
          'relationshipGoal': data['relationshipGoal'] ?? '',
          'images': images.take(3).toList(),
          'distance': distance,
          'compatibilityScore': _calculateCompatibilityScore(currentProfile, data),
        });
        debugPrint('  ADDED');
      }

      // Sort by compatibility
      result.sort((a, b) =>
          (b['compatibilityScore'] as double).compareTo(a['compatibilityScore'] as double));

      debugPrint('Returning ${result.length} swipeable profiles');
      return result;
    } catch (e, s) {
      debugPrint('EXCEPTION in getAllUsersForSwiping: $e\n$s');
      return [];
    }
  }

  // ==================================================================
  // HELPER: Check if like exists
  // ==================================================================
  Future<bool> _checkLikeExists(String fromUserId, String toUserId) async {
    try {
      final likeDoc = await _firestore
          .collection('likes')
          .doc(_generateSortedId(fromUserId, toUserId))
          .get();
      return likeDoc.exists;
    } catch (e) {
      return false;
    }
  }

  // ==================================================================
  // HELPER: Generate sorted ID (e.g., "abc_xyz")
  // ==================================================================
  String _generateSortedId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // ==================================================================
  // HELPER: Calculate compatibility score
  // ==================================================================
  double _calculateCompatibilityScore(
    Map<String, dynamic>? current,
    Map<String, dynamic> other,
  ) {
    if (current == null) return 0.0;

    double score = 0.0;

    final goal1 = current['relationshipGoal']?.toString().toLowerCase();
    final goal2 = other['relationshipGoal']?.toString().toLowerCase();
    if (goal1 == goal2 && goal1 != null) score += 0.5;

    final distance = _calculateDistance(
      other['location']?['latitude'],
      other['location']?['longitude'],
      current['location']?['latitude'],
      current['location']?['longitude'],
    );
    if (distance < 50) score += 0.3 * (1 - distance / 50);

    return score;
  }

  // ==================================================================
  // HELPER: Haversine distance
  // ==================================================================
  double _calculateDistance(
    dynamic lat1,
    dynamic lng1,
    dynamic lat2,
    dynamic lng2,
  ) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return 999;

    const R = 6371; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);
}