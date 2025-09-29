import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current location
  Future<Map<String, dynamic>?> getCurrentLocationWithCity() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? cityName;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          cityName = place.locality ?? place.administrativeArea ?? 'Unknown City';
        } else {
          cityName = 'Unknown City';
        }
      } catch (e) {
        debugPrint('Error getting city name: $e');
        cityName = 'Unknown City';
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': cityName,
      };
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  // Upload single image to Firebase Storage
  Future<String?> _uploadImage(File imageFile, String userId) async {
    try {
      final fileName = 'profile_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Upload multiple images
  Future<List<String>> _uploadImages(List<File?> images, String userId) async {
    List<String> imageUrls = [];
    
    for (int i = 0; i < images.length && i < 3; i++) {
      if (images[i] != null) {
        final url = await _uploadImage(images[i]!, userId);
        if (url != null) {
          imageUrls.add(url);
        }
      }
    }
    
    // If no images are uploaded, provide a default image
    if (imageUrls.isEmpty) {
      imageUrls.add('https://i.pravatar.cc/300');
    }
    
    return imageUrls;
  }

  // Save profile to Firestore
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
        debugPrint('No user logged in');
        return false;
      }

      final imageUrls = await _uploadImages(images, userId);

      final profileData = {
        'userId': userId,
        'firstName': firstName.isNotEmpty ? firstName : 'Anonymous',
        'lastName': lastName.isNotEmpty ? lastName : '',
        'fullName': '${firstName.isNotEmpty ? firstName : 'Anonymous'} ${lastName.isNotEmpty ? lastName : ''}'.trim(),
        'bio': bio.isNotEmpty ? bio : 'No bio provided',
        'relationshipGoal': relationshipGoal.isNotEmpty ? relationshipGoal : 'Not specified',
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (locationWithCity != null) {
        profileData['location'] = {
          'latitude': locationWithCity['latitude'],
          'longitude': locationWithCity['longitude'],
        };
        profileData['city'] = locationWithCity['city'] ?? city ?? 'Unknown City';
      } else {
        profileData['city'] = city ?? 'Unknown City';
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .set(profileData, SetOptions(merge: true));

      debugPrint('Profile saved successfully for user: $userId');
      debugPrint('Profile data: $profileData');
      return true;
    } catch (e) {
      debugPrint('Error saving profile: $e');
      return false;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      debugPrint('Profile not found for user: $userId');
      return null;
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  // Update specific profile fields
  Future<bool> updateProfileField({
    required String field,
    required dynamic value,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('No user logged in');
        return false;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Profile field $field updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error updating profile field: $e');
      return false;
    }
  }

  // Save like to Firestore
  Future<bool> saveLike(String toUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('No user logged in');
        return false;
      }

      final likeId = _generateSortedId(userId, toUserId);
      final likeData = {
        'fromUserId': userId,
        'toUserId': toUserId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('likes').doc(likeId).set(likeData);
      debugPrint('Like saved: $userId -> $toUserId');
      return true;
    } catch (e) {
      debugPrint('Error saving like: $e');
      return false;
    }
  }

  // Check for mutual like
  Future<bool> checkMutualLike(String otherUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('No user logged in');
        return false;
      }

      final userLikeDoc = await _firestore
          .collection('likes')
          .doc(_generateSortedId(userId, otherUserId))
          .get();

      if (!userLikeDoc.exists) {
        debugPrint('No like from $userId to $otherUserId');
        return false;
      }

      final mutualLikeDoc = await _firestore
          .collection('likes')
          .doc(_generateSortedId(otherUserId, userId))
          .get();

      debugPrint('Mutual like check: ${mutualLikeDoc.exists}');
      return mutualLikeDoc.exists;
    } catch (e) {
      debugPrint('Error checking mutual like: $e');
      return false;
    }
  }

  // Create a match
  Future<bool> createMatch(String otherUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('No user logged in');
        return false;
      }

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
      debugPrint('Error creating match: $e');
      return false;
    }
  }

  // Get mutual matches
  Future<List<Map<String, dynamic>>> getMutualMatches() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('No user logged in');
        return [];
      }

      final snapshot = await _firestore
          .collection('matches')
          .where('userIds', arrayContains: userId)
          .get();

      List<Map<String, dynamic>> matches = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final otherUserId = (data['userIds'] as List).firstWhere((id) => id != userId);
        final profile = await getUserProfile(otherUserId);
        if (profile != null) {
          matches.add({
            'userId': otherUserId,
            'name': profile['fullName'] ?? 'Unknown',
            'image': (profile['images'] as List?)?.isNotEmpty ?? false
                ? profile['images'][0]
                : 'https://i.pravatar.cc/300',
            'lastMessage': data['lastMessage'],
            'lastMessageTime': data['lastMessageTime'],
          });
        }
      }

      debugPrint('Fetched ${matches.length} mutual matches');
      return matches;
    } catch (e) {
      debugPrint('Error fetching mutual matches: $e');
      return [];
    }
  }

  // Generate sorted ID
  String _generateSortedId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Get all users for swiping with matching criteria
  Future<List<Map<String, dynamic>>> getAllUsersForSwiping({
    int limit = 20,
    bool includeDistanceFilter = false,
    double maxDistance = 100.0,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('No current user for swiping');
        return [];
      }

      debugPrint('Fetching users for swiping (limit: $limit)...');

      final currentUserProfile = await getUserProfile(userId);

      Query query = _firestore
          .collection('users')
          .where('userId', isNotEqualTo: userId)
          .limit(limit);

      final QuerySnapshot snapshot = await query.get();
      debugPrint('Found ${snapshot.docs.length} users in total');

      List<Map<String, dynamic>> users = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final profileUserId = doc.id;

        // Relaxed completeness check
        if (data['fullName'] == null) {
          debugPrint('Skipping profile $profileUserId: missing fullName');
          continue;
        }

        // Check if user has already liked this profile
        try {
          final likeDoc = await _firestore
              .collection('likes')
              .doc(_generateSortedId(userId, profileUserId))
              .get();
          if (likeDoc.exists) {
            debugPrint('Skipping already liked profile: $profileUserId');
            continue;
          }
        } catch (e) {
          debugPrint('No likes collection or document for $profileUserId, treating as not liked: $e');
        }

        double compatibilityScore = _calculateCompatibilityScore(
          currentUserProfile,
          data,
        );

        double distance = _calculateDistance(
          data['location']?['latitude'],
          data['location']?['longitude'],
          currentUserProfile?['location']?['latitude'],
          currentUserProfile?['location']?['longitude'],
        );

        if (includeDistanceFilter && distance > maxDistance) {
          debugPrint('Skipping profile $profileUserId due to distance: $distance km');
          continue;
        }

        final profile = {
          'id': profileUserId,
          'name': data['fullName'] ?? 'Unknown',
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'bio': data['bio'] ?? 'No bio provided',
          'city': data['city'] ?? 'Unknown',
          'relationshipGoal': data['relationshipGoal'] ?? 'Not specified',
          'images': (data['images'] as List?)?.isNotEmpty == true
              ? (data['images'] as List).take(3).toList()
              : ['https://i.pravatar.cc/300'],
          'location': data['location'],
          'fullProfile': {
            ...data,
            'id': profileUserId,
          },
          'distance': distance,
          'compatibilityScore': compatibilityScore,
        };

        users.add(profile);
        debugPrint('Added profile: ${profile['name']} from ${profile['city']} (ID: $profileUserId)');
      }

      users.sort((a, b) => 
        (b['compatibilityScore'] as double).compareTo(a['compatibilityScore'] as double)
      );

      debugPrint('Returning ${users.length} profiles for swiping');
      return users;
    } on FirebaseException catch (e) {
      debugPrint('Firebase error getting users: ${e.code} - ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error getting users for swiping: $e');
      return [];
    }
  }

  // Calculate compatibility score
  double _calculateCompatibilityScore(
    Map<String, dynamic>? currentUser,
    Map<String, dynamic> otherUser,
  ) {
    double score = 0.0;

    if (currentUser == null) return score;

    final currentGoal = currentUser['relationshipGoal']?.toString().toLowerCase();
    final otherGoal = otherUser['relationshipGoal']?.toString().toLowerCase();
    if (currentGoal != null && otherGoal != null && currentGoal == otherGoal) {
      score += 0.5;
    }

    final distance = _calculateDistance(
      otherUser['location']?['latitude'],
      otherUser['location']?['longitude'],
      currentUser['location']?['latitude'],
      currentUser['location']?['longitude'],
    );
    if (distance < 50.0) {
      score += 0.3 * (1 - (distance / 50.0));
    }

    return score;
  }

  // Calculate distance between users
  double _calculateDistance(
    dynamic otherLat,
    dynamic otherLng,
    dynamic currentLat,
    dynamic currentLng,
  ) {
    try {
      if (otherLat == null || otherLng == null || currentLat == null || currentLng == null) {
        return 999.0;
      }

      const double earthRadius = 6371;
      final double dLat = _degreesToRadians(otherLat - currentLat);
      final double dLng = _degreesToRadians(otherLng - currentLng);
      
      final double a = sin(dLat / 2) * sin(dLat / 2) +
                      cos(_degreesToRadians(currentLat)) * cos(_degreesToRadians(otherLat)) * 
                      sin(dLng / 2) * sin(dLng / 2);
      final double c = 2 * asin(sqrt(a));
      
      return earthRadius * c;
    } catch (e) {
      debugPrint('Error calculating distance: $e');
      return 999.0;
    }
  }

  // Helper method to convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }
}