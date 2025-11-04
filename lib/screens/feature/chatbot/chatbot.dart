import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatbotModal extends StatefulWidget {
  @override
  _ChatbotModalState createState() => _ChatbotModalState();
}

class _ChatbotModalState extends State<ChatbotModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  List<ChatMessage> messages = [];
  bool isLoading = true;
  bool isTyping = false;
  Map<String, dynamic>? userData;
  List<String> allergens = [];
  List<String> suggestionChips = [];
  bool showChips = true;
  late GenerativeModel model;
  ChatSession? chatSession;
  String? userImageUrl;
  late AnimationController typingAnimationController;
  late Animation<double> typingAnimation;
  bool showScrollToBottom = false;
  double scrollPosition = 0;

  @override
  void initState() {
    super.initState();

    typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    typingAnimation = CurvedAnimation(
      parent: typingAnimationController,
      curve: Curves.easeInOut,
    );

    scrollController.addListener(scrollListener);

    initializeAI();
    loadUserProfile();
    loadChatHistory();
  }

  void scrollListener() {
    final double currentPosition = scrollController.position.pixels;
    final double maxPosition = scrollController.position.maxScrollExtent;

    bool shouldShow = (maxPosition - currentPosition) > 200;

    if (shouldShow != showScrollToBottom) {
      setState(() {
        showScrollToBottom = shouldShow;
        scrollPosition = currentPosition;
      });
    }
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      Future.delayed(Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() {
            showScrollToBottom = false;
          });
        }
      });
    }
  }

  void initializeAI() {
    final apiKey = dotenv.env['API_KEY'] ?? '';
    model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'You are a specialized allergen information assistant. Your ONLY purpose is to provide information about allergens, allergic reactions, cross-reactivity, allergen avoidance, and allergy-related symptoms. '
        'You must STRICTLY follow these rules:\n'
        '1. DIAGNOSIS REQUESTS ARE ALLERGEN-RELATED: If the user asks "can you diagnose me", "diagnose my symptoms", "what do I have", or similar diagnosis questions, these ARE allergen-related questions. You MUST respond with: "I cannot provide medical diagnoses, but I strongly recommend consulting a healthcare professional or allergist for proper diagnosis and treatment. They can perform appropriate tests to identify the cause of your symptoms." If symptoms are described, you may briefly mention they could be allergen-related before the recommendation.\n'
        '2. ONLY answer questions directly related to allergens, allergies, allergic reactions, food allergens, environmental allergens, cross-contamination, and allergy management.\n'
        '3. If a question is NOT about allergens or allergies (like asking about diabetes, fitness, etc.), politely decline and redirect: "I apologize, but I can only provide information about allergens and allergic reactions. Please ask me about specific allergens, potential allergic symptoms, or allergy management strategies."\n'
        '4. Do NOT answer questions about general health conditions, diseases, medications, treatments, or medical advice unrelated to allergens.\n'
        '5. Use a formal, calm, and respectful tone. Address the user directly using "you".\n'
        '6. Keep responses concise—preferably 2 to 4 sentences—written in clear, grammatically correct English.\n'
        '7. Never use markdown, bullet points, or emojis.\n'
        '8. Examples of ACCEPTABLE topics: food allergens, pollen allergies, pet dander, allergic reactions, anaphylaxis, allergen avoidance, cross-reactivity, allergy testing, common allergen sources, and requests for diagnosis (which you decline appropriately).\n'
        '9. Examples of UNACCEPTABLE topics: diabetes, heart disease, pregnancy care, general medications, non-allergy infections, mental health, fitness advice, nutrition (unless directly related to allergen avoidance).',
      ),
    );
  }

  Future<void> loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        setState(() {
          userData = userDoc.data();
          userImageUrl = userDoc.data()?['imageUrl'];
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  String buildUserContext() {
    List<String> contextParts = [];

    if (allergens.isNotEmpty) {
      contextParts.add('User allergens: ${allergens.join(", ")}');
    }

    if (userData != null) {
      if (userData!['asthmaRespiratory'] == true) {
        contextParts.add(
          'User has asthma/respiratory condition (relevant for allergen-related triggers)',
        );
      }
    }

    if (contextParts.isEmpty) {
      return '';
    }

    return '\n\nUser context: ${contextParts.join("; ")}';
  }

  String cleanAIResponse(String response) {
    String cleaned = response
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('__', '')
        .replaceAll('_', '')
        .replaceAll('##', '')
        .replaceAll('#', '')
        .replaceAll('`', '')
        .replaceAll('---', '')
        .replaceAll('~~~', '');

    cleaned = cleaned
        .replaceAll(RegExp(r'^\s*[\*\-\+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    cleaned = cleaned.trim();

    return cleaned;
  }

  Future<void> loadChatHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final allergenSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .where('type', isEqualTo: 'allergen')
              .get();

      allergens =
          allergenSnapshot.docs
              .map((doc) => doc.data()['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();

      final chatDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('chatbot')
              .doc('history')
              .get();

      if (chatDoc.exists && chatDoc.data()?['messages'] != null) {
        List<dynamic> savedMessages = chatDoc.data()!['messages'];
        if (savedMessages.isNotEmpty) {
          setState(() {
            messages =
                savedMessages.map((msg) {
                  return ChatMessage(
                    text: msg['text'],
                    isUser: msg['isUser'],
                    timestamp: (msg['timestamp'] as Timestamp).toDate(),
                  );
                }).toList();
            isLoading = false;
            showChips = false;
          });

          restoreChatSession();
        } else {
          await generateInitialMessages();
        }
      } else {
        await generateInitialMessages();
      }

      scrollToBottom();
    } catch (e) {
      print('Error loading chat history: $e');
      await generateInitialMessages();
    }
  }

  void restoreChatSession() {
    List<Content> history = [];

    for (var msg in messages) {
      history.add(Content(msg.isUser ? 'user' : 'model', [TextPart(msg.text)]));
    }

    chatSession = model.startChat(history: history);
  }

  Future<void> generateInitialMessages() async {
    setState(() {
      messages = [];
      showChips = true;
      isLoading = true;
    });

    chatSession = model.startChat();

    await generateAISuggestions();

    setState(() {
      isLoading = false;
    });

    await saveChatHistory();
    scrollToBottom();
  }

  Future<void> generateAISuggestions() async {
    try {
      String userProfile = buildUserProfileForSuggestions();

      String prompt =
          '''Based on the following user allergen profile, generate exactly 4 personalized questions STRICTLY about allergens and allergic reactions. 

$userProfile

Return ONLY the 4 questions, one per line, without numbering, bullets, or any additional text. 
Each question should be:
- STRICTLY focused on allergens, allergic reactions, or allergen avoidance
- Practical and actionable
- Between 6–10 words long
- Written in first person (e.g., "What foods contain hidden shrimp allergens?")
- Concise and direct''';

      final response = await model.generateContent([Content.text(prompt)]);
      String? aiResponse = response.text;

      if (aiResponse != null && aiResponse.isNotEmpty) {
        List<String> suggestions =
            aiResponse
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty && s.length > 10)
                .take(4)
                .toList();

        if (suggestions.length >= 3) {
          setState(() {
            suggestionChips = suggestions;
          });
          return;
        }
      }

      setState(() {
        suggestionChips = getFallbackSuggestions();
      });
    } catch (e) {
      print('Error generating AI suggestions: $e');
      setState(() {
        suggestionChips = getFallbackSuggestions();
      });
    }
  }

  String buildUserProfileForSuggestions() {
    List<String> profileParts = [];

    if (allergens.isNotEmpty) {
      profileParts.add('Known allergens: ${allergens.join(", ")}');
    }

    if (userData != null) {
      if (userData!['asthmaRespiratory'] == true) {
        profileParts.add('Has asthma (relevant for allergen triggers)');
      }
    }

    if (profileParts.isEmpty) {
      return 'General allergen inquiries (no specific allergens reported)';
    }

    return profileParts.join('\n');
  }

  List<String> getFallbackSuggestions() {
    List<String> suggestions = [];

    if (allergens.isNotEmpty) {
      suggestions.add('What foods should I avoid with ${allergens[0]}?');
      suggestions.add('What causes cross-reactions with ${allergens[0]}?');
    }

    if (userData?['asthmaRespiratory'] == true) {
      suggestions.add('What allergens trigger asthma symptoms?');
    }

    // Default allergen-focused suggestions
    while (suggestions.length < 4) {
      List<String> defaults = [
        'What are common food allergens?',
        'How can I identify hidden allergens?',
        'What are symptoms of allergic reactions?',
        'How do I prevent cross-contamination?',
        'What is anaphylaxis?',
        'Can allergies develop in adults?',
      ];

      for (String def in defaults) {
        if (!suggestions.contains(def) && suggestions.length < 4) {
          suggestions.add(def);
        }
      }
    }

    return suggestions.take(4).toList();
  }

  Future<void> saveChatHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      List<Map<String, dynamic>> messagesToSave =
          messages.map((msg) {
            return {
              'text': msg.text,
              'isUser': msg.isUser,
              'timestamp': Timestamp.fromDate(msg.timestamp),
            };
          }).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chatbot')
          .doc('history')
          .set({
            'messages': messagesToSave,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }

  Future<void> sendMessage([String? predefinedMessage]) async {
    String userMessage = predefinedMessage ?? messageController.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );
      showChips = false;
      isTyping = true;
    });

    messageController.clear();

    scrollToBottom();

    if (!typingAnimationController.isAnimating) {
      typingAnimationController.repeat(reverse: true);
    }

    try {
      if (chatSession == null) {
        chatSession = model.startChat();
      }

      String messageWithContext = userMessage + buildUserContext();

      final response = await chatSession!.sendMessage(
        Content.text(messageWithContext),
      );

      String aiResponse =
          response.text ??
          'I apologize, but I couldn\'t generate a response. Please try again.';

      aiResponse = cleanAIResponse(aiResponse);

      setState(() {
        messages.add(
          ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        isTyping = false;
      });

      typingAnimationController.stop();

      scrollToBottom();
      await saveChatHistory();
    } catch (e) {
      print('Error sending message to AI: $e');
      setState(() {
        messages.add(
          ChatMessage(
            text:
                'I apologize, but I encountered an error. Please try again or contact support if the issue persists.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        isTyping = false;
      });

      typingAnimationController.stop();

      scrollToBottom();
      await saveChatHistory();
    }
  }

  Widget buildUserAvatar() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return buildDefaultAvatar();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return buildDefaultAvatar();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final imageUrl = data['imageUrl'] as String?;
        final hasValidImage = imageUrl != null && imageUrl.isNotEmpty;

        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE2E8F0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child:
                hasValidImage
                    ? Image.network(
                      imageUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return buildDefaultAvatar();
                      },
                    )
                    : buildDefaultAvatar(),
          ),
        );
      },
    );
  }

  Widget buildDefaultAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0B8FAC).withOpacity(0.1),
      ),
      child: Icon(Icons.person, color: Color(0xFF0B8FAC), size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return AnimatedPadding(
          padding: MediaQuery.of(context).viewInsets,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF0B8FAC).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.smart_toy,
                              color: Color(0xFF0B8FAC),
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Allergen Assistant',
                                  style: TextStyle(
                                    color: Color(0xFF2D3748),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  isTyping
                                      ? 'Typing...'
                                      : 'Ask about allergens',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Messages
                    Expanded(
                      child:
                          isLoading
                              ? Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                controller: this.scrollController,
                                padding: EdgeInsets.all(16),
                                itemCount: messages.length + (isTyping ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == messages.length && isTyping) {
                                    return buildTypingIndicator();
                                  }
                                  return buildMessageBubble(messages[index]);
                                },
                              ),
                    ),

                    if (showChips && suggestionChips.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 8, left: 8),
                              child: Text(
                                'Quick allergen questions:',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  suggestionChips.map((suggestion) {
                                    return GestureDetector(
                                      onTap: () => sendMessage(suggestion),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF0F9FF),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Color(
                                              0xFF0B8FAC,
                                            ).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          suggestion,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF0B8FAC),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: messageController,
                                enabled: !isTyping,
                                decoration: InputDecoration(
                                  hintText:
                                      isTyping
                                          ? 'AI is typing...'
                                          : 'Ask about allergens...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide(
                                      color: Color(0xFF0B8FAC),
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Color(0xFFF8F9FA),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted:
                                    (_) => isTyping ? null : sendMessage(),
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color:
                                    isTyping
                                        ? Color(0xFF9CA3AF)
                                        : Color(0xFF0B8FAC),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed:
                                    isTyping ? null : () => sendMessage(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (showScrollToBottom && messages.length > 2)
                  Positioned(
                    bottom: 80,
                    left: MediaQuery.of(context).size.width / 2 - 25,
                    child: GestureDetector(
                      onTap: scrollToBottom,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(0xFF0B8FAC),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildMessageBubble(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser)
            Container(
              margin: EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF0B8FAC).withOpacity(0.1),
                child: Icon(
                  Icons.smart_toy,
                  color: Color(0xFF0B8FAC),
                  size: 16,
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? Color(0xFF0B8FAC) : Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Color(0xFF2D3748),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser)
            Container(
              margin: EdgeInsets.only(left: 8),
              child: buildUserAvatar(),
            ),
        ],
      ),
    );
  }

  Widget buildTypingIndicator() {
    if (!typingAnimationController.isAnimating) {
      typingAnimationController.repeat(reverse: true);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF0B8FAC).withOpacity(0.1),
              child: Icon(Icons.smart_toy, color: Color(0xFF0B8FAC), size: 16),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: typingAnimation,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(0xFF0B8FAC),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                FadeTransition(
                  opacity: typingAnimation,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(0xFF0B8FAC),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                FadeTransition(
                  opacity: typingAnimation,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(0xFF0B8FAC),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.removeListener(scrollListener);
    scrollController.dispose();
    typingAnimationController.stop();
    typingAnimationController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
