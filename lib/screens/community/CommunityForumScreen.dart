import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ForumUserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String profileImage;
  final String bio;
  final DateTime createdAt;
  final bool isAnonymous;

  ForumUserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.profileImage,
    this.bio = '',
    required this.createdAt,
    this.isAnonymous = false,
  });

  factory ForumUserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ForumUserProfile(
      uid: doc.id,
      displayName: data['displayName'] ?? 'Anonymous',
      email: data['email'] ?? '',
      profileImage: data['profileImage'] ?? '',
      bio: data['bio'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isAnonymous: data['isAnonymous'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'profileImage': profileImage,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'isAnonymous': isAnonymous,
    };
  }
}

class ForumPost {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String authorImage;
  final DateTime createdAt;
  final int replies;
  final int likes;
  final String category;
  final bool isPinned;
  final List<String> likedBy;
  final List<String> images;

  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorImage,
    required this.createdAt,
    required this.replies,
    required this.likes,
    required this.category,
    this.isPinned = false,
    this.likedBy = const [],
    this.images = const [],
  });

  factory ForumPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ForumPost(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      authorImage: data['authorImage'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      replies: data['replies'] ?? 0,
      likes: data['likes'] ?? 0,
      category: data['category'] ?? 'Discussions',
      isPinned: data['isPinned'] ?? false,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      images: List<String>.from(data['images'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorImage': authorImage,
      'createdAt': Timestamp.fromDate(createdAt),
      'replies': replies,
      'likes': likes,
      'category': category,
      'isPinned': isPinned,
      'likedBy': likedBy,
      'images': images,
    };
  }
}

class ForumNotification {
  final String id;
  final String userId;
  final String type; // 'like', 'reply', 'mention'
  final String postId;
  final String postTitle;
  final String actorName;
  final String actorImage;
  final DateTime createdAt;
  final bool isRead;

  ForumNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.postId,
    required this.postTitle,
    required this.actorName,
    required this.actorImage,
    required this.createdAt,
    this.isRead = false,
  });

  factory ForumNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ForumNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      postId: data['postId'] ?? '',
      postTitle: data['postTitle'] ?? '',
      actorName: data['actorName'] ?? '',
      actorImage: data['actorImage'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }
}

class CommunityForumScreen extends StatefulWidget {
  const CommunityForumScreen({Key? key}) : super(key: key);

  @override
  State<CommunityForumScreen> createState() => _CommunityForumScreenState();
}

class _CommunityForumScreenState extends State<CommunityForumScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  final List<String> categories = [
    'All',
    'Discussions',
    'Tips',
    'Questions',
    'Stories',
  ];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: categories.length, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return DateFormat('MMM d').format(dateTime);
  }

  Future<void> _toggleLike(ForumPost post) async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      final postRef = _firestore.collection('forum_posts').doc(post.id);

      if (post.likedBy.contains(userId)) {
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
      } else {
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });

        // Create notification for post author
        if (post.authorId != userId) {
          final currentUser = await _getUserProfile(userId);
          await _firestore.collection('forum_notifications').add({
            'userId': post.authorId,
            'type': 'like',
            'postId': post.id,
            'postTitle': post.title,
            'actorName': currentUser?.displayName ?? 'Someone',
            'actorImage': currentUser?.profileImage ?? '',
            'createdAt': Timestamp.now(),
            'isRead': false,
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildAvatar(String? profileImage, String name) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.5), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child:
          profileImage != null && profileImage.isNotEmpty
              ? ClipOval(
                child: Image.network(
                  profileImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildInitialAvatar(name),
                ),
              )
              : _buildInitialAvatar(name),
    );
  }

  Future<ForumUserProfile?> _getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['displayName'] != null || data['profileImage'] != null) {
          return ForumUserProfile.fromFirestore(doc);
        }
      }

      final user = _auth.currentUser;
      if (user != null) {
        return ForumUserProfile(
          uid: uid,
          displayName: user.displayName ?? 'Anonymous',
          email: user.email ?? '',
          profileImage: user.photoURL ?? '',
          bio: '',
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
    return null;
  }

  Widget _buildInitialAvatar(String name) {
    final initials =
        name
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
            .toUpperCase();
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Search Posts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search by title or content...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(
                          () =>
                              _searchQuery =
                                  _searchController.text.toLowerCase(),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget buildForumPostCard(ForumPost post) {
    final currentUserId = _auth.currentUser?.uid ?? '';
    final isLiked = post.likedBy.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(postId: post.id),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.transparent,
                      child: _buildAvatar(post.authorImage, post.authorName),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  post.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (post.isPinned)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.push_pin,
                                        size: 9,
                                        color: Colors.amber,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Pinned',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatTime(post.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  post.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: post.images.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(post.images[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _toggleLike(post),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 15,
                            color: isLiked ? Colors.red : Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.likes.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 15,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.replies.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Community Forum',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: _showSearchDialog,
          ),
          StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('forum_notifications')
                    .where('userId', isEqualTo: _auth.currentUser?.uid ?? '')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 22),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Searching for: "$_searchQuery"',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: tabController,
              tabs: categories.map((category) => Tab(text: category)).toList(),
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children:
                  categories.map((category) {
                    Query query = _firestore
                        .collection('forum_posts')
                        .orderBy('isPinned', descending: true)
                        .orderBy('createdAt', descending: true);

                    if (category != 'All') {
                      query = query.where('category', isEqualTo: category);
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: query.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.forum_outlined,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No posts yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to start a discussion!',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        var posts =
                            snapshot.data!.docs
                                .map((doc) => ForumPost.fromFirestore(doc))
                                .toList();

                        // Apply search filter
                        if (_searchQuery.isNotEmpty) {
                          posts =
                              posts.where((post) {
                                return post.title.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    post.content.toLowerCase().contains(
                                      _searchQuery,
                                    );
                              }).toList();
                        }

                        if (posts.isEmpty && _searchQuery.isNotEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No results found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            return buildForumPostCard(posts[index]);
                          },
                        );
                      },
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 24),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
      ),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  String selectedCategory = 'Discussions';
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final ImagePicker picker = ImagePicker();
  bool isLoading = false;
  bool postAnonymously = false;
  List<File> selectedImages = [];
  List<String> uploadedImageUrls = [];

  final List<String> categories = [
    'Discussions',
    'Tips',
    'Questions',
    'Stories',
  ];

  Future<void> pickImages() async {
    try {
      final List<XFile> images = await picker.pickMultiImage(limit: 5);
      if (images.isNotEmpty) {
        setState(() {
          selectedImages = images.map((img) => File(img.path)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
    }
  }

  Future<String> uploadImage(File imageFile) async {
    try {
      final userId = auth.currentUser?.uid ?? '';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = storage.ref().child('forum_posts/$userId/$timestamp.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<ForumUserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return ForumUserProfile.fromFirestore(doc);
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
    return null;
  }

  Future<void> createPost() async {
    if (titleController.text.isEmpty || contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Upload images
      uploadedImageUrls = [];
      for (var imageFile in selectedImages) {
        final url = await uploadImage(imageFile);
        uploadedImageUrls.add(url);
      }

      final userProfile = await getUserProfile(user.uid);

      String displayName = 'Anonymous';
      String displayImage = '';

      if (!postAnonymously) {
        final doc = await firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final firstName = data['firstName'] ?? '';
          final lastName = data['lastName'] ?? '';
          displayName = '$firstName $lastName'.trim();
          if (displayName.isEmpty) {
            displayName =
                userProfile?.displayName ?? user.displayName ?? 'User';
          }
          displayImage = data['imageUrl'] ?? userProfile?.profileImage ?? '';
        } else {
          displayName = userProfile?.displayName ?? user.displayName ?? 'User';
          displayImage = userProfile?.profileImage ?? '';
        }
      }

      await firestore.collection('forum_posts').add({
        'title': titleController.text,
        'content': contentController.text,
        'authorId': user.uid,
        'authorName': displayName,
        'authorImage': displayImage,
        'createdAt': Timestamp.now(),
        'replies': 0,
        'likes': 0,
        'category': selectedCategory,
        'isPinned': false,
        'likedBy': [],
        'isAnonymous': postAnonymously,
        'images': uploadedImageUrls,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                underline: const SizedBox(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                items:
                    categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() => selectedCategory = value ?? 'Discussions');
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Title',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 24),
            Text(
              'Content',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              decoration: InputDecoration(
                hintText: 'Share your thoughts, experiences, or tips...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 20),
            // Image picker section
            GestureDetector(
              onTap: pickImages,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add Photos (Max 5)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selectedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(selectedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Post anonymously',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: postAnonymously,
                    onChanged: (value) {
                      setState(() => postAnonymously = value);
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child:
                    isLoading
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text(
                          'Create Post',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return DateFormat('MMM d').format(dateTime);
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('forum_notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      final notifications =
          await _firestore
              .collection('forum_notifications')
              .where('userId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      for (var doc in notifications.docs) {
        await doc.reference.update({'isRead': true});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  String getNotificationText(String type, String actorName) {
    switch (type) {
      case 'like':
        return '$actorName liked your post';
      case 'reply':
        return '$actorName replied to your post';
      case 'mention':
        return '$actorName mentioned you';
      default:
        return 'New notification';
    }
  }

  IconData getNotificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'reply':
        return Icons.chat_bubble;
      case 'mention':
        return Icons.alternate_email;
      default:
        return Icons.notifications;
    }
  }

  Color getNotificationColor(String type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'reply':
        return Colors.blue;
      case 'mention':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: markAllAsRead,
            child: Text(
              'Mark all read',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('forum_notifications')
                .where('userId', isEqualTo: _auth.currentUser?.uid ?? '')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ll notify you when something happens',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final notifications =
              snapshot.data!.docs
                  .map((doc) => ForumNotification.fromFirestore(doc))
                  .toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      markAsRead(notification.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  PostDetailScreen(postId: notification.postId),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            notification.isRead
                                ? Colors.white
                                : AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: getNotificationColor(
                                notification.type,
                              ).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              getNotificationIcon(notification.type),
                              size: 20,
                              color: getNotificationColor(notification.type),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getNotificationText(
                                    notification.type,
                                    notification.actorName,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        notification.isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.postTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatTime(notification.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final replyController = TextEditingController();
  bool isReplying = false;

  Future<ForumUserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return ForumUserProfile.fromFirestore(doc);
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
    return null;
  }

  Future<void> addReply(String postId) async {
    if (replyController.text.isEmpty) return;

    setState(() => isReplying = true);

    try {
      final user = auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userProfile = await getUserProfile(user.uid);

      // Get post details for notification
      final postDoc =
          await firestore.collection('forum_posts').doc(postId).get();
      final postData = postDoc.data() as Map<String, dynamic>;
      final postAuthorId = postData['authorId'];
      final postTitle = postData['title'];

      await firestore
          .collection('forum_posts')
          .doc(postId)
          .collection('replies')
          .add({
            'content': replyController.text,
            'authorId': user.uid,
            'authorName':
                userProfile?.displayName ?? user.displayName ?? 'Anonymous',
            'authorImage': userProfile?.profileImage ?? '',
            'createdAt': Timestamp.now(),
            'likes': 0,
          });

      await firestore.collection('forum_posts').doc(postId).update({
        'replies': FieldValue.increment(1),
      });

      // Create notification for post author
      if (postAuthorId != user.uid) {
        await firestore.collection('forum_notifications').add({
          'userId': postAuthorId,
          'type': 'reply',
          'postId': postId,
          'postTitle': postTitle,
          'actorName':
              userProfile?.displayName ?? user.displayName ?? 'Someone',
          'actorImage': userProfile?.profileImage ?? '',
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
      }

      replyController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => isReplying = false);
    }
  }

  Widget buildAvatarContainer(String? profileImage, String name) {
    if (profileImage != null && profileImage.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          profileImage,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => buildInitialAvatar(name),
        ),
      );
    }
    return buildInitialAvatar(name);
  }

  Widget buildInitialAvatar(String name) {
    final initials =
        name
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
            .toUpperCase();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.5), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Discussion',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            firestore.collection('forum_posts').doc(widget.postId).snapshots(),
        builder: (context, postSnapshot) {
          if (postSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!postSnapshot.hasData) {
            return const Center(child: Text('Post not found'));
          }

          final post = ForumPost.fromFirestore(postSnapshot.data!);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        decoration: const BoxDecoration(color: Colors.white),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.transparent,
                                  child: buildAvatarContainer(
                                    post.authorImage,
                                    post.authorName,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.authorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMM d, yyyy • HH:mm',
                                        ).format(post.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    post.category,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              post.content,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.6,
                              ),
                            ),
                            if (post.images.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemCount: post.images.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Show full image
                                      showDialog(
                                        context: context,
                                        builder:
                                            (context) => Dialog(
                                              child: Image.network(
                                                post.images[index],
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            post.images[index],
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey[200], thickness: 0.5),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite_border,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${post.likes}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${post.replies}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: const BoxDecoration(color: Colors.white),
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replies (${post.replies})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 14),
                            StreamBuilder<QuerySnapshot>(
                              stream:
                                  firestore
                                      .collection('forum_posts')
                                      .doc(widget.postId)
                                      .collection('replies')
                                      .orderBy('createdAt', descending: false)
                                      .snapshots(),
                              builder: (context, repliesSnapshot) {
                                if (repliesSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }

                                if (!repliesSnapshot.hasData ||
                                    repliesSnapshot.data!.docs.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 40,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No replies yet',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children:
                                      repliesSnapshot.data!.docs.map((
                                        replyDoc,
                                      ) {
                                        final reply =
                                            replyDoc.data()
                                                as Map<String, dynamic>;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.grey[200]!,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      child: buildAvatarContainer(
                                                        reply['authorImage'] ??
                                                            '',
                                                        reply['authorName'] ??
                                                            'Anonymous',
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            reply['authorName'] ??
                                                                'Anonymous',
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                          Text(
                                                            DateFormat(
                                                              'MMM d, HH:mm',
                                                            ).format(
                                                              (reply['createdAt']
                                                                      as Timestamp)
                                                                  .toDate(),
                                                            ),
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color:
                                                                  Colors
                                                                      .grey[500],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  reply['content'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!, width: 0.5),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isReplying ? null : () => addReply(widget.postId),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              isReplying ? Colors.grey[300] : AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child:
                            isReplying
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 18,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    replyController.dispose();
    super.dispose();
  }
}
