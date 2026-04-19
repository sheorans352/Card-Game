import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html; // For web SEO titles
import '../providers/blog_provider.dart';
import '../widgets/breadcrumb_widget.dart';

class BlogDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  const BlogDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends ConsumerState<BlogDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  void _updatePageTitle(String title) {
    html.document.title = '$title | Casino Delight';
    // You could also add meta tags here via html.document.querySelector('meta[name="description"]')
  }

  @override
  Widget build(BuildContext context) {
    final blogAsync = ref.watch(blogDetailProvider(widget.slug));

    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      body: blogAsync.when(
        data: (blog) {
          if (blog == null) {
            return const Center(
              child: Text('Article not found', style: TextStyle(color: Colors.white)),
            );
          }

          // Update SEO title
          _updatePageTitle(blog.title);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.black,
                toolbarHeight: 70,
                floating: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => context.go('/blogs'),
                ),
              title: Text(
                  blog.title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.4,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Breadcrumbs
                      BreadcrumbWidget(items: [
                        BreadcrumbItem(label: 'Home', route: '/'),
                        BreadcrumbItem(label: 'Blogs', route: '/blogs'),
                        BreadcrumbItem(label: blog.title),
                      ]),
                      const SizedBox(height: 32),
                      // H1
                      Text(
                        blog.h1 ?? blog.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Summary
                      if (blog.summary != null)
                        Text(
                          blog.summary!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      const SizedBox(height: 32),
                      // Metadata
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.person, size: 16, color: Colors.black),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                blog.author,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Published ${DateFormat('MMM dd, yyyy').format(blog.publishedAt)}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      // Markdown Content
                      MarkdownBody(
                        data: blog.content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          h1: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.4,
                          ),
                          h2: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                          h3: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                          p: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            height: 1.7,
                          ),
                          a: const TextStyle(
                            color: Colors.amber,
                            decoration: TextDecoration.underline,
                          ),
                          listBullet: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            // ignore: deprecated_member_use
                            html.window.open(href, '_blank');
                          }
                        },
                      ),
                      if (blog.internalLinks.isNotEmpty) ...[
                        const SizedBox(height: 48),
                        const Text(
                          'USEFUL LINKS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...blog.internalLinks.map((link) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: InkWell(
                                onTap: () => html.window.open(link['url']!, '_blank'),
                                child: Text(
                                  '• ${link['label']}',
                                  style: const TextStyle(color: Colors.amber, fontSize: 14),
                                ),
                              ),
                            )),
                      ],
                      const SizedBox(height: 60),
                      // Related Blogs
                      if (blog.relatedBlogSlugs.isNotEmpty) ...[
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 32),
                        const Text(
                          'RELATED ARTICLES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Explore more guides to improve your game.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        // Note: In a real app, you'd fetch the related blogs here.
                        // For now we show the list of slugs as a placeholder.
                        ...blog.relatedBlogSlugs.map((slug) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(slug, style: const TextStyle(color: Colors.white70)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                              onTap: () => context.go('/blogs/$slug'),
                            )),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }
}
