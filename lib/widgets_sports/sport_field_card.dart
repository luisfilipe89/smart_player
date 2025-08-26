// lib/widgets/sport_field_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/tokens.dart';

class SportFieldCard extends StatelessWidget {
  final Map<String, dynamic> field;
  final bool isFavorite;
  final String distanceText;
  final Future<String> Function(Map<String, dynamic>) getDisplayName;
  final Widget characteristics;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShare;
  final VoidCallback onDirections;

  const SportFieldCard({
    super.key,
    required this.field,
    required this.isFavorite,
    required this.distanceText,
    required this.getDisplayName,
    required this.characteristics,
    required this.onToggleFavorite,
    required this.onShare,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = field['tags']?['image'] as String?;
    final imgH = AppHeights.cardImage(context);

    return Container(
      margin: AppPaddings.topBottom,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.md,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: AppPaddings.allReg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Image ----------
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.image),
                child: _ImageWithShimmer(
                  imageUrl: imageUrl,
                  height: imgH,
                ),
              ),

              const SizedBox(height: 8),

              // ---------- Title ----------
              FutureBuilder<String>(
                future: getDisplayName(field),
                builder: (context, snapshot) {
                  final title = snapshot.hasData &&
                          (snapshot.data ?? '').trim().isNotEmpty
                      ? snapshot.data!
                      : 'unnamed_field'.tr();

                  return Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle,
                  );
                },
              ),

              const SizedBox(height: 4),

              // ---------- Distance ----------
              Text(
                distanceText,
                style: TextStyle(color: AppColors.blackopac),
              ),

              const SizedBox(height: 8),

              // ---------- Characteristics ----------
              characteristics,

              const SizedBox(height: 6),

              // ---------- Actions ----------
              Center(
                child: Padding(
                  padding: AppPaddings.topSuperSmall,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Semantics(
                        button: true,
                        label: isFavorite
                            ? 'remove_from_favorites'.tr()
                            : 'add_to_favorites'.tr(),
                        child: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? AppColors.red
                                : AppColors.blackIcon,
                            size: 24,
                          ),
                          tooltip: 'favorite'.tr(),
                          onPressed: onToggleFavorite,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'share_location'.tr(),
                        child: IconButton(
                          icon: const Icon(Icons.share, size: 24),
                          tooltip: 'share_location'.tr(),
                          onPressed: onShare,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'directions'.tr(),
                        child: IconButton(
                          icon: const Icon(Icons.directions, size: 24),
                          tooltip: 'directions'.tr(),
                          onPressed: onDirections,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageWithShimmer extends StatelessWidget {
  const _ImageWithShimmer({required this.imageUrl, required this.height});
  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {

    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: Container(
          color: AppColors.superlightgrey,
          child: const Center(child: Icon(Icons.image_not_supported)),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (context, url) => _shimmerBox(),
        errorWidget: (context, url, error) => Container(
          color: AppColors.lightgrey,
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      ),
    );
  }

  Widget _shimmerBox() {
    return Shimmer.fromColors(
      baseColor: AppColors.lightgrey,
      highlightColor: AppColors.superlightgrey,
      child: Container(color: AppColors.lightgrey),
    );
  }
}
