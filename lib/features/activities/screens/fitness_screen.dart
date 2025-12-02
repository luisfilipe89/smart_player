import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:move_young/widgets/tab_with_count.dart';
import 'package:move_young/widgets/app_back_button.dart';

// Simple model for fitness items
class FitnessItem {
  final String id;
  final String title;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;

  FitnessItem({
    required this.id,
    required this.title,
    this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
  });
}

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Placeholder data - replace with actual data source later
  final List<FitnessItem> _fitnessStations = [
    FitnessItem(
      id: '1',
      title: 'Fitness Station 1',
      address: 'Sample Address 1',
      latitude: 51.6978,
      longitude: 5.3037,
    ),
    FitnessItem(
      id: '2',
      title: 'Fitness Station 2',
      address: 'Sample Address 2',
      latitude: 51.6980,
      longitude: 5.3040,
    ),
  ];

  final List<FitnessItem> _sportContainers = [
    FitnessItem(
      id: '3',
      title: 'Sport Container 1',
      address: 'Sample Address 3',
      latitude: 51.6975,
      longitude: 5.3035,
    ),
    FitnessItem(
      id: '4',
      title: 'Sport Container 2',
      address: 'Sample Address 4',
      latitude: 51.6977,
      longitude: 5.3038,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
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
      debugPrint('Error opening directions: $e');
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
                subtitle: item.address != null
                    ? Text(
                        item.address!,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.grey,
                        ),
                      )
                    : null,
              ),
              // Image placeholder
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.superlightgrey,
                  borderRadius: BorderRadius.circular(AppRadius.smallCard),
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppRadius.smallCard),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage();
                          },
                        ),
                      )
                    : _buildPlaceholderImage(),
              ),
              // Directions button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
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
              ),
            ],
          ),
        ),
      ),
    );
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
        child: Padding(
          padding: AppPaddings.symmHorizontalReg,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.container),
              boxShadow: AppShadows.md,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.container),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Fitness Stations tab
                  RefreshIndicator(
                    onRefresh: () async {
                      // Refresh logic here
                    },
                    child: _fitnessStations.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.only(bottom: AppHeights.reg),
                            children: [
                              Padding(
                                padding: AppPaddings.allSuperBig,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.fitness_center,
                                        size: 64, color: AppColors.grey),
                                    const SizedBox(height: AppHeights.reg),
                                    Text(
                                      'no_fitness_stations'.tr(),
                                      style: AppTextStyles.title
                                          .copyWith(color: AppColors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppPaddings.allMedium.add(
                              const EdgeInsets.only(bottom: AppHeights.reg),
                            ),
                            itemCount: _fitnessStations.length,
                            itemBuilder: (_, i) =>
                                _buildFitnessCard(_fitnessStations[i]),
                          ),
                  ),
                  // Sport Containers tab
                  RefreshIndicator(
                    onRefresh: () async {
                      // Refresh logic here
                    },
                    child: _sportContainers.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.only(bottom: AppHeights.reg),
                            children: [
                              Padding(
                                padding: AppPaddings.allSuperBig,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.sports_basketball,
                                        size: 64, color: AppColors.grey),
                                    const SizedBox(height: AppHeights.reg),
                                    Text(
                                      'no_sport_containers'.tr(),
                                      style: AppTextStyles.title
                                          .copyWith(color: AppColors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppPaddings.allMedium.add(
                              const EdgeInsets.only(bottom: AppHeights.reg),
                            ),
                            itemCount: _sportContainers.length,
                            itemBuilder: (_, i) =>
                                _buildFitnessCard(_sportContainers[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
