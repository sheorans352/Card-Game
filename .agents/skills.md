# Casino Delight: Core Skills

This document tracks the technical patterns and skills required to maintain and evolve the **Casino Delight** codebase.

## 📱 Flutter (SEO & UI)
- **Path URL Strategy**: Configured to use standard clean URLs (`/path`) instead of hash strategy.
- **Dynamic Titles**: Implemented in `BlogDetailScreen` using `dart:html` for browser tab SEO.
- **Markdown Rendering**: Mastered using `flutter_markdown` for consistent styling of articles (H1-H3, links, lists).
- **Responsive Hub**: Multi-column grid system for game cards and blog entries.

## ☁️ Supabase (Backend)
- **Database Architecture**: 
  - `blogs` table with automated `published_at` capture.
  - JSONB/Array support for `related_blogs` and `internal_links`.
- **Storage Management**: 
  - `blog-images` bucket setup for automated image hosting.
- **RLS (Security)**: Public-read policies for published content.

## ⚙️ n8n Automation
- **Multi-Source Ingestion**: 
  - Reading structured metadata from **Excel`.
  - Downloading long-form content from **Google Docs`.
- **Image Processing**:
  - Reading binary files from the local computer.
  - Automated uploads to Supabase Storage via HTTP API.
- **headless CMS**: Using Supabase as a data source for the Flutter frontend.

## 📐 Standards
- **Naming**: Use `snake_case` for database columns and `camelCase` for Flutter models.
- **Styling**: Maintain the "Dark Gold" theme (Deep Navy background with Gold accents).
