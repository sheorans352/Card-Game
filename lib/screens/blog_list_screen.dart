import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/blog_provider.dart';
import '../models/blog.dart';

class BlogListScreen extends ConsumerWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogsAsync = ref.watch(blogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'ARTICLES & GUIDES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        centerTitle: true,
      ),
      body: blogsAsync.when(
        data: (blogs) => blogs.isEmpty
            ? const Center(
                child: Text('No articles yet.', style: TextStyle(color: Colors.white38)),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: blogs.length,
                itemBuilder: (context, index) {
                  final blog = blogs[index];
                  return _BlogListItem(blog: blog);
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }
}

class _BlogListItem extends StatefulWidget {
  final Blog blog;
  const _BlogListItem({required this.blog});

  @override
  State<_BlogListItem> createState() => _BlogListItemState();
}

class _BlogListItemState extends State<_BlogListItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => context.go('/blogs/${widget.blog.slug}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovering ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering ? Colors.amber.withOpacity(0.4) : Colors.white.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: _hovering
                ? [BoxShadow(color: Colors.amber.withOpacity(0.05), blurRadius: 20)]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GUIDE',
                      style: TextStyle(
                        color: Colors.amber.withOpacity(0.8),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM dd, yyyy').format(widget.blog.publishedAt),
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.blog.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              if (widget.blog.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.blog.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.white24),
                  const SizedBox(width: 6),
                  Text(
                    widget.blog.author,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const Spacer(),
                  Text(
                    'READ ARTICLE →',
                    style: TextStyle(
                      color: _hovering ? Colors.amber : Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
