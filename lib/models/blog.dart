class Blog {
  final String id;
  final String slug;
  final String? category;
  final String title;
  final String? h1;
  final String? summary;
  final String? description;
  final String content;
  final String author;
  final String? imageUrl;
  final List<String> relatedBlogSlugs;
  final List<Map<String, String>> internalLinks;
  final DateTime publishedAt;
  final bool isPublished;

  Blog({
    required this.id,
    required this.slug,
    this.category,
    required this.title,
    this.h1,
    this.summary,
    this.description,
    required this.content,
    required this.author,
    this.imageUrl,
    this.relatedBlogSlugs = const [],
    this.internalLinks = const [],
    required this.publishedAt,
    required this.isPublished,
  });

  factory Blog.fromJson(Map<String, dynamic> json) {
    return Blog(
      id: json['id'],
      slug: json['slug'],
      category: json['category'],
      title: json['title'],
      h1: json['h1'],
      summary: json['summary'],
      description: json['description'],
      content: json['content'],
      author: json['author'],
      imageUrl: json['image_url'],
      relatedBlogSlugs: List<String>.from(json['related_blog_slugs'] ?? []),
      internalLinks: (json['internal_links'] as List?)
              ?.map((item) => Map<String, String>.from(item))
              .toList() ??
          [],
      publishedAt: DateTime.parse(json['published_at']),
      isPublished: json['is_published'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'category': category,
      'title': title,
      'h1': h1,
      'summary': summary,
      'description': description,
      'content': content,
      'author': author,
      'image_url': imageUrl,
      'related_blog_slugs': relatedBlogSlugs,
      'internal_links': internalLinks,
      'published_at': publishedAt.toIso8601String(),
      'is_published': isPublished,
    };
  }
}
