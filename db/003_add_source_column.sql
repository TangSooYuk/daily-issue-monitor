-- Tracks whether a keyword came from automatic trend detection or manual /post command.
alter table trending_keywords
  add column if not exists source text default 'trend';
