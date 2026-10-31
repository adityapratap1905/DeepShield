import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_card.dart';
import '../data/learning_content.dart';

class LearnScreen extends StatefulWidget {
  final String? initialCategory;

  const LearnScreen({super.key, this.initialCategory});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null &&
        learningCategories.contains(widget.initialCategory)) {
      _category = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;
    final query = _query.trim().toLowerCase();
    final articles = learningArticles.where((article) {
      final matchesCategory =
          _category == 'All' || article.category == _category;
      final matchesQuery = query.isEmpty ||
          article.title.toLowerCase().contains(query) ||
          article.summary.toLowerCase().contains(query) ||
          article.keyPoints.any((point) => point.toLowerCase().contains(query));
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text('Learn',
            style: TextStyle(
                color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          children: [
            Text('Clear, practical guides for navigating digital media.',
                style: TextStyle(color: textSecondary, height: 1.45)),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search learning guides',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  ...learningCategories,
                ].map((category) {
                  final selected = category == _category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = category),
                      selectedColor: accent.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: selected ? accent : textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: selected
                            ? accent.withValues(alpha: 0.25)
                            : (isDark
                                ? AppColors.cardBorderDark
                                : AppColors.cardBorderLight),
                      ),
                      backgroundColor:
                          isDark ? AppColors.cardDark : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            if (articles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text('No guides match those filters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary)),
              )
            else
              for (final article in articles) ...[
                _LearningCard(
                  article: article,
                  accent: accent,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showArticle(article),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  void _showArticle(LearningArticle article) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.category.toUpperCase(),
                  style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(article.title,
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text('${article.readMinutes} min read',
                  style: TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 18),
              for (final point in article.keyPoints) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, size: 7, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(point,
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 15,
                              height: 1.55)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'These tips provide context, not a guarantee. Automated media checks can miss manipulations or flag authentic content.',
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    height: 1.45,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningCard extends StatelessWidget {
  final LearningArticle article;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _LearningCard({
    required this.article,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => DSCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(article.icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.category.toUpperCase(),
                      style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(article.title,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(article.summary,
                      style: TextStyle(
                          color: textSecondary, fontSize: 12, height: 1.45)),
                  const SizedBox(height: 8),
                  Text('${article.readMinutes} min read',
                      style: TextStyle(color: textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary),
          ],
        ),
      );
}
