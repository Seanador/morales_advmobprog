import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;
  final Timestamp? readAt;

  MessageModel({
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.readAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      senderId: (map['senderId'] ?? '').toString(),
      senderEmail: (map['senderEmail'] ?? '').toString(),
      receiverId: (map['receiverId'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      timestamp: map['timestamp'] is Timestamp
          ? map['timestamp'] as Timestamp
          : Timestamp.now(),
      readAt: map['readAt'] is Timestamp ? map['readAt'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'readAt': readAt,
    };
  }
}
