import 'dart:io';
import 'dart:math'; // Added for sin, cos, sqrt, asin
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

      // Get city name from coordinates using reverse geocoding
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
    
    for (int i = 0; i < images.length; i++) {
      if (images[i] != null) {
        final url = await _uploadImage(images[i]!, userId);
        if (url != null) {
          imageUrls.add(url);
        }
      }
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
        'firstName': firstName,
        'lastName': lastName,
        'fullName': '$firstName $lastName',
        'bio': bio,
        'relationshipGoal': relationshipGoal,
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
      } else if (city != null && city.isNotEmpty) {
        profileData['city'] = city;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .set(profileData, SetOptions(merge: true));

      debugPrint('Profile saved successfully');
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
      if (userId == null) return false;

      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

      final likeData = {
        'fromUserId': userId,
        'toUserId': toUserId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('likes')
          .doc('${userId}_$toUserId')
          .set(likeData);

      debugPrint('Like saved for user $toUserId');
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
      if (userId == null) return false;

      final doc = await _firestore
          .collection('likes')
          .doc('${otherUserId}_$userId')
          .get();
      
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking mutual like: $e');
      return false;
    }
  }

  // Create a match
  Future<bool> createMatch(String otherUserId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final matchData = {
        'userIds': [userId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
      };

      await _firestore
          .collection('matches')
          .doc('${userId}_$otherUserId')
          .set(matchData);

      await _firestore
          .collection('matches')
          .doc('${otherUserId}_$userId')
          .set(matchData);

      debugPrint('Match created with $otherUserId');
      return true;
    } catch (e) {
      debugPrint('Error creating match: $e');
      return false;
    }
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
        final userId = doc.id;

        if (data['firstName'] == null || 
            data['bio'] == null || 
            (data['images'] == null || (data['images'] as List).isEmpty)) {
          debugPrint('Skipping incomplete profile: $userId');
          continue;
        }

        double compatibilityScore = _calculateCompatibilityScore(
          currentUserProfile,
          data,
        );

        final profile = {
          'id': userId,
          'name': '${data['firstName']} ${data['lastName'] ?? ''}'.trim(),
          'firstName': data['firstName'],
          'lastName': data['lastName'] ?? '',
          'bio': data['bio'],
          'city': data['city'] ?? 'Unknown',
          'relationshipGoal': data['relationshipGoal'] ?? '',
          'images': data['images'] ?? [],
          'location': data['location'],
          'fullProfile': {
            ...data,
            'id': userId,
          },
          'distance': _calculateDistance(
            data['location']?['latitude'],
            data['location']?['longitude'],
            currentUserProfile?['location']?['latitude'],
            currentUserProfile?['location']?['longitude'],
          ),
          'compatibilityScore': compatibilityScore,
        };

        users.add(profile);
        debugPrint('Added profile: ${profile['name']} from ${profile['city']}');
      }

      users.sort((a, b) => 
        (b['compatibilityScore'] as double).compareTo(a['compatibilityScore'] as double)
      );

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