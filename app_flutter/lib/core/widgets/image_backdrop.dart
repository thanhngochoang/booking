// lib/core/widgets/image_backdrop.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:photobooking/core/widgets/aurora_background.dart';

/// The lead photo of an intro page (S03 cover, later S16 and S28), blurred
/// behind the content (spec §1.2): scaled 1.3×, blur σ[sigma], saturation
/// 130 %, [opacity] over the aurora, fading into the page over the top
/// [height] of the box.
///
/// Cheap by construction: the photo is decoded at a quarter of the box
/// width (the blur removes the detail anyway), the blur is an
/// `ImageFiltered` on that one image, not a `BackdropFilter`, and it sits in
/// its own `RepaintBoundary` behind the content, so scrolling never repaints
/// or re-blurs it. With high contrast on only the aurora shows. Decorative,
/// so it is excluded from semantics.
class ImageBackdrop extends StatelessWidget {
  const ImageBackdrop({
    super.key,
    required this.image,
    this.height = 0.62,
    this.sigma = 24,
    this.opacity = 0.5,
    this.child,
  });

  final ImageProvider image;

  /// Share of the box height the photo covers before it has faded out.
  final double height;
  final double sigma;
  final double opacity;
  final Widget? child;

  /// Saturation 130 % (Rec. 709 luma weights) with the alpha scaled by
  /// [opacity], in one colour matrix (no extra layer for the opacity).
  static ColorFilter _filter(double opacity) => ColorFilter.matrix(<double>[
    1.23622, -0.21456, -0.02166, 0, 0, //
    -0.06378, 1.08544, -0.02166, 0, 0,
    -0.06378, -0.21456, 1.27834, 0, 0,
    0, 0, 0, opacity, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final plain = MediaQuery.highContrastOf(context);
    return AuroraBackground(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!plain)
            LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final h = box.maxHeight * height;
                final decodeWidth =
                    (w * MediaQuery.devicePixelRatioOf(context) / 4)
                        .ceil()
                        .clamp(32, 512)
                        .toInt();
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        key: const Key('image-backdrop-layer'),
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white, Colors.transparent],
                            stops: [0.5, 1],
                          ).createShader(rect),
                          child: ClipRect(
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: sigma,
                                sigmaY: sigma,
                                tileMode: TileMode.decal,
                              ),
                              child: ColorFiltered(
                                colorFilter: _filter(opacity),
                                child: Transform.scale(
                                  scale: 1.3,
                                  child: Image(
                                    image: ResizeImage.resizeIfNeeded(
                                      decodeWidth,
                                      null,
                                      image,
                                    ),
                                    width: w,
                                    height: h,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ?child,
        ],
      ),
    );
  }
}
