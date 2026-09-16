import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_app_bar.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: 'Privacy Policy',
        showThemeToggle: true,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryLight.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primaryLight,
                                    AppColors.primaryDark,
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.privacy_tip,
                                size: 40,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Privacy Policy',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${DateTime.now().toString().split(' ')[0]}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Privacy Policy Content
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      context,
                      '1. Information We Collect',
                      'We collect information you provide directly to us, such as when you create an account, enroll in courses, or contact us for support. This may include:\n\n• Personal information (name, email address, phone number)\n• Account credentials and preferences\n• Course progress and completion data\n• Communication records and support requests\n• Device information and usage analytics',
                    ),
                    _buildSection(
                      context,
                      '2. How We Use Your Information',
                      'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Process transactions and send related information\n• Send technical notices, updates, and support messages\n• Respond to your comments and questions\n• Monitor and analyze trends and usage\n• Personalize your learning experience\n• Ensure platform security and prevent fraud',
                    ),
                    _buildSection(
                      context,
                      '3. Information Sharing and Disclosure',
                      'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except in the following circumstances:\n\n• With your explicit consent\n• To comply with legal obligations\n• To protect our rights and prevent fraud\n• With service providers who assist in platform operations\n• In connection with a business transfer or acquisition',
                    ),
                    _buildSection(
                      context,
                      '4. Data Security',
                      'We implement appropriate technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet or electronic storage is 100% secure.',
                    ),
                    _buildSection(
                      context,
                      '5. Data Retention',
                      'We retain your personal information for as long as necessary to provide our services and fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required or permitted by law.',
                    ),
                    _buildSection(
                      context,
                      '6. Your Rights and Choices',
                      'You have the right to:\n\n• Access and update your personal information\n• Request deletion of your account and data\n• Opt-out of marketing communications\n• Request data portability\n• Object to certain processing activities\n• Withdraw consent where applicable',
                    ),
                    _buildSection(
                      context,
                      '7. Cookies and Tracking Technologies',
                      'We use cookies and similar tracking technologies to enhance your experience on our platform. These technologies help us:\n\n• Remember your preferences and settings\n• Analyze platform usage and performance\n• Provide personalized content and recommendations\n• Ensure platform security and functionality',
                    ),
                    _buildSection(
                      context,
                      '8. Third-Party Services',
                      'Our platform may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to review their privacy policies before providing any personal information.',
                    ),
                    _buildSection(
                      context,
                      '9. Children\'s Privacy',
                      'Our services are not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information.',
                    ),
                    _buildSection(
                      context,
                      '10. International Data Transfers',
                      'Your information may be transferred to and processed in countries other than your own. We ensure that such transfers comply with applicable data protection laws and implement appropriate safeguards.',
                    ),
                    _buildSection(
                      context,
                      '11. Changes to This Privacy Policy',
                      'We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new Privacy Policy on this page and updating the "Last updated" date.',
                    ),
                    _buildSection(
                      context,
                      '12. Contact Us',
                      'If you have any questions about this Privacy Policy or our privacy practices, please contact us at:\n\nEmail: privacy@amlms.com\nPhone: +1 (555) 123-4567\nAddress: 123 Learning Street, Education City, EC 12345\n\nData Protection Officer: dpo@amlms.com',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Accept Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: AppColors.primaryLight.withOpacity(0.3),
                  ),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLight,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
