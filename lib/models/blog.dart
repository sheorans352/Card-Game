class Blog {
  final String id;
  final String slug;
  final String title;
  final String? description;
  final String content;
  final String author;
  final String? imageUrl;
  final DateTime publishedAt;
  final bool isPublished;

  Blog({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    required this.content,
    required this.author,
    this.imageUrl,
    required this.publishedAt,
    required this.isPublished,
  });

  factory Blog.fromJson(Map<String, dynamic> json) {
    return Blog(
      id: json['id'],
      slug: json['slug'],
      title: json['title'],
      description: json['description'],
      content: json['content'],
      author: json['author'],
      imageUrl: json['image_url'],
      publishedAt: DateTime.parse(json['published_at']),
      isPublished: json['is_published'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'description': description,
      'content': content,
      'author': author,
      'image_url': imageUrl,
      'published_at': publishedAt.toIso8601String(),
      'is_published': isPublished,
    };
  }
}
