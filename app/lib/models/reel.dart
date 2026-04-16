// Direct Pollinations AI - turbo model for fast image generation (~1-2s)
String _buildImageUrl(String prompt, {int width = 512, int height = 768}) {
  // Cap prompt to avoid URL length issues (Pollinations has limits)
  String trimmed = prompt.length > 180 ? prompt.substring(0, 180) : prompt;
  final enhanced = '$trimmed, cinematic lighting, vibrant colors, detailed';
  final encoded = Uri.encodeComponent(enhanced);
  final seed = prompt.hashCode.abs() % 1000000;
  // turbo model is much faster than flux (~1-2s vs ~5s)
  return 'https://image.pollinations.ai/prompt/$encoded?width=$width&height=$height&model=turbo&nologo=true&enhance=true&seed=$seed';
}

class ReelSlide {
  final String heading;
  final String content;
  final String emoji;
  final String imagePrompt;
  final String sourceQuote;
  final int pageNumber;

  ReelSlide({
    required this.heading,
    required this.content,
    required this.emoji,
    this.imagePrompt = '',
    this.sourceQuote = '',
    this.pageNumber = 0,
  });

  String get imageUrl {
    final prompt = imagePrompt.isNotEmpty
        ? imagePrompt
        : 'educational illustration about ${heading.length > 60 ? heading.substring(0, 60) : heading}, digital art, vibrant colors, detailed';
    return _buildImageUrl(prompt);
  }

  factory ReelSlide.fromJson(Map<String, dynamic> json) {
    return ReelSlide(
      heading: json['heading'] ?? '',
      content: json['content'] ?? '',
      emoji: json['emoji'] ?? '',
      imagePrompt: json['imagePrompt'] ?? '',
      sourceQuote: json['sourceQuote'] ?? '',
      pageNumber: json['pageNumber'] ?? 0,
    );
  }
}

class ReelQuiz {
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;

  ReelQuiz({
    required this.question,
    required this.options,
    required this.answer,
    this.explanation = '',
  });

  factory ReelQuiz.fromJson(Map<String, dynamic> json) {
    return ReelQuiz(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      answer: json['answer'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }
}

class ReelScene {
  final String text;
  final String emoji;
  final int duration;
  final String transition;
  final List<String> backgroundGradient;
  final String imagePrompt;
  final String sourceQuote;
  final int pageNumber;

  ReelScene({
    required this.text,
    required this.emoji,
    required this.duration,
    required this.transition,
    required this.backgroundGradient,
    this.imagePrompt = '',
    this.sourceQuote = '',
    this.pageNumber = 0,
  });

  String get imageUrl {
    final shortText = text.length > 60 ? text.substring(0, 60) : text;
    final prompt = imagePrompt.isNotEmpty
        ? imagePrompt
        : 'educational scene about $shortText, digital art, vibrant colors, detailed';
    return _buildImageUrl(prompt);
  }

  factory ReelScene.fromJson(Map<String, dynamic> json) {
    return ReelScene(
      text: json['text'] ?? '',
      emoji: json['emoji'] ?? '',
      duration: json['duration'] ?? 3,
      transition: json['transition'] ?? 'fade',
      backgroundGradient: List<String>.from(json['backgroundGradient'] ?? ['#667eea', '#764ba2']),
      imagePrompt: json['imagePrompt'] ?? '',
      sourceQuote: json['sourceQuote'] ?? '',
      pageNumber: json['pageNumber'] ?? 0,
    );
  }
}

class Reel {
  final String id;
  final String userId;
  final String title;
  final List<ReelSlide> slides;
  final List<ReelScene> scenes;
  final String narration;
  final ReelQuiz? quiz;
  final List<String> tags;
  final String subject;
  final String style;
  final String type;
  final int likes;
  final int views;
  final String createdAt;
  final String pdfName;
  final String groupId;
  final String explanationStyle;
  final String sourceQuote;
  final int pageNumber;

  Reel({
    required this.id,
    required this.userId,
    required this.title,
    required this.slides,
    required this.scenes,
    required this.narration,
    this.quiz,
    required this.tags,
    required this.subject,
    this.style = 'realistic',
    required this.type,
    required this.likes,
    required this.views,
    required this.createdAt,
    required this.pdfName,
    this.groupId = '',
    this.explanationStyle = '',
    this.sourceQuote = '',
    this.pageNumber = 0,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      slides: (json['slides'] as List?)
              ?.map((s) => ReelSlide.fromJson(s))
              .toList() ??
          [],
      scenes: (json['scenes'] as List?)
              ?.map((s) => ReelScene.fromJson(s))
              .toList() ??
          [],
      narration: json['narration'] ?? '',
      quiz: json['quiz'] != null ? ReelQuiz.fromJson(json['quiz']) : null,
      tags: List<String>.from(json['tags'] ?? []),
      subject: json['subject'] ?? '',
      style: json['style'] ?? 'realistic',
      type: json['type'] ?? 'card',
      likes: json['likes'] ?? 0,
      views: json['views'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      pdfName: json['pdfName'] ?? '',
      groupId: json['groupId'] ?? '',
      explanationStyle: json['explanationStyle'] ?? '',
      sourceQuote: json['sourceQuote'] ?? '',
      pageNumber: json['pageNumber'] ?? 0,
    );
  }
}
