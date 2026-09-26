import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_card.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    
    // Mock reports
    final reports = [
      {'title': 'Q3 Security Audit', 'date': 'Oct 12, 2023', 'type': 'PDF', 'size': '2.4 MB'},
      {'title': 'Weekly Scan Summary', 'date': 'Oct 05, 2023', 'type': 'PDF', 'size': '1.1 MB'},
      {'title': 'Deepfake Incident Report', 'date': 'Sep 28, 2023', 'type': 'PDF', 'size': '3.7 MB'},
    ];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Generated Reports',
            style: TextStyle(
                color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: DSAuroraBackground(
        subtle: true,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final r = reports[index];
            return DSCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded, color: primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['title']!,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${r['date']} • ${r['size']}',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.download_rounded, color: textSecondary),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Downloading ${r['title']}...')),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.share_rounded, color: textSecondary),
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sharing ${r['title']}...')),
                          );
                        },
                      ),
                    ],
                  )
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.05, end: 0);
          },
        ),
      ),
    );
  }
}
