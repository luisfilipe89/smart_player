import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/screens/activities/sports_screens/generic_sport_screen.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<String> categories = const [
    'fitness_stations',
    'fitness_circus',
    'sport_containers'
  ];

  // Map each category to sportType (for now all use 'fitness', can be changed later)
  final Map<String, String> categorySportType = const {
    'fitness_stations': 'fitness',
    'fitness_circus': 'fitness',
    'sport_containers': 'fitness',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
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
          tabs: categories.map((category) {
            return Tab(text: category.tr());
          }).toList(),
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
                children: categories.map((categoryKey) {
                  final sportType = categorySportType[categoryKey] ?? 'fitness';
                  return GenericSportScreen(
                    key: PageStorageKey('cat_$categoryKey'),
                    title: categoryKey.tr(),
                    sportType: sportType,
                    showScaffold: false,
                    hideFilters: true,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
