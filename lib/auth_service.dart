import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

const List<String> scopes = <String>[
  'email',
  'https://www.googleapis.com/auth/calendar',
];

// Inisialisasi GoogleSignIn dengan clientId dan scope Calendar
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: '703592972172-rrd3vebkqbtfc74quemula3e4cujsju1.apps.googleusercontent.com',
  scopes: scopes,
);

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // sign up
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print(e);
      return null;
    }
  }

  // sign in
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print(e);
      return null;
    }
  }

  // Google Sign In
  Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential result = await _auth.signInWithCredential(credential);
      if (result.user != null && context.mounted) {
        // Tambahkan user ke database jika login Google
        final user = result.user;
        final hashedUid = sha256.convert(utf8.encode(user!.uid)).toString();
        final db = FirebaseFirestore.instance;
        final userDoc = db.collection('users').doc(hashedUid);
        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          await userDoc.set({
            'id': hashedUid,
            'email': user.email,
            'displayName': user.displayName,
            'photoURL': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'provider': 'google',
          });
        }
        Navigator.pushReplacementNamed(context, '/home');
      }
      return result.user;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return null;
    }
  }

  // get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
