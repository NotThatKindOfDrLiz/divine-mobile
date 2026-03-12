// ABOUTME: Web-native video player entry point with conditional imports
// ABOUTME: Routes to HtmlElementView impl on web, stub on native/VM

export 'web_video_player_stub.dart'
    if (dart.library.js_interop) 'web_video_player_web.dart';
