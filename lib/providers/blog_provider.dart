import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/blog.dart';

final blogServiceProvider = Provider((ref) => BlogService());

final blogsProvider = FutureProvider<List<Blog>>((ref) async {
  final service = ref.watch(blogServiceProvider);
  return service.fetchPublishedBlogs();
});

final blogDetailProvider = FutureProvider.family<Blog?, String>((ref, slug) async {
  final service = ref.watch(blogServiceProvider);
  return service.fetchBlogBySlug(slug);
});

class BlogService {
  final _client = Supabase.instance.client;

  Future<List<Blog>> fetchPublishedBlogs() async {
    final response = await _client
        .from('blogs')
        .select()
        .eq('is_published', true)
        .order('published_at', ascending: false);
    
    return (response as List).map((json) => Blog.fromJson(json)).toList();
  }

  Future<Blog?> fetchBlogBySlug(String slug) async {
    final response = await _client
        .from('blogs')
        .select()
        .eq('slug', slug)
        .eq('is_published', true)
        .maybeSingle();

    if (response == null) return null;
    return Blog.fromJson(response);
  }
}
