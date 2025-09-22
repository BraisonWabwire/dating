import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Add this import

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
      final fileName = 'profile_images/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
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
    Map<String, dynamic>? locationWithCity, // Updated to include city
    String? city, // Keep city parameter for manual override if needed
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        debugPrint('No user logged in');
        return false;
      }

      // Upload images first
      final imageUrls = await _uploadImages(images, userId);

      // Prepare profile data
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

      // Add location and city data
      if (locationWithCity != null) {
        profileData['location'] = {
          'latitude': locationWithCity['latitude'],
          'longitude': locationWithCity['longitude'],
        };
        profileData['city'] = locationWithCity['city'] ?? city ?? 'Unknown City';
      } else if (city != null && city.isNotEmpty) {
        profileData['city'] = city;
      }

      // Save to Firestore
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
}