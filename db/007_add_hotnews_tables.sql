-- Backs /hotnews (broadcast), /hotcollect (manual backfill), and the two independent
-- collection paths that feed hotnews_candidates: an hourly RSS+clustering pass (current
-- news, no keyword dependency) and an on-demand /hotcollect DATE backfill (the only way to
-- reach a past date, seeded from hotnews_trend_history + Naver News search).
--
-- Nothing in this file reads or writes trending_keywords/keyword_news (the WordPress
-- auto-posting flow's own tables) -- not even read-only. hotnews_trend_history below is a
-- deliberate, independent duplicate of that flow's own Google Trends RSS collection, kept
-- fully separate so the two features' data/lifecycles never couple.

-- Historical keyword-by-date log, populated by its own independent Trends RSS collector
-- (every 3h) purely so /hotcollect DATE has something to search Naver News against for a
-- past date. Only dates from whenever that collector started running are backfillable.
create table hotnews_trend_history (
  id bigint generated always as identity primary key,
  keyword text not null,
  rank int,
  approx_traffic text,
  trend_link text,
  region text default 'KR',
  trend_date date not null,
  created_at timestamptz default now(),
  unique (keyword, trend_date, region)
);

-- Individual articles/story-clusters, accumulated over time. Two different collectors write
-- here with two different 'hotness' signals:
--   - RSS+clustering (hourly, current news): outlet_count set (how many of the 21 tracked
--     press outlets independently covered this story in the same run), rank/approx_traffic
--     null, trend_link null.
--   - /hotcollect DATE backfill (Naver search seeded from hotnews_trend_history): rank/
--     approx_traffic/trend_link set (from hotnews_trend_history), outlet_count null.
-- unique(article_url) means an article already stored (e.g. still circulating next hour)
-- is skipped; a genuinely new article/story still gets added -- this is how candidates
-- accumulate through the day.
create table hotnews_candidates (
  id bigint generated always as identity primary key,
  keyword text not null, -- the trending keyword (backfill) or Claude-labeled story topic (RSS clustering)
  rank int,
  approx_traffic text,
  trend_link text,
  outlet_count int, -- number of distinct press outlets whose RSS covered this story in the same run (RSS path only)
  article_title text not null,
  article_url text not null unique,
  article_source text, -- 'naver_news' (backfill) or comma-joined outlet names (RSS clustering)
  published_at timestamptz,
  region text default 'KR',
  candidate_date date not null,
  posted_at timestamptz,
  wp_post_id bigint,
  created_at timestamptz default now()
);

-- One row per broadcast (the 3-hourly auto list, or an on-demand /hotnews list). Holds the
-- exact snapshot of items shown (so retries display the same numbering) and the currently-live
-- Wait node's resume URL, so a typed '1,3,7' reply can look up and resume the right execution --
-- same mechanism as trending_keywords.pending_review_resume_url, just its own table since a
-- broadcast spans many hotnews_candidates rows rather than being one row itself.
create table hotnews_broadcast (
  id bigint generated always as identity primary key,
  chat_id text not null,
  items jsonb not null, -- [{index, candidate_id, keyword, trend_link, candidate_date, article_title, article_url, outlet_count}, ...]
  attempt int default 1,
  pending_resume_url text,
  created_at timestamptz default now()
);
