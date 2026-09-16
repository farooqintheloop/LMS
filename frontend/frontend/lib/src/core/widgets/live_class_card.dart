import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class LiveClassCard extends StatelessWidget {
  final Map<String, dynamic> liveClass;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const LiveClassCard({
    super.key,
    required this.liveClass,
    this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final onSurface = colorScheme.onSurface;
    final title = liveClass['title'] ?? 'Untitled Class';
    final instructor = liveClass['instructor']?['name'] ??
        liveClass['instructor_name'] ??
        'Unknown Instructor';
    final scheduledStart = liveClass['scheduled_start'];
    final duration = liveClass['duration'] ?? 60;
    final platform = liveClass['platform'] ?? 'Zoom';
    final status = _getLiveClassStatus(scheduledStart);
    final isLive = status == 'live';
    final isUpcoming = status == 'upcoming';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isLive ? AppColors.live : colorScheme.primary.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isLive
                    ? AppColors.live.withOpacity(0.1)
                    : colorScheme.primary.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isLive ? AppColors.live : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isLive ? 'LIVE NOW' : 'UPCOMING',
                    style: TextStyle(
                      color: isLive ? AppColors.live : colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  // Platform icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getPlatformIcon(platform),
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Instructor
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instructor',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              instructor,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: onSurface,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Time and Duration
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          context: context,
                          icon: Icons.schedule,
                          label: 'Start Time',
                          value: _formatDateTime(scheduledStart),
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoItem(
                          context: context,
                          icon: Icons.timer,
                          label: 'Duration',
                          value: '$duration min',
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Platform
                  _buildInfoItem(
                    context: context,
                    icon: _getPlatformIcon(platform),
                    label: 'Platform',
                    value: platform,
                    color: AppColors.secondary,
                  ),

                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLive || isUpcoming ? onJoin : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isLive ? AppColors.live : colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLive ? Icons.play_arrow : Icons.video_call,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isLive ? 'Join Now' : 'Join Class',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
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
      ),
    );
  }

  Widget _buildInfoItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final onSurface = colorScheme.onSurface;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getLiveClassStatus(dynamic scheduledStart) {
    if (scheduledStart == null) return 'unknown';

    try {
      final startTime = DateTime.parse(scheduledStart);
      final now = DateTime.now();
      final difference = startTime.difference(now);

      if (difference.isNegative && difference.inMinutes.abs() < 60) {
        return 'live';
      } else if (difference.isNegative) {
        return 'ended';
      } else {
        return 'upcoming';
      }
    } catch (e) {
      return 'unknown';
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'TBD';

    try {
      final dt = DateTime.parse(dateTime);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final classDate = DateTime(dt.year, dt.month, dt.day);

      if (classDate == today) {
        return 'Today, ${DateFormat('h:mm a').format(dt)}';
      } else if (classDate == tomorrow) {
        return 'Tomorrow, ${DateFormat('h:mm a').format(dt)}';
      } else {
        return DateFormat('MMM d, h:mm a').format(dt);
      }
    } catch (e) {
      return 'TBD';
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'zoom':
        return Icons.video_call;
      case 'google meet':
      case 'meet':
        return Icons.video_camera_front;
      case 'teams':
        return Icons.groups;
      case 'skype':
        return Icons.chat;
      default:
        return Icons.video_call;
    }
  }
}
