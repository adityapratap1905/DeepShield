import 'package:flutter/material.dart';

class LearningArticle {
  final String id;
  final String title;
  final String category;
  final String summary;
  final int readMinutes;
  final IconData icon;
  final List<String> keyPoints;

  const LearningArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.readMinutes,
    required this.icon,
    required this.keyPoints,
  });
}

/// Editorial learning content bundled with the app, not generated API results.
const learningArticles = <LearningArticle>[
  LearningArticle(
    id: 'deepfakes',
    title: 'What are deepfakes?',
    category: 'Deepfakes',
    summary: 'How synthetic and edited media can change what we see and hear.',
    readMinutes: 3,
    icon: Icons.movie_filter_outlined,
    keyPoints: [
      'Deepfakes use machine learning or editing tools to create or alter audio, images, or video.',
      'Visual clues can be subtle or absent. A detector can help, but no single check settles whether media is genuine.',
      'Check who first published the media and look for independent reporting before sharing it.',
    ],
  ),
  LearningArticle(
    id: 'image-checks',
    title: 'Check an image’s source',
    category: 'Media checks',
    summary: 'A few practical steps to add context before trusting a photo.',
    readMinutes: 2,
    icon: Icons.image_search_outlined,
    keyPoints: [
      'Look for the earliest known publication and compare captions across reliable sources.',
      'Search for earlier copies of the image and check whether the scene matches the claimed date and place.',
      'Treat metadata and automated scores as clues. They can be missing, changed, or wrong.',
    ],
  ),
  LearningArticle(
    id: 'video-checks',
    title: 'Verify a video carefully',
    category: 'Media checks',
    summary: 'Understand what frame sampling can show and what it can miss.',
    readMinutes: 3,
    icon: Icons.video_library_outlined,
    keyPoints: [
      'Keep an original copy and note where the clip came from before editing or reposting it.',
      'A sampled-frame scan checks selected moments, not every frame or every kind of manipulation.',
      'Compare the clip with other footage, trusted reports, and the original source.',
    ],
  ),
  LearningArticle(
    id: 'phishing',
    title: 'Spot common phishing tactics',
    category: 'Cybersecurity',
    summary: 'Recognize pressure, impersonation, and suspicious links.',
    readMinutes: 3,
    icon: Icons.link_off_rounded,
    keyPoints: [
      'Be cautious when a message creates urgency or asks for passwords, payment, or verification codes.',
      'Check the full domain and reach an organization through a known address or app, not the message link.',
      'Report suspicious messages through the service that received them and avoid forwarding the link.',
    ],
  ),
  LearningArticle(
    id: 'privacy',
    title: 'Protect your privacy online',
    category: 'Online safety',
    summary: 'Simple habits for safer accounts and less exposed personal data.',
    readMinutes: 2,
    icon: Icons.lock_outline_rounded,
    keyPoints: [
      'Use a unique password for each important account and enable multi-factor authentication when available.',
      'Review app permissions and avoid posting location or identity details that are not needed.',
      'Pause before uploading someone else’s image or sharing personal media publicly.',
    ],
  ),
];

List<String> get learningCategories =>
    learningArticles.map((article) => article.category).toSet().toList();
