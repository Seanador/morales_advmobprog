import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  User get _currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('Firebase sign-in is required to use chat.');
    }
    return user;
  }

  DocumentReference<Map<String, dynamic>> _room(
    String currentUserId,
    String otherUserId,
  ) {
    final ids = [currentUserId, otherUserId]..sort();
    return _firestore.collection('chat_rooms').doc(ids.join('_'));
  }

  // get all users
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('Users').snapshots().map((snapshot) {
      final users = snapshot.docs.map((doc) {
        return <String, dynamic>{...doc.data(), 'uid': doc.id};
      }).toList();
      users.sort(
        (a, b) => _displayName(
          a,
        ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
      );
      return users;
    });
  }

  static String _displayName(Map<String, dynamic> user) {
    final fullName = [
      (user['firstName'] ?? '').toString().trim(),
      (user['lastName'] ?? '').toString().trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    final username = (user['username'] ?? '').toString().trim();
    if (username.isNotEmpty) return username;
    return (user['email'] ?? '').toString().trim();
  }

  Future<void> ensureChatRoom(String otherUserId) async {
    final currentUser = _currentUser;
    if (otherUserId.isEmpty || otherUserId == currentUser.uid) {
      throw ArgumentError('Choose another valid Firebase user.');
    }
    final participants = [currentUser.uid, otherUserId]..sort();
    await _room(currentUser.uid, otherUserId).set({
      'participants': participants,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // send message
  Future<void> sendMessage(String receiverId, String message) async {
    final currentUser = _currentUser;
    final text = message.trim();
    if (text.isEmpty) return;

    await ensureChatRoom(receiverId);

    final newMessage = MessageModel(
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? '',
      receiverId: receiverId,
      message: text,
      timestamp: Timestamp.now(),
    );

    await _room(
      currentUser.uid,
      receiverId,
    ).collection('messages').add(newMessage.toMap());

    await _room(currentUser.uid, receiverId).update({
      'lastMessage': text,
      'lastSenderId': currentUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(
    String currentUserId,
    String otherUserId,
  ) {
    return _room(currentUserId, otherUserId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  /// Marks received messages as seen when the receiver opens the conversation.
  Future<void> markMessagesAsSeen(String otherUserId) async {
    final currentUser = _currentUser;
    final snapshot = await _room(currentUser.uid, otherUserId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser.uid)
        .get();
    final unread = snapshot.docs.where((doc) => doc.data()['readAt'] == null);
    if (unread.isEmpty) return;

    final batch = _firestore.batch();
    for (final message in unread) {
      batch.update(message.reference, {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  Future<String?> getUidByEmail(String email) async {
    final q = await _firestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;

    // Ensure your Users doc actually stores the Firebase Auth UID in a field `uid`
    return (q.docs.first.data()['uid'] ?? '').toString();
  }
}
