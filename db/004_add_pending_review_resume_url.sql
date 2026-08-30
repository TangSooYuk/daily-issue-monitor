-- Lets a free-text Telegram reply ("승인: 코멘트" / "거절: 코멘트") resume the currently
-- pending news-review Wait node, by remembering that node's resume URL per keyword row.
alter table trending_keywords
  add column if not exists pending_review_resume_url text;
