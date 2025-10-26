import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/friends/friends_provider.dart';

/// Friend picker widget for selecting friends to invite to a game
class FriendPicker extends ConsumerWidget {
  final String currentUid;
  final Set<String> initiallySelected;
  final Set<String> lockedUids;
  final void Function(String uid, bool selected) onToggle;

  const FriendPicker({
    super.key,
    required this.currentUid,
    required this.initiallySelected,
    required this.lockedUids,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.container),
        boxShadow: AppShadows.md,
      ),
      child: ref.watch(watchFriendsListProvider).when(
            data: (friendUids) {
              if (friendUids.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('no_friends_to_invite'.tr(),
                      style:
                          AppTextStyles.small.copyWith(color: AppColors.grey)),
                );
              }
              // Fetch all profiles upfront to avoid FutureBuilder in ListView
              return FutureBuilder<Map<String, Map<String, String?>>>(
                future: Future.wait(friendUids.map((id) => ref
                    .read(friendsActionsProvider)
                    .fetchMinimalProfile(id))).then((profiles) {
                  final map = <String, Map<String, String?>>{};
                  for (int i = 0;
                      i < friendUids.length && i < profiles.length;
                      i++) {
                    map[friendUids[i]] = profiles[i];
                  }
                  return map;
                }),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snap.hasData || snap.data == null) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('no_friends_to_invite'.tr(),
                          style: AppTextStyles.small
                              .copyWith(color: AppColors.grey)),
                    );
                  }
                  final profiles = snap.data!;

                  return ListView.separated(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: friendUids.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.lightgrey),
                    itemBuilder: (context, i) {
                      final uid = friendUids[i];
                      final data = profiles[uid] ??
                          const {'displayName': 'User', 'photoURL': null};
                      final name = data['displayName'] ?? 'User';
                      final photo = data['photoURL'];
                      final selected = initiallySelected.contains(uid);
                      final locked = lockedUids.contains(uid);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.superlightgrey,
                          backgroundImage: (photo != null && photo.isNotEmpty)
                              ? CachedNetworkImageProvider(photo)
                              : null,
                          child: (photo == null || photo.isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?')
                              : null,
                        ),
                        title: Text(name,
                            style: AppTextStyles.body.copyWith(
                                color: locked ? AppColors.grey : null)),
                        trailing: Checkbox(
                          value: selected || locked,
                          onChanged:
                              locked ? null : (v) => onToggle(uid, v == true),
                        ),
                        onTap: locked ? null : () => onToggle(uid, !selected),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('no_friends_to_invite'.tr(),
                  style: AppTextStyles.small.copyWith(color: AppColors.grey)),
            ),
          ),
    );
  }
}
