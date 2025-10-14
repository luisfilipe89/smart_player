[1mdiff --git a/lib/screens/games/games_my_screen.dart b/lib/screens/games/games_my_screen.dart[m
[1mindex 76a26c7..533c8a1 100644[m
[1m--- a/lib/screens/games/games_my_screen.dart[m
[1m+++ b/lib/screens/games/games_my_screen.dart[m
[36m@@ -4,6 +4,13 @@[m [mimport 'package:move_young/models/game.dart';[m
 import 'package:move_young/services/auth_service.dart';[m
 import 'package:move_young/services/cloud_games_service.dart';[m
 import 'package:move_young/theme/_theme.dart';[m
[32m+[m[32mimport 'package:move_young/screens/games/games_join_screen.dart';[m
[32m+[m[32mimport 'package:move_young/screens/games/game_organize_screen.dart';[m
[32m+[m[32mimport 'package:url_launcher/url_launcher.dart';[m
[32m+[m[32mimport 'package:share_plus/share_plus.dart';[m
[32m+[m[32mimport 'package:cached_network_image/cached_network_image.dart';[m
[32m+[m[32mimport 'package:move_young/services/friends_service.dart' as friends;[m
[32m+[m[32mimport 'package:move_young/services/weather_service.dart';[m
 [m
 class GamesMyScreen extends StatefulWidget {[m
   final String? highlightGameId;[m
[36m@@ -20,6 +27,7 @@[m [mclass _GamesMyScreenState extends State<GamesMyScreen>[m
   List<Game> _created = [];[m
   final Map<String, GlobalKey> _itemKeys = {};[m
   late final TabController _tab;[m
[32m+[m[32m  final Set<String> _expanded = <String>{};[m
 [m
   @override[m
   void initState() {[m
[36m@@ -28,6 +36,158 @@[m [mclass _GamesMyScreenState extends State<GamesMyScreen>[m
     _load();[m
   }[m
 [m
[32m+[m[32m  // ---- Helpers restored ----[m
[32m+[m[32m  Widget _buildParticipantsStrip(Game game) {[m
[32m+[m[32m    final List<String> uids = game.players;[m
[32m+[m[32m    if (uids.isEmpty) return const SizedBox.shrink();[m
[32m+[m[32m    final List<String> limited = uids.take(12).toList();[m
[32m+[m[32m    return SizedBox([m
[32m+[m[32m      height: 44,[m
[32m+[m[32m      child: FutureBuilder<List<Map<String, String?>>>([m
[32m+[m[32m        future: Future.wait([m
[32m+[m[32m          limited.map((uid) => friends.FriendsService.fetchMinimalProfile(uid)),[m
[32m+[m[32m        ),[m
[32m+[m[32m        builder: (context, snapshot) {[m
[32m+[m[32m          final profiles = snapshot.data ?? const <Map<String, String?>>[];[m
[32m+[m[32m          if (profiles.isEmpty) return const SizedBox.shrink();[m
[32m+[m
[32m+[m[32m          const double radius = 18;[m
[32m+[m[32m          const double diameter = radius * 2;[m
[32m+[m[32m          const double overlap = 6;[m
[32m+[m[32m          const int maxVisible = 8;[m
[32m+[m[32m          final int total = uids.length;[m
[32m+[m[32m          final int visibleCount =[m
[32m+[m[32m              profiles.length > maxVisible ? maxVisible : profiles.length;[m
[32m+[m[32m          final int remaining = total - visibleCount;[m
[32m+[m
[32m+[m[32m          final List<Widget> items = [];[m
[32m+[m[32m          for (int i = 0; i < visibleCount; i++) {[m
[32m+[m[32m            final name = (profiles[i]['displayName'] ?? 'User').trim();[m
[32m+[m[32m            final photo = profiles[i]['photoURL'];[m
[32m+[m[32m            final initials = _initialsFromName(name);[m
[32m+[m[32m            items.add(Positioned([m
[32m+[m[32m              left: i * (diameter - overlap),[m
[32m+[m[32m              top: 0,[m
[32m+[m[32m              child: Container([m
[32m+[m[32m                padding: const EdgeInsets.all(1),[m
[32m+[m[32m                decoration: BoxDecoration([m
[32m+[m[32m                  shape: BoxShape.circle,[m
[32m+[m[32m                  border: const Border.fromBorderSide([m
[32m+[m[32m                      BorderSide(color: AppColors.primary, width: 1)),[m
[32m+[m[32m                ),[m
[32m+[m[32m                child: CircleAvatar([m
[32m+[m[32m                  radius: radius,[m
[32m+[m[32m                  backgroundColor: AppColors.superlightgrey,[m
[32m+[m[32m                  backgroundImage: (photo != null && photo.isNotEmpty)[m
[32m+[m[32m                      ? NetworkImage(photo)[m
[32m+[m[32m                      : null,[m
[32m+[m[32m                  child: (photo == null || photo.isEmpty)[m
[32m+[m[32m                      ? (initials == '?'[m
[32m+[m[32m                          ? const Icon(Icons.person,[m
[32m+[m[32m                              size: 18, color: AppColors.blackopac)[m
[32m+[m[32m                          : Text(initials, style: AppTextStyles.small))[m
[32m+[m[32m                      : null,[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m            ));[m
[32m+[m[32m          }[m
[32m+[m
[32m+[m[32m          if (remaining > 0) {[m
[32m+[m[32m            items.add(Positioned([m
[32m+[m[32m              left: visibleCount * (diameter - overlap),[m
[32m+[m[32m              top: 0,[m
[32m+[m[32m              child: Container([m
[32m+[m[32m                padding: const EdgeInsets.all(1),[m
[32m+[m[32m                decoration: BoxDecoration([m
[32m+[m[32m                  shape: BoxShape.circle,[m
[32m+[m[32m                  border: const Border.fromBorderSide([m
[32m+[m[32m                      BorderSide(color: AppColors.primary, width: 1)),[m
[32m+[m[32m                ),[m
[32m+[m[32m                child: CircleAvatar([m
[32m+[m[32m                  radius: radius,[m
[32m+[m[32m                  backgroundColor: AppColors.white,[m
[32m+[m[32m                  child: Text('+$remaining',[m
[32m+[m[32m                      style: AppTextStyles.small[m
[32m+[m[32m                          .copyWith(color: AppColors.primary)),[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m            ));[m
[32m+[m[32m          }[m
[32m+[m
[32m+[m[32m          final double width =[m
[32m+[m[32m              (visibleCount + (remaining > 0 ? 1 : 0)) * (diameter - overlap) +[m
[32m+[m[32m                  overlap +[m
[32m+[m[32m                  2;[m
[32m+[m
[32m+[m[32m          return SizedBox([m
[32m+[m[32m              width: width, height: diameter, child: Stack(children: items));[m
[32m+[m[32m        },[m
[32m+[m[32m      ),[m
[32m+[m[32m    );[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  String _initialsFromName(String name) {[m
[32m+[m[32m    final parts =[m
[32m+[m[32m        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();[m
[32m+[m[32m    if (parts.isEmpty) return '?';[m
[32m+[m[32m    final first = parts.first[0];[m
[32m+[m[32m    final second = parts.length > 1 ? parts[1][0] : '';[m
[32m+[m[32m    return (first + second).toUpperCase();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  bool _isUserJoined(Game game) {[m
[32m+[m[32m    final uid = AuthService.currentUserId;[m
[32m+[m[32m    if (uid == null || uid.isEmpty) return false;[m
[32m+[m[32m    return game.players.any((p) => p == uid);[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> _leaveGame(Game game) async {[m
[32m+[m[32m    final uid = AuthService.currentUserId;[m
[32m+[m[32m    if (uid == null || uid.isEmpty) return;[m
[32m+[m[32m    final ok = await CloudGamesService.leaveGame(game.id, uid);[m
[32m+[m[32m    if (!mounted) return;[m
[32m+[m[32m    ScaffoldMessenger.of(context).showSnackBar([m
[32m+[m[32m      SnackBar([m
[32m+[m[32m        content: Text(ok ? 'You left the game' : 'Failed to leave'),[m
[32m+[m[32m        backgroundColor: ok ? AppColors.grey : AppColors.red,[m
[32m+[m[32m      ),[m
[32m+[m[32m    );[m
[32m+[m[32m    if (ok) await _load();[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Future<void> _messageOrganizer(Game game) async {[m
[32m+[m[32m    final info = game.contactInfo?.trim();[m
[32m+[m[32m    if (info == null || info.isEmpty) return;[m
[32m+[m[32m    if (info.contains('@')) {[m
[32m+[m[32m      final uri = Uri(scheme: 'mailto', pa