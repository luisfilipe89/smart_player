import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:move_young/widgets/tab_with_count.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/features/activities/services/local_fields_service.dart';
import 'package:move_young/services/system/location_provider.dart';
import 'package:move_young/utils/geolocation_utils.dart';
import 'package:move_young/utils/navigation_utils.dart';
import 'package:move_young/features/maps/screens/gmaps_screen.dart';

class FitnessItem {
  final String id;
  final String title;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final List<String>? imageUrls;
  final double? distanceMeters;
  final String? name;

  FitnessItem({
    required this.id,
    required this.title,
    this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.imageUrls,
    this.distanceMeters,
    this.name,
  });

  List<String> get allImages {
    if (imageUrls != null && imageUrls!.isNotEmpty) {
      return imageUrls!;
    }
    if (imageUrl != null) {
      return [imageUrl!];
    }
    return [];
  }
}

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final LocalFieldsService _fieldsService = const LocalFieldsService();

  List<FitnessItem> _fitnessStations = [];
  List<FitnessItem> _sportContainers = [];
  bool _isLoading = true;
  bool _isCalculatingDistances = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadFitnessData();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
      // Precache images when sport containers tab is accessed
      _precacheSportContainerImages();
    }
  }

  Future<void> _precacheSportContainerImages() async {
    if (_sportContainers.isEmpty) return;

    // Precache first image of each container for faster initial load
    for (final container in _sportContainers.take(3)) {
      final images = container.allImages;
      if (images.isNotEmpty && !images[0].startsWith('http')) {
        try {
          await precacheImage(
            AssetImage(images[0]),
            context,
          );
        } catch (e) {
          // Ignore precache errors
        }
      }
    }
  }

  Future<void> _loadFitnessData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load fitness stations
      final fitnessFields =
          await _fieldsService.loadFields(sportType: 'fitness');
      NumberedLogger.d('Loaded ${fitnessFields?.length ?? 0} fitness fields');

      // Load sport containers
      final containerFields =
          await _fieldsService.loadFields(sportType: 'sport_container');
      NumberedLogger.d(
          'Loaded ${containerFields?.length ?? 0} sport container fields');

      // Process fitness stations
      _fitnessStations = [];
      if (fitnessFields != null && fitnessFields.isNotEmpty) {
        _fitnessStations = fitnessFields.map((field) {
          // Title: micro address (street name only)
          final title = field['address_micro_short']?.toString() ??
              field['address_super_short']?.toString() ??
              'Unnamed Fitness Station';

          // Subtitle: super short address (street name with postal code)
          final subtitle = field['address_super_short']?.toString() ??
              field['address_short']?.toString();

          return FitnessItem(
            id: field['id']?.toString() ?? '',
            title: title,
            address: subtitle,
            latitude: field['lat'] as double?,
            longitude: field['lon'] as double?,
            name: field['name']?.toString(),
          );
        }).where((item) {
          // Filter to only include fitness_station leisure type
          final index =
              fitnessFields.indexWhere((f) => f['id']?.toString() == item.id);
          if (index >= 0) {
            final tags = fitnessFields[index]['tags'] as Map<String, dynamic>?;
            final leisure = tags?['leisure']?.toString();
            return leisure == 'fitness_station';
          }
          return false;
        }).toList();
      }

      // Process sport containers
      _sportContainers = [];
      if (containerFields != null && containerFields.isNotEmpty) {
        _sportContainers = containerFields.map((field) {
          // Title: micro address (street name only)
          final title = field['address_micro_short']?.toString() ??
              field['address_super_short']?.toString() ??
              'Unnamed Sport Container';

          // Subtitle: super short address (street name with postal code)
          final subtitle = field['address_super_short']?.toString() ??
              field['address_short']?.toString();

          // Get images array
          final images = field['images'] as List<dynamic>?;
          final imageUrls = images
              ?.map((e) => e?.toString())
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList();

          NumberedLogger.d(
              'Sport container ${field['id']} has ${imageUrls?.length ?? 0} images: $imageUrls');

          return FitnessItem(
            id: field['id']?.toString() ?? '',
            title: title,
            address: subtitle,
            latitude: field['lat'] as double?,
            longitude: field['lon'] as double?,
            imageUrls: imageUrls?.isNotEmpty == true ? imageUrls : null,
            name: field['name']?.toString(),
          );
        }).toList();
      }

      NumberedLogger.d(
          'Categorized: ${_fitnessStations.length} stations, ${_sportContainers.length} containers');

      // Show items immediately (in random order as loaded)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Now calculate distances and sort
      await _updateDistancesAndSort();
    } catch (e, stackTrace) {
      NumberedLogger.e('Error loading fitness data: $e');
      NumberedLogger.e('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCalculatingDistances = false;
        });
      }
    }
  }

  Future<void> _updateDistancesAndSort() async {
    if (mounted) {
      setState(() {
        _isCalculatingDistances = true;
      });
    }

    try {
      final locationActions = ref.read(locationActionsProvider);
      final userPosition = await locationActions.getCurrentPosition();

      // Update fitness stations with distances
      final fitnessStationsWithDistances = await Future.wait(
        _fitnessStations.map((item) async {
          if (item.latitude == null || item.longitude == null) {
            return item;
          }

          final distance = calculateDistanceMeters(
            startLat: userPosition.latitude,
            startLon: userPosition.longitude,
            endLat: item.latitude!,
            endLon: item.longitude!,
          );

          return FitnessItem(
            id: item.id,
            title: item.title,
            address: item.address,
            latitude: item.latitude,
            longitude: item.longitude,
            imageUrl: item.imageUrl,
            imageUrls: item.imageUrls,
            distanceMeters: distance,
            name: item.name,
          );
        }),
      );

      // Sort by distance
      fitnessStationsWithDistances.sort((a, b) {
        final distA = a.distanceMeters ?? double.infinity;
        final distB = b.distanceMeters ?? double.infinity;
        return distA.compareTo(distB);
      });

      // Update sport containers with distances
      final sportContainersWithDistances = await Future.wait(
        _sportContainers.map((item) async {
          if (item.latitude == null || item.longitude == null) {
            return item;
          }

          final distance = calculateDistanceMeters(
            startLat: userPosition.latitude,
            startLon: userPosition.longitude,
            endLat: item.latitude!,
            endLon: item.longitude!,
          );

          return FitnessItem(
            id: item.id,
            title: item.title,
            address: item.address,
            latitude: item.latitude,
            longitude: item.longitude,
            imageUrl: item.imageUrl,
            imageUrls: item.imageUrls,
            distanceMeters: distance,
            name: item.name,
          );
        }),
      );

      // Sort by distance
      sportContainersWithDistances.sort((a, b) {
        final distA = a.distanceMeters ?? double.infinity;
        final distB = b.distanceMeters ?? double.infinity;
        return distA.compareTo(distB);
      });

      if (mounted) {
        setState(() {
          _fitnessStations = fitnessStationsWithDistances;
          _sportContainers = sportContainersWithDistances;
          _isCalculatingDistances = false;
        });
      }
    } catch (e) {
      NumberedLogger.e('Failed to calculate distances: $e');
      // If location fails, keep items in original order
      if (mounted) {
        setState(() {
          _isCalculatingDistances = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openDirections(FitnessItem item) async {
    try {
      Uri uri;

      // Prefer coordinates if available for accurate directions
      if (item.latitude != null && item.longitude != null) {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${item.latitude},${item.longitude}&travelmode=walking',
        );
      } else if (item.address != null && item.address!.isNotEmpty) {
        // Fallback: Use address
        final query = Uri.encodeComponent(item.address!);
        uri =
            Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No location information available for directions'),
              backgroundColor: AppColors.orange,
            ),
          );
        }
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      NumberedLogger.e('Error opening directions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('could_not_open_maps'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareLocation(FitnessItem item) async {
    if (item.latitude == null || item.longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No location information available for sharing'),
            backgroundColor: AppColors.orange,
          ),
        );
      }
      return;
    }

    final name = item.name ?? item.title;
    await NavigationUtils.shareLocation(
      name,
      item.latitude!.toString(),
      item.longitude!.toString(),
    );
  }

  Future<void> _openReportSheet(FitnessItem item) async {
    final fieldId = item.id.trim();
    final fallbackId = fieldId.isNotEmpty
        ? fieldId
        : (item.latitude != null && item.longitude != null
            ? 'loc:${item.latitude!.toStringAsFixed(5)}:${item.longitude!.toStringAsFixed(5)}'
            : 'fitness_item:${item.id}');

    final fieldName = (item.name ?? item.title).trim().isNotEmpty
        ? (item.name ?? item.title).trim()
        : 'unnamed_location'.tr();

    final fieldAddress = item.address?.trim();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FieldReportSheet(
        fieldId: fallbackId,
        fieldName: fieldName,
        fieldAddress: fieldAddress,
      ),
    );

    if (!mounted || result != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('field_report_submitted'.tr()),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Widget _buildFitnessCard(FitnessItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppHeights.reg),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.08],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  item.title,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.address != null)
                      Text(
                        item.address!,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    if (item.distanceMeters != null &&
                        item.distanceMeters!.isFinite) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatDistance(item.distanceMeters!),
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Images - support multiple images with carousel
              _buildImageSection(item),
              // Action buttons row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openDirections(item),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          textStyle: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          iconSize: 16,
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.directions, size: 16),
                        label: Text('directions'.tr()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _shareLocation(item),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          textStyle: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          iconSize: 16,
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text('share'.tr()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openReportSheet(item),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          textStyle: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          iconSize: 16,
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon:
                            const Icon(Icons.report_problem_outlined, size: 16),
                        label: Text('report'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(FitnessItem item) {
    final images = item.allImages;

    if (images.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.superlightgrey,
          borderRadius: BorderRadius.circular(AppRadius.smallCard),
        ),
        child: _buildPlaceholderImage(),
      );
    }

    if (images.length == 1) {
      // Single image
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.superlightgrey,
          borderRadius: BorderRadius.circular(AppRadius.smallCard),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.smallCard),
          child: _buildImage(images[0]),
        ),
      );
    }

    // Multiple images - use PageView carousel with indicator
    return _ImageCarousel(images: images);
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: AppColors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Image placeholder',
            style: AppTextStyles.small.copyWith(
              color: AppColors.grey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    // Check if it's a network URL or local asset
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        memCacheHeight: 300,
        placeholder: (context, url) => _buildPlaceholderImage(),
        errorWidget: (context, url, error) => _buildPlaceholderImage(),
      );
    } else {
      // Local asset - optimize with cache dimensions
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        cacheWidth: 800, // Optimize memory usage
        cacheHeight: 600,
        errorBuilder: (context, error, stackTrace) {
          NumberedLogger.e('Error loading asset image: $imagePath - $error');
          return _buildPlaceholderImage();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(goHome: true),
        title: Text('fitness'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.primary,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          tabs: [
            TabWithCount(
              label: 'fitness_stations'.tr(),
              count: _fitnessStations.length,
            ),
            TabWithCount(
              label: 'sport_containers'.tr(),
              count: _sportContainers.length,
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: AppPaddings.symmHorizontalReg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Show subtle loading indicator when calculating distances
                    if (_isCalculatingDistances)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'finding_closest_fields'.tr(),
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.container),
                          boxShadow: AppShadows.md,
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.container),
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Fitness Stations tab
                              RefreshIndicator(
                                onRefresh: _loadFitnessData,
                                child: _fitnessStations.isEmpty
                                    ? ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.only(
                                            bottom: AppHeights.reg),
                                        children: [
                                          Padding(
                                            padding: AppPaddings.allSuperBig,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.fitness_center,
                                                    size: 64,
                                                    color: AppColors.grey),
                                                const SizedBox(
                                                    height: AppHeights.reg),
                                                Text(
                                                  'no_fitness_stations'.tr(),
                                                  style: AppTextStyles.title
                                                      .copyWith(
                                                          color:
                                                              AppColors.grey),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: AppPaddings.allMedium.add(
                                          const EdgeInsets.only(
                                              bottom: AppHeights.reg),
                                        ),
                                        itemCount: _fitnessStations.length,
                                        itemBuilder: (_, i) =>
                                            _buildFitnessCard(
                                                _fitnessStations[i]),
                                      ),
                              ),
                              // Sport Containers tab
                              RefreshIndicator(
                                onRefresh: _loadFitnessData,
                                child: _sportContainers.isEmpty
                                    ? ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.only(
                                            bottom: AppHeights.reg),
                                        children: [
                                          Padding(
                                            padding: AppPaddings.allSuperBig,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                    Icons.sports_basketball,
                                                    size: 64,
                                                    color: AppColors.grey),
                                                const SizedBox(
                                                    height: AppHeights.reg),
                                                Text(
                                                  'no_sport_containers'.tr(),
                                                  style: AppTextStyles.title
                                                      .copyWith(
                                                          color:
                                                              AppColors.grey),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: AppPaddings.allMedium.add(
                                          const EdgeInsets.only(
                                              bottom: AppHeights.reg),
                                        ),
                                        itemCount: _sportContainers.length,
                                        itemBuilder: (_, i) =>
                                            _buildFitnessCard(
                                                _sportContainers[i]),
                                      ),
                              ),
                            ],
                          ),
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

class _ImageCarousel extends StatefulWidget {
  final List<String> images;

  const _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    NumberedLogger.d(
        'ImageCarousel initialized with ${widget.images.length} images: ${widget.images}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 180,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              // Precache next and previous images for smooth scrolling
              if (index + 1 < widget.images.length &&
                  !widget.images[index + 1].startsWith('http')) {
                precacheImage(AssetImage(widget.images[index + 1]), context);
              }
              if (index > 0 && !widget.images[index - 1].startsWith('http')) {
                precacheImage(AssetImage(widget.images[index - 1]), context);
              }
            },
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.smallCard),
                child: _buildImage(widget.images[index]),
              );
            },
          ),
          // Page indicator
          if (widget.images.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? AppColors.white
                          : AppColors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    // Check if it's a network URL or local asset
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        memCacheHeight: 300,
        placeholder: (context, url) => _buildPlaceholderImage(),
        errorWidget: (context, url, error) => _buildPlaceholderImage(),
      );
    } else {
      // Local asset - optimize with cache dimensions
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        cacheWidth: 800, // Optimize memory usage
        cacheHeight: 600,
        errorBuilder: (context, error, stackTrace) {
          NumberedLogger.e('Error loading asset image: $imagePath - $error');
          return _buildPlaceholderImage();
        },
      );
    }
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: AppColors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Image placeholder',
            style: AppTextStyles.small.copyWith(
              color: AppColors.grey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
