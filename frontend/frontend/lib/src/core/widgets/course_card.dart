import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool isEnrolled;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.showProgress = true,
    this.isEnrolled = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = course['title'] ?? 'Untitled Course';
    final description = course['description'] ?? 'No description available';
    final instructor = course['instructor']?['name'] ??
        course['instructor_name'] ??
        'Unknown Instructor';
    final thumbnail = course['thumbnail'] ?? course['image_url'];
    final progress = course['progress'] ?? 0.0;
    final totalLectures = course['total_lectures'] ?? 0;
    final completedLectures = course['completed_lectures'] ?? 0;
    final difficulty = course['difficulty'] ?? 'beginner';
    final category = course['category'] ?? 'General';

    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final surface = colorScheme.surface;
    final surfaceVariant = colorScheme.surfaceVariant;
    final shadowColor = Theme.of(context).shadowColor.withOpacity(0.2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Thumbnail
            Container(
              height: 80, // Reduced height from 140 to 120
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                color: AppColors.backgroundMedium,
              ),
              child: thumbnail != null
                  ? ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderThumbnail(category);
                        },
                      ),
                    )
                  : _buildPlaceholderThumbnail(category),
            ),

            Padding(
              padding:
                  const EdgeInsets.all(12), // Reduced padding from 14 to 12
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and Difficulty Badge
                  Wrap(
                    spacing: 6, // Reduced from 8 to 6
                    runSpacing: 6, // Added to handle wrapping
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3), // Reduced padding
                        decoration: BoxDecoration(
                          color: AppColors.getCategoryColor(0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                              10), // Reduced from 12 to 10
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: AppColors.getCategoryColor(0),
                            fontSize: 10, // Reduced from 12 to 10
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3), // Reduced padding
                        decoration: BoxDecoration(
                          color: AppColors.getDifficultyColor(difficulty)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                              10), // Reduced from 12 to 10
                        ),
                        child: Text(
                          difficulty.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.getDifficultyColor(difficulty),
                            fontSize: 10, // Reduced from 12 to 10
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8), // Reduced from 10 to 8

                  // Course Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6), // Reduced from 8 to 6

                  // Course Description
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8), // Reduced from 10 to 8

                  // Instructor
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          instructor,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (showProgress) ...[
                    const SizedBox(height: 10), // Reduced from 12 to 10

                    // Progress Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: onSurface,
                                  ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryLight,
                                  ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4), // Reduced from 6 to 4

                        // Progress Bar
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0
                                ? AppColors.success
                                : AppColors.primaryLight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 6,
                        ),

                        const SizedBox(height: 4), // Reduced from 6 to 4

                        // Lecture Count
                        Text(
                          '$completedLectures of $totalLectures lectures completed',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                    fontSize: 11, // Slightly smaller font
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10), // Reduced from 12 to 10

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEnrolled
                            ? AppColors.success
                            : AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8), // Reduced from 10 to 8
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isEnrolled ? 'Continue Learning' : 'Enroll Now',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderThumbnail(String category) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.getCategoryColor(0).withOpacity(0.8),
            AppColors.getCategoryColor(0).withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(category),
          size: 48,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'programming':
      case 'coding':
        return Icons.code;
      case 'design':
      case 'ui/ux':
        return Icons.design_services;
      case 'business':
      case 'marketing':
        return Icons.business;
      case 'language':
      case 'english':
        return Icons.language;
      case 'music':
        return Icons.music_note;
      case 'photography':
        return Icons.camera_alt;
      default:
        return Icons.school;
    }
  }
}
