-- PostgreSQL schema for XDU Treehole.
-- Recommended: PostgreSQL 13+.

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL DEFAULT '',
  alias VARCHAR(128) NOT NULL,
  nickname VARCHAR(128) NOT NULL DEFAULT '',
  student_id VARCHAR(32) NOT NULL DEFAULT '',
  avatar_url VARCHAR(512) NOT NULL DEFAULT '',
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at TIMESTAMPTZ NULL,
  allow_stranger_dm BOOLEAN NOT NULL DEFAULT TRUE,
  show_contactable BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  banned BOOLEAN NOT NULL DEFAULT FALSE,
  muted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS sessions (
  token VARCHAR(128) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS email_codes (
  email VARCHAR(255) PRIMARY KEY,
  code VARCHAR(8) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS channels (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(64) NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tags (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(64) NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sensitive_words (
  id BIGSERIAL PRIMARY KEY,
  word VARCHAR(64) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS settings (
  setting_key VARCHAR(64) PRIMARY KEY,
  value_int INTEGER NULL,
  value_text TEXT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meta_seq (
  seq_key VARCHAR(32) PRIMARY KEY,
  seq_value INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS posts (
  id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  channel_id BIGINT NULL REFERENCES channels(id) ON DELETE SET NULL,
  has_image BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(16) NOT NULL,
  allow_comment BOOLEAN NOT NULL DEFAULT TRUE,
  allow_dm BOOLEAN NOT NULL DEFAULT FALSE,
  author_alias VARCHAR(128) NOT NULL,
  author_id VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  review_status VARCHAR(16) NOT NULL DEFAULT 'pending',
  risk_marked BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS post_tags (
  post_id VARCHAR(64) NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, tag_id)
);

CREATE TABLE IF NOT EXISTS comments (
  id VARCHAR(64) PRIMARY KEY,
  post_id VARCHAR(64) NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL,
  author_alias VARCHAR(128) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  like_count INTEGER NOT NULL DEFAULT 0,
  review_status VARCHAR(16) NOT NULL DEFAULT 'pending',
  risk_marked BOOLEAN NOT NULL DEFAULT FALSE,
  parent_id VARCHAR(64) NULL REFERENCES comments(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS likes (
  user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id VARCHAR(64) NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE IF NOT EXISTS favorites (
  user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id VARCHAR(64) NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE IF NOT EXISTS reports (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL,
  reporter_alias VARCHAR(128) NOT NULL,
  target_type VARCHAR(32) NOT NULL,
  target_id VARCHAR(64) NOT NULL,
  reason VARCHAR(128) NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  result TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL,
  handled_at TIMESTAMPTZ NULL,
  handled_by VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS dm_requests (
  id VARCHAR(64) PRIMARY KEY,
  to_user_id VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL,
  from_alias VARCHAR(128) NOT NULL,
  from_user_id VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL,
  from_avatar_url VARCHAR(512) NOT NULL DEFAULT '',
  reason TEXT NOT NULL DEFAULT '',
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NULL
);

CREATE TABLE IF NOT EXISTS conversations (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL,
  peer_user_id VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL,
  name VARCHAR(128) NOT NULL,
  avatar_url VARCHAR(512) NOT NULL DEFAULT '',
  last_message TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id VARCHAR(64) PRIMARY KEY,
  actor_id VARCHAR(64) NULL REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(64) NOT NULL,
  detail TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_posts_channel_status_created
  ON posts (channel_id, status, deleted, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_author_created
  ON posts (author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_review_deleted
  ON posts (review_status, deleted, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_status_created
  ON posts (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_post_tags_tag_post
  ON post_tags (tag_id, post_id);

CREATE INDEX IF NOT EXISTS idx_comments_post_created
  ON comments (post_id, deleted, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_user_created
  ON comments (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_review_deleted
  ON comments (review_status, deleted, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_parent
  ON comments (parent_id);

CREATE INDEX IF NOT EXISTS idx_likes_post_user
  ON likes (post_id, user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_post_user
  ON favorites (post_id, user_id);

CREATE INDEX IF NOT EXISTS idx_reports_status_created
  ON reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_target
  ON reports (target_type, target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_user_created
  ON reports (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_dm_requests_to_status_created
  ON dm_requests (to_user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dm_requests_status_updated
  ON dm_requests (status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversations_user_updated
  ON conversations (user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created
  ON audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_created
  ON audit_logs (actor_id, created_at DESC);
