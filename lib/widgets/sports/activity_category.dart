import 'package:flutter/material.dart';
import 'package:move_young/widgets/sports/activity_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/core/activity.dart';

class ActivityCategoryPage extends StatefulWidget {
  const ActivityCategoryPage({
    super.key,
    required this.activities,
    required this.onTapActivity,
  });

  final List<Activity> activities;
  final void Function(String key) onTapActivity;

  @override
  State<ActivityCategoryPage> createState() => _ActivityCategoryPageState();
}

class _ActivityCategoryPageState extends State<ActivityCategoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // ⚠️ required!.

    return ListView.builder(
      padding: EdgeInsets.zero,
      cacheExtent: 400,
      itemCount: widget.activities.length,
      itemBuilder: (context, index) {
        final a = widget.activities[index];

        return ActivityCard(
          title: a.key.tr(), // localize by key
          imageUrl: a.image,
          calories: 'calories_per_hour'.tr(args: ['${a.kcalPerHour}']),
          imageAlignment: a.align ?? Alignment.center,
          onTap: () => widget.onTapActivity(a.key),
        );
      },
    );
  }
}
