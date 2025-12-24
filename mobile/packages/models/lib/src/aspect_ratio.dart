// ABOUTME: Aspect ratio options for video recording
// ABOUTME: Used to configure camera preview and pro_video_editor crop filters

/// Aspect ratio options for video recording
enum AspectRatio {
  /// 1:1 (classic Vine)
  square,

  /// 9:16 (default, modern vertical video)
  vertical
  ;

  double get value {
    switch (this) {
      case .square:
        return 1;
      case .vertical:
        return 9 / 16;
    }
  }
}
