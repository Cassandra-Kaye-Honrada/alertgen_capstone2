
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';

abstract class ResultScreenTemplate extends StatefulWidget {
  final File? image;
  final Map<String, dynamic> resultData;

  const ResultScreenTemplate({
    Key? key,
    required this.image,
    required this.resultData,
  }) : super(key: key);
}

abstract class ResultScreenTemplateState<T extends ResultScreenTemplate>
    extends State<T>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  // Abstract methods to be implemented by subclasses
  String getTitle();
  String getMainTitle();
  Widget buildStatusBadge();
  Widget buildConfidenceBadge();
  Widget? buildAdditionalBadge() => null;
  Widget buildAllergenTab();
  Widget buildDescriptionTab();
  void onFirstAidTap();

  Widget buildResultHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                widget.image != null
                    ? Image.file(
                      widget.image!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                    : Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.photo, size: 40, color: Colors.grey),
                    ),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getMainTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                buildStatusBadge(),
               
                if (buildAdditionalBadge() != null) ...[
                  const SizedBox(height: 8),
                  buildAdditionalBadge()!,
                ],
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onFirstAidTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/first_aid.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Learn about first aid',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(getTitle()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Column(
        children: [
          buildResultHeader(),
          const SizedBox(height: 16),
          TabBar(
            controller: tabController,
            tabs: const [Tab(text: 'Allergen'), Tab(text: 'Description')],
            labelColor: AppColors.textBlack,
            unselectedLabelColor: AppColors.textGray,
            indicatorColor: AppColors.primary,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [buildAllergenTab(), buildDescriptionTab()],
            ),
          ),
        ],
      ),
    );
  }
}
