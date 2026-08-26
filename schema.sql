create table trending_keywords (
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

create table keyword_news (
  id bigint generated always as identity primary key,
  keyword_id bigint references trending_keywords(id) on delete cascade,
  title text not null,
  url text not null,
  source text,
  published_at timestamptz,
  used_in_post boolean default false,
  created_at timestamptz default now()
);
