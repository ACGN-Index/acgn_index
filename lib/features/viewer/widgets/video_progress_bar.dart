import 'package:flutter/material.dart';

/// 瑙嗛杩涘害鏉★細搴曡建銆佺紦瀛樺尯闂淬€佸凡鎾尯闂翠笌婊戝潡銆?
///
/// 涓嶇敤 Material `Slider` 鏄洜涓哄畠鏃犳硶缁樺埗缂撳瓨鍖洪棿锛屼笖鑷甫杈冨ぇ鐨勫乏鍙冲唴缂╋紱
/// 杩欓噷璁╄建閬撳湪鎵ｉ櫎婊戝潡鍗婂緞鍚庨摵婊℃暣涓搴︼紝鐐瑰嚮涓庢嫋鍔ㄩ兘浼氬洖璋冩瘮渚嬶紙0~1锛夈€?
class VideoProgressBar extends StatefulWidget {
  const VideoProgressBar({
    required this.value,
    required this.buffered,
    required this.enabled,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.height = 18,
    super.key,
  });

  /// 宸叉挱姣斾緥 0~1銆?
  final double value;

  /// 缂撳瓨姣斾緥 0~1銆?
  final double buffered;

  final bool enabled;

  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  final double height;

  static const double _thumbRadius = 6;
  static const double _trackHeight = 3;

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  double _lastFraction = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double fractionAt(Offset local) {
          final usable = width - VideoProgressBar._thumbRadius * 2;
          if (usable <= 0) {
            return 0;
          }
          return ((local.dx - VideoProgressBar._thumbRadius) / usable).clamp(0.0, 1.0);
        }

        void update(Offset local) {
          _lastFraction = fractionAt(local);
          widget.onChanged?.call(_lastFraction);
        }

        return Semantics(
          slider: true,
          value: '${(widget.value * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.enabled
                ? (details) {
                    _lastFraction = fractionAt(details.localPosition);
                    widget.onChangeStart?.call(_lastFraction);
                    widget.onChanged?.call(_lastFraction);
                    widget.onChangeEnd?.call(_lastFraction);
                  }
                : null,
            onHorizontalDragStart: widget.enabled
                ? (details) {
                    _lastFraction = fractionAt(details.localPosition);
                    widget.onChangeStart?.call(_lastFraction);
                    update(details.localPosition);
                  }
                : null,
            onHorizontalDragUpdate: widget.enabled
                ? (details) => update(details.localPosition)
                : null,
            onHorizontalDragEnd: widget.enabled
                ? (details) => widget.onChangeEnd?.call(_lastFraction)
                : null,
            child: SizedBox(
              height: widget.height,
              child: CustomPaint(
                painter: VideoProgressPainter(
                  value: widget.value.clamp(0.0, 1.0),
                  buffered: widget.buffered.clamp(0.0, 1.0),
                  thumbRadius: VideoProgressBar._thumbRadius,
                  trackHeight: VideoProgressBar._trackHeight,
                ),
                size: Size(width, widget.height),
              ),
            ),
          ),
        );
      },
    );
  }
}

class VideoProgressPainter extends CustomPainter {
  const VideoProgressPainter({
    required this.value,
    required this.buffered,
    required this.thumbRadius,
    required this.trackHeight,
  });

  final double value;
  final double buffered;
  final double thumbRadius;
  final double trackHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final left = thumbRadius;
    final usable = size.width - thumbRadius * 2;
    if (usable <= 0) {
      return;
    }
    final centerY = size.height / 2;
    final radius = Radius.circular(trackHeight / 2);

    void drawRange(double from, double to, Color color) {
      if (to <= from) {
        return;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left + usable * from,
            centerY - trackHeight / 2,
            usable * (to - from),
            trackHeight,
          ),
          radius,
        ),
        Paint()..color = color,
      );
    }

    drawRange(0, 1, Colors.white.withValues(alpha: 0.24));
    drawRange(0, buffered, Colors.white.withValues(alpha: 0.42));
    drawRange(0, value, Colors.white);
    canvas.drawCircle(
      Offset(left + usable * value, centerY),
      thumbRadius,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(VideoProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.buffered != buffered ||
      oldDelegate.thumbRadius != thumbRadius ||
      oldDelegate.trackHeight != trackHeight;
}
