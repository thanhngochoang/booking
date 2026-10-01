import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// The blue → violet → magenta of the logo; white text passes AA on every stop.
const ctaGradient = LinearGradient(
  colors: [AppColors.ctaStart, AppColors.ctaMid, AppColors.ctaEnd],
);

/// On the light canvas the main action stays in one hue (violet 500 → 600),
/// so it doesn't compete with the pastel aurora. Both ends keep white text >= 5.5:1.
const ctaGradientLight = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.ctaLightStart, AppColors.ctaLightEnd],
);

LinearGradient ctaGradientFor(Brightness brightness) =>
    brightness == Brightness.dark ? ctaGradient : ctaGradientLight;

/// The viewer's avatar when they chose "avatar" as the main-button style;
/// null means the plain theme gradient. Set once above the router.
class CtaAvatarScope extends InheritedWidget {
  const CtaAvatarScope({super.key, required this.avatar, required super.child});

  final ImageProvider? avatar;

  static ImageProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CtaAvatarScope>()?.avatar;

  @override
  bool updateShouldNotify(CtaAvatarScope old) => avatar != old.avatar;
}

/// Fill behind a main action: the theme gradient, or the blurred avatar
/// tinted with that gradient.
///
/// The avatar is lifted into the 55-100% brightness range, then multiplied by
/// the gradient. A multiply can only darken, so the result is never lighter
/// than the gradient itself and white text keeps the gradient's contrast
/// whatever the photo looks like. While the photo loads or fails, the
/// gradient underneath shows.
class CtaSurface extends StatelessWidget {
  const CtaSurface({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final BorderRadius borderRadius;

  // out = 0.55 + 0.45 * in, per channel.
  static const _lift = ColorFilter.matrix(<double>[
    0.45, 0, 0, 0, 140.25, //
    0, 0.45, 0, 0, 140.25,
    0, 0, 0.45, 0, 140.25,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final gradient = ctaGradientFor(Theme.of(context).brightness);
    final avatar = CtaAvatarScope.of(context);
    final base = DecoratedBox(
      decoration: BoxDecoration(gradient: gradient, borderRadius: borderRadius),
      child: avatar == null ? child : null,
    );
    if (avatar == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius,
        ),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(child: base),
          Positioned.fill(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: ShaderMask(
                  blendMode: BlendMode.modulate,
                  shaderCallback: gradient.createShader,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 12,
                      sigmaY: 12,
                      tileMode: TileMode.mirror,
                    ),
                    child: ColorFiltered(
                      colorFilter: _lift,
                      child: Image(
                        image: avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
