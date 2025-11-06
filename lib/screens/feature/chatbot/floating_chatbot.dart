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
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Ink(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B9EB3), Color(0xFF1E7A8C)],
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(15.0),
          child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
