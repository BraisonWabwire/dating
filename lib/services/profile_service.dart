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

      debugPrint('Uploading image: ${imageFile.path} → $fileName');
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
      debugPrint('No images uploaded → using default: $defaultUrl');
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
  // SAVE LIKE
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
      };

      await _firestore.collection('likes').doc(likeId).set(likeData);
      debugPrint('Like saved: $userId → $toUserId');
      return true;
    } catch (e) {
      debugPrint('saveLike error: $e');
      return false;
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
  // GET USERS FOR SWIPING
  // ==================================================================
  Future<List<Map<String, dynamic>>> getAllUsersForSwiping({
    int limit = 20,
    bool includeDistanceFilter = false,
    double maxDistance = 100.0,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      final currentProfile = await getUserProfile(userId);
      if (currentProfile == null) {
        debugPrint('Current user profile missing');
        return [];
      }

      final query = _firestore
          .collection('users')
          .where('userId', isNotEqualTo: userId)
          .limit(limit);

      final snapshot = await query.get();
      debugPrint('Found ${snapshot.docs.length} potential profiles');

      final List<Map<String, dynamic>> users = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final profileId = doc.id;

        // Required: fullName + at least one image
        final images = (data['images'] as List?) ?? [];
        if (data['fullName'] == null || images.isEmpty) {
          debugPrint('Skipping $profileId: missing name or image');
          continue;
        }

        // Skip if already liked
        try {
          final likeDoc = await _firestore
              .collection('likes')
              .doc(_generateSortedId(userId, profileId))
              .get();
          if (likeDoc.exists) {
            debugPrint('Already liked: $profileId');
            continue;
          }
        } catch (e) {
          debugPrint('Likes check failed (OK): $e');
        }

        // Distance
        final distance = _calculateDistance(
          data['location']?['latitude'],
          data['location']?['longitude'],
          currentProfile['location']?['latitude'],
          currentProfile['location']?['longitude'],
        );

        if (includeDistanceFilter && distance > maxDistance) {
          debugPrint('Too far: $profileId ($distance km)');
          continue;
        }

        // Add to swipe list
        users.add({
          'id': profileId,
          'name': data['fullName'],
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'bio': data['bio'] ?? 'No bio',
          'city': data['city'] ?? 'Unknown',
          'relationshipGoal': data['relationshipGoal'] ?? '',
          'images': images.take(3).toList(),
          'location': data['location'],
          'distance': distance,
          'compatibilityScore': _calculateCompatibilityScore(currentProfile, data),
        });
      }

      // Sort by compatibility
      users.sort((a, b) => (b['compatibilityScore'] as double)
          .compareTo(a['compatibilityScore'] as double));

      debugPrint('Returning ${users.length} swipeable profiles');
      return users;
    } catch (e) {
      debugPrint('getAllUsersForSwiping error: $e');
      return [];
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