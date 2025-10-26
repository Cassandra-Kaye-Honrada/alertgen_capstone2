import 'package:allergen/screens/feature/chatbot/chatbot.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FloatingChatbotButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ChatbotModal(),
        );
      },
      child: Icon(Icons.chat_bubble_outline),
      backgroundColor: Colors.blue,
    );
  }
}