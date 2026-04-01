-- MySQL schema for XDU Treehole.
-- Recommended: MySQL 8.0+.

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL DEFAULT '',
  alias VARCHAR(128) NOT NULL,
  nickname VARCHAR(128) NOT NULL DEFAULT '',
  student_id VARCHAR(32) NOT NULL DEFAULT '',
  avatar_url VARCHAR(512) NOT NULL DEFAULT '',
  verified TINYINT(1) NOT NULL DEFAULT 0,
  verified_at DATETIME(6) NULL,
  allow_stranger_dm TINYINT(1) NOT NULL DEFAULT 1,
  show_contactable TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  is_admin TINYINT(1) NOT NULL DEFAULT 0,
  banned TINYINT(1) NOT NULL DEFAULT 0,
  muted TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sessions (
  token VARCHAR(128) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS email_codes (
  email VARCHAR(255) PRIMARY KEY,
  code VARCHAR(8) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS channels (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(64) NOT NULL UNIQUE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tags (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(64) NOT NULL UNIQUE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sensitive_words (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  word VARCHAR(64) NOT NULL UNIQUE,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS settings (
  setting_key VARCHAR(64) PRIMARY KEY,
  value_int INT NULL,
  value_text TEXT NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS meta_seq (
  seq_key VARCHAR(32) PRIMARY KEY,
  seq_value INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS posts (
  id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  channel_id BIGINT NULL,
  has_image TINYINT(1) NOT NULL DEFAULT 0,
  status VARCHAR(16) NOT NULL,
  allow_comment TINYINT(1) NOT NULL DEFAULT 1,
  allow_dm TINYINT(1) NOT NULL DEFAULT 0,
  author_alias VARCHAR(128) NOT NULL,
  author_id VARCHAR(64) NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  review_status VARCHAR(16) NOT NULL DEFAULT 'pending',
  risk_marked TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT fk_posts_channel FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE SET NULL,
  CONSTRAINT fk_posts_author FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS post_tags (
  post_id VARCHAR(64) NOT NULL,
  tag_id BIGINT NOT NULL,
  PRIMARY KEY (post_id, tag_id),
  CONSTRAINT fk_post_tags_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_post_tags_tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS comments (
  id VARCHAR(64) PRIMARY KEY,
  post_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NULL,
  author_alias VARCHAR(128) NOT NULL,
  content TEXT NOT NULL,
  created_at DATETIME(6) NOT NULL,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  like_count INT NOT NULL DEFAULT 0,
  review_status VARCHAR(16) NOT NULL DEFAULT 'pending',
  risk_marked TINYINT(1) NOT NULL DEFAULT 0,
  parent_id VARCHAR(64) NULL,
  CONSTRAINT fk_comments_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_comments_parent FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS likes (
  user_id VARCHAR(64) NOT NULL,
  post_id VARCHAR(64) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (user_id, post_id),
  CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_likes_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS favorites (
  user_id VARCHAR(64) NOT NULL,
  post_id VARCHAR(64) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (user_id, post_id),
  CONSTRAINT fk_favorites_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_favorites_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reports (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NULL,
  reporter_alias VARCHAR(128) NOT NULL,
  target_type VARCHAR(32) NOT NULL,
  target_id VARCHAR(64) NOT NULL,
  reason VARCHAR(128) NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  result TEXT NOT NULL,
  created_at DATETIME(6) NOT NULL,
  handled_at DATETIME(6) NULL,
  handled_by VARCHAR(64) NULL,
  CONSTRAINT fk_reports_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_reports_handler FOREIGN KEY (handled_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS dm_requests (
  id VARCHAR(64) PRIMARY KEY,
  to_user_id VARCHAR(64) NULL,
  from_alias VARCHAR(128) NOT NULL,
  from_user_id VARCHAR(64) NULL,
  from_avatar_url VARCHAR(512) NOT NULL DEFAULT '',
  reason TEXT NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NULL,
  CONSTRAINT fk_dm_requests_user FOREIGN KEY (to_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_dm_requests_from_user FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS conversations (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NULL,
  peer_user_id VARCHAR(64) NULL,
  name VARCHAR(128) NOT NULL,
  avatar_url VARCHAR(512) NOT NULL DEFAULT '',
  last_message TEXT NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_conversations_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_conversations_peer_user FOREIGN KEY (peer_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS audit_logs (
  id VARCHAR(64) PRIMARY KEY,
  actor_id VARCHAR(64) NULL,
  action VARCHAR(64) NOT NULL,
  detail TEXT NOT NULL,
  created_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_posts_channel_status_created
  ON posts (channel_id, status, deleted, created_at);
CREATE INDEX idx_posts_author_created
  ON posts (author_id, created_at);
CREATE INDEX idx_posts_review_deleted
  ON posts (review_status, deleted, created_at);
CREATE INDEX idx_posts_status_created
  ON posts (status, created_at);

CREATE INDEX idx_post_tags_tag_post
  ON post_tags (tag_id, post_id);

CREATE INDEX idx_comments_post_created
  ON comments (post_id, deleted, created_at);
CREATE INDEX idx_comments_user_created
  ON comments (user_id, created_at);
CREATE INDEX idx_comments_review_deleted
  ON comments (review_status, deleted, created_at);
CREATE INDEX idx_comments_parent
  ON comments (parent_id);

CREATE INDEX idx_likes_post_user
  ON likes (post_id, user_id);
CREATE INDEX idx_favorites_post_user
  ON favorites (post_id, user_id);

CREATE INDEX idx_reports_status_created
  ON reports (status, created_at);
CREATE INDEX idx_reports_target
  ON reports (target_type, target_id, created_at);
CREATE INDEX idx_reports_user_created
  ON reports (user_id, created_at);

CREATE INDEX idx_dm_requests_to_status_created
  ON dm_requests (to_user_id, status, created_at);
CREATE INDEX idx_dm_requests_status_updated
  ON dm_requests (status, updated_at);

CREATE INDEX idx_conversations_user_updated
  ON conversations (user_id, updated_at);

CREATE INDEX idx_audit_logs_created
  ON audit_logs (created_at);
CREATE INDEX idx_audit_logs_actor_created
  ON audit_logs (actor_id, created_at);
