import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite persistence (plan referenced Isar; same logical schema).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'xoqs.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE IF NOT EXISTS songs (
  id TEXT PRIMARY KEY,
  youtube_id TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT NOT NULL DEFAULT '',
  thumbnail_url TEXT,
  duration_sec INTEGER NOT NULL DEFAULT 0,
  local_path TEXT,
  is_liked INTEGER NOT NULL DEFAULT 0,
  is_downloaded INTEGER NOT NULL DEFAULT 0,
  last_played_ms INTEGER,
  updated_at_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_songs_youtube ON songs(youtube_id);
CREATE INDEX IF NOT EXISTS idx_songs_liked ON songs(is_liked);

CREATE TABLE IF NOT EXISTS playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  cover_url TEXT,
  track_ids TEXT NOT NULL,
  is_spotify_import INTEGER NOT NULL DEFAULT 0,
  spotify_id TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS artists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  image_url TEXT,
  is_followed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS albums (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist_name TEXT NOT NULL,
  cover_url TEXT,
  year INTEGER,
  track_ids TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS play_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id TEXT NOT NULL,
  played_at_ms INTEGER NOT NULL,
  listen_sec INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_history_played ON play_history(played_at_ms DESC);

CREATE TABLE IF NOT EXISTS download_jobs (
  job_id TEXT PRIMARY KEY,
  song_id TEXT NOT NULL,
  status INTEGER NOT NULL,
  progress REAL NOT NULL,
  quality_kbps INTEGER NOT NULL,
  target_path TEXT NOT NULL,
  error_message TEXT,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS stream_url_cache (
  youtube_id TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  quality_label TEXT
);

CREATE TABLE IF NOT EXISTS search_cache (
  query_key TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  cached_at_ms INTEGER NOT NULL,
  ttl_sec INTEGER NOT NULL
);
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Tablolar zaten IF NOT EXISTS ile oluşturulduğu için
        // yeni versiyonlarda da güvenli şekilde çalışır.
        // Gerekirse buraya migration kodları eklenebilir.
        if (oldVersion < 1) {
          // onCreate zaten çalışmış olacak, bu blok sadece güvenlik için
          await db.execute('PRAGMA foreign_keys = ON');
        }
      },
    );
    return _db!;
  }

  static String encodeTrackIds(List<String> ids) => jsonEncode(ids);

  static List<String> decodeTrackIds(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<String>();
  }
}
