import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/async_view.dart';
import 'package:photobooking/core/widgets/network_photo.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';

class SampleGrid extends ConsumerWidget {
  const SampleGrid({
    super.key,
    required this.samples,
    this.maxThumbnails = 6,
    this.onTapPhoto,
  });

  final List<DeliverySampleRef> samples;
  final int maxThumbnails;
  final ValueChanged<int>? onTapPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (samples.isEmpty) return const SizedBox.shrink();

    final count = samples.length;
    final displayCount = count > maxThumbnails ? maxThumbnails : count;
    final hasOverflow = count > maxThumbnails;
    final overflowCount = count - displayCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 3;
        const spacing = AppSpace.s2;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(displayCount, (index) {
            final sample = samples[index];
            final isLastOverflowTile = hasOverflow && index == displayCount - 1;

            return SizedBox(
              width: itemWidth,
              height: itemWidth,
              child: GestureDetector(
                onTap: () {
                  if (onTapPhoto != null) {
                    onTapPhoto!(index);
                  } else {
                    _openViewer(context, initialIndex: index);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SampleThumb(storagePath: sample.thumbPath),
                      if (isLastOverflowTile)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                          child: Center(
                            child: Text(
                              '+$overflowCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppText.lg,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  void _openViewer(BuildContext context, {required int initialIndex}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryPhotoViewer(
          samples: samples,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _SampleThumb extends ConsumerWidget {
  const _SampleThumb({required this.storagePath});

  final String storagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(deliveryImageUrlProvider(storagePath)).value;
    if (url != null) {
      return NetworkPhoto(url: url, fit: BoxFit.cover, retry: false);
    }
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: AppIcon(AppIcons.image, size: 24),
      ),
    );
  }
}

class DeliveryPhotoViewer extends StatefulWidget {
  const DeliveryPhotoViewer({
    super.key,
    required this.samples,
    required this.initialIndex,
  });

  final List<DeliverySampleRef> samples;
  final int initialIndex;

  @override
  State<DeliveryPhotoViewer> createState() => _DeliveryPhotoViewerState();
}

class _DeliveryPhotoViewerState extends State<DeliveryPhotoViewer> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.samples.length}',
          style: const TextStyle(color: Colors.white, fontSize: AppText.base),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.samples.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final sample = widget.samples[index];
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Consumer(
                builder: (context, ref, _) {
                  final urlAsync = ref.watch(deliveryImageUrlProvider(sample.path));
                  return AsyncView<String>(
                    value: urlAsync,
                    data: (context, url) => NetworkPhoto(url: url, fit: BoxFit.contain),
                    error: (context, _, _) => const Center(
                      child: AppIcon(AppIcons.brokenImage, color: Colors.white54, size: 48),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
