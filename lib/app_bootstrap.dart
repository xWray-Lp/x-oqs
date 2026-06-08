import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:x_oqs/app.dart';
import 'package:x_oqs/core/audio/audio_handler.dart';
import 'package:x_oqs/core/providers.dart';
import 'package:x_oqs/core/theme/obsidian_colors.dart';
import 'package:x_oqs/services/cache_service.dart';
import 'package:x_oqs/services/sponsor_block_service.dart';
import 'package:x_oqs/services/youtube_music_service.dart';

/// İlk frame'i hemen çizer; veritabanı ve AudioService arka planda açılır.
/// Native splash sonrası siyah ekranı önler (runApp öncesi uzun await yok).
class XoqsBootstrapApp extends StatefulWidget {
  const XoqsBootstrapApp({super.key});

  @override
  State<XoqsBootstrapApp> createState() => _XoqsBootstrapAppState();
}

class _XoqsBootstrapAppState extends State<XoqsBootstrapApp> {
  static const _initTimeout = Duration(seconds: 45);

  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_runInit);
  }

  Future<void> _runInit() async {
    try {
      await _initCore().timeout(_initTimeout);
    } on TimeoutException catch (e, st) {
      developer.log('X-oqS init timeout', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    } catch (e, st) {
      developer.log('X-oqS init failed', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _initCore() async {
    // AudioSession: hata devam etse bile ilerle
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e, st) {
      developer.log('AudioSession configure failed (continuing)', error: e, stackTrace: st);
    }

    // Cache ve servisleri hazırla
    final cache = await CacheService.open();
    final yt = YoutubeMusicService(cache);
    final sponsor = SponsorBlockService();

    // AudioService başlatımı - hata durumunda fallback ile devam et
    XoqsAudioHandler? xoqsHandler;
    try {
      await AudioService.init(
        builder: () {
          xoqsHandler = XoqsAudioHandler(
            youtube: yt,
            cache: cache,
            sponsorBlock: sponsor,
          );
          return xoqsHandler!;
        },
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.xoqs.audio',
          androidNotificationChannelName: 'X-oqS',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (e, st) {
      developer.log('AudioService init failed (continuing without background audio)', error: e, stackTrace: st);
      // Fallback: handler'ı manuel oluştur ama AudioService olmadan
      xoqsHandler = XoqsAudioHandler(
        youtube: yt,
        cache: cache,
        sponsorBlock: sponsor,
      );
    }

    if (!mounted) return;
    runApp(
      ProviderScope(
        overrides: [
          cacheProvider.overrideWith((ref) => cache),
          youtubeProvider.overrideWith((ref) => yt),
          audioHandlerProvider.overrideWith((ref) => xoqsHandler!),
        ],
        child: const XoqsApp(),
      ),
    );
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _runInit();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ObsidianColors.background,
        ),
        home: Scaffold(
          backgroundColor: ObsidianColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'X-oqS',
                    style: TextStyle(
                      color: ObsidianColors.primaryText,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Başlatma sırasında bir sorun oluştu.',
                    style: TextStyle(
                      color: ObsidianColors.secondaryText,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _error.toString(),
                        style: const TextStyle(
                          color: ObsidianColors.secondaryText,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _retry,
                    style: FilledButton.styleFrom(
                      backgroundColor: ObsidianColors.primary,
                      foregroundColor: ObsidianColors.onPrimary,
                    ),
                    child: Text(_loading ? 'Deneniyor…' : 'Yeniden dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ObsidianColors.background,
      ),
      home: Scaffold(
        backgroundColor: ObsidianColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: ObsidianColors.primary,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'X-oqS',
                style: TextStyle(
                  color: ObsidianColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hazırlanıyor…',
                style: TextStyle(
                  color: ObsidianColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
