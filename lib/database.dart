import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'google_calender_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fungsi untuk hash user ID
  String _hashUid(String uid) {
    return sha256.convert(utf8.encode(uid)).toString();
  }

  // Menambah to-do baru untuk user saat ini dan ke Google Calendar
  Future<void> addTodo(String task, {DateTime? eventDate}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final hashedUid = _hashUid(user.uid);
    final docRef = _db.collection('users').doc(hashedUid).collection('to-do').doc();
    await docRef.set({
      'id': docRef.id,
      'task': task,
    });

    // Tambahkan ke Google Calendar
    final googleUser = await GoogleSignIn().signInSilently();
    if (googleUser != null) {
      final calendarService = GoogleCalendarService();
      await calendarService.insertEvent(
        task,
        eventDate ?? DateTime.now(),
        googleUser,
      );
    }
  }

  // Mengambil semua to-do milik user saat ini
  Stream<List<Map<String, dynamic>>> getTodos() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    final hashedUid = _hashUid(user.uid);
    return _db
        .collection('users')
        .doc(hashedUid)
        .collection('to-do')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
