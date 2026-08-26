-- Run this after the original schema (trending_keywords, keyword_news) already exists.
-- Adds columns needed to close the loop once a keyword has been turned into a blog post.

alter table trending_keywords
  add column if not exists wp_post_id bigint,
  add column if not exists posted_at timestamptz;
