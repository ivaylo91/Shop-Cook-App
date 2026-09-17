import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/design.dart';

/// A recipe's picture, or a quiet placeholder when there is none or it fails
/// to load.
///
/// Shared by the meal screen and the library so a recipe looks the same
/// wherever it appears.
class RecipeThumbnail extends StatelessWidget {
  final String url;
  final bool isVideo;
  final double width;
  final double height;

  const RecipeThumbnail({
    super.key,
    required this.url,
    required this.isVideo,
    this.width = 96,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final fallback = Container(
      width: width,
      height: height,
      color: palette.sunken,
      // FaIcon has no box of its own; without this it sits in the corner.
      alignment: Alignment.center,
      child: FaIcon(
        isVideo ? FontAwesomeIcons.play : FontAwesomeIcons.fileLines,
        size: 18,
        color: palette.inkFaint,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.chip),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
