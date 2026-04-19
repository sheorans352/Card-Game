import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/blog.dart';
import '../shared/config/env_config.dart';

final blogServiceProvider = Provider((ref) {
  final config = ref.watch(appConfigProvider);
  return BlogService(isStaging: config.isStaging);
});

final blogsProvider = FutureProvider<List<Blog>>((ref) async {
  final service = ref.watch(blogServiceProvider);
  return service.fetchBlogs();
});

final blogDetailProvider = FutureProvider.family<Blog?, String>((ref, slug) async {
  final service = ref.watch(blogServiceProvider);
  return service.fetchBlogBySlug(slug);
});

class BlogService {
  final _client = Supabase.instance.client;

  /// [isStaging] true  → shows 'staging' + 'published' blogs (preview mode)
  /// [isStaging] false → shows 'published' blogs only (live site)
  final bool isStaging;

  BlogService({required this.isStaging});

  Future<List<Blog>> fetchBlogs() async {
    var query = _client.from('blogs').select();

    if (isStaging) {
      // Staging sees everything except drafts
      query = query.inFilter('status', ['staging', 'published']);
    } else {
      // Production sees only fully published blogs
      query = query.eq('status', 'published');
    }

    final response = await query.order('published_at', ascending: false);
    return (response as List).map((json) => Blog.fromJson(json)).toList();
  }

  Future<Blog?> fetchBlogBySlug(String slug) async {
    var query = _client
        .from('blogs')
        .select()
        .eq('slug', slug);

    if (isStaging) {
      query = query.inFilter('status', ['staging', 'published']);
    } else {
      query = query.eq('status', 'published');
    }

    final response = await query.maybeSingle();
    if (response == null) return null;
    return Blog.fromJson(response);
  }
}
