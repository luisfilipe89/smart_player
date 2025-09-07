import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/theme/tokens.dart';

class GameOrganizeScreen extends StatefulWidget {
  const GameOrganizeScreen({super.key});

  @override
  State<GameOrganizeScreen> createState() => _GameOrganizeScreenState();
}

class _GameOrganizeScreenState extends State<GameOrganizeScreen> {
  String? _selectedSport;
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;

  // Available sports with their icons
  final List<Map<String, dynamic>> _sports = [
    {
      'key': 'soccer',
      'icon': Icons.sports_soccer,
      'color': Colors.green,
    },
    {
      'key': 'basketball',
      'icon': Icons.sports_basketball,
      'color': Colors.orange,
    },
  ];

  // Generate list of dates for the next two weeks
  List<DateTime> get _availableDates {
    final today = DateTime.now();
    final dates = <DateTime>[];
    for (int i = 0; i < 14; i++) {
      dates.add(DateTime(today.year, today.month, today.day + i));
    }
    return dates;
  }

  List<String> get _availableTimes {
    return [
      '9:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
      '18:00',
      '19:00',
      '20:00',
      '21:00'
    ];
  }

  bool get _isFormComplete {
    return _selectedSport != null &&
        _selectedDate != null &&
        _selectedTime != null;
  }

  // Get day of week abbreviation (capitalized)
  String _getDayOfWeekAbbr(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  // Get month abbreviation
  String _getMonthAbbr(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[date.month - 1];
  }

  Future<void> _createGame() async {
    if (_selectedSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_select_sport'.tr()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_select_date'.tr()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_select_time'.tr()),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse the selected time and combine with selected date
      final timeParts = _selectedTime!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        hour,
        minute,
      );

      // Create a basic game object
      final game = Game(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sport: _selectedSport!,
        dateTime: combinedDateTime,
        location: 'TBD', // Will be filled in next step
        maxPlayers: 10,
        description: 'Game organized by user',
        organizerId: 'current_user_id',
        organizerName: 'Current User',
        createdAt: DateTime.now(),
      );

      // TODO: Save game to backend/database
      debugPrint('Created game: ${game.toJson()}');
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_created_successfully'.tr()),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('game_creation_failed'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.blackIcon),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'organize_a_game'.tr(),
          style: AppTextStyles.title,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppPaddings.symmHorizontalReg.copyWith(
            bottom: AppPaddings.allBig.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppHeights.reg),

              // Title
              Text(
                'choose_sport'.tr(),
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppHeights.small),
              Text(
                'select_sport_to_organize'.tr(),
                style: AppTextStyles.bodyMuted,
              ),

              const SizedBox(height: AppHeights.huge),

              // Sports Grid
              SizedBox(
                height: 120,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: AppWidths.regular,
                    mainAxisSpacing: AppHeights.reg,
                  ),
                  itemCount: _sports.length,
                  itemBuilder: (context, index) {
                    final sport = _sports[index];
                    final isSelected = _selectedSport == sport['key'];

                    return _buildSportCard(
                      sport: sport,
                      isSelected: isSelected,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedSport = sport['key'];
                          _selectedDate = null; // Reset date when sport changes
                          _selectedTime = null; // Reset time when sport changes
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: AppHeights.superHuge),

              // Date Selection Section (only show if sport is selected)
              if (_selectedSport != null) ...[
                const SizedBox(height: AppHeights.reg),
                Text(
                  'choose_date'.tr(),
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: AppHeights.small),
                Text(
                  'select_game_date'.tr(),
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: AppHeights.reg),

                // Date Grid
                SizedBox(
                  height: 65,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableDates.length,
                    itemBuilder: (context, index) {
                      final date = _availableDates[index];
                      final isSelected = _selectedDate != null &&
                          _selectedDate!.day == date.day &&
                          _selectedDate!.month == date.month;
                      final isToday = date.day == DateTime.now().day &&
                          date.month == DateTime.now().month;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: index < _availableDates.length - 1
                              ? AppWidths.regular
                              : 0,
                        ),
                        child: _buildDateCard(
                          date: date,
                          isSelected: isSelected,
                          isToday: isToday,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (isSelected) {
                                // If clicking on the already selected date, unselect it
                                _selectedDate = null;
                              } else {
                                // Select the new date
                                _selectedDate = date;
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppHeights.huge),
              ],

              // Time Selection Section (only show if date is selected)
              if (_selectedDate != null) ...[
                Text(
                  'choose_time'.tr(),
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: AppHeights.small),
                Text(
                  'select_game_time'.tr(),
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: AppHeights.reg),

                // Time Grid
                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableTimes.length,
                    itemBuilder: (context, index) {
                      final time = _availableTimes[index];
                      final isSelected = _selectedTime == time;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: index < _availableTimes.length - 1
                              ? AppWidths.regular
                              : 0,
                        ),
                        child: _buildTimeCard(
                          time: time,
                          isSelected: isSelected,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _selectedTime = time;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppHeights.huge),
              ],

              // Create Game Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isLoading || !_isFormComplete ? null : _createGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isFormComplete ? AppColors.blue : AppColors.grey,
                    foregroundColor: AppColors.white,
                    padding: AppPaddings.symmMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : Text(
                          'create_game'.tr(),
                          style: AppTextStyles.cardTitle.copyWith(
                            color: AppColors.white,
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

  Widget _buildSportCard({
    required Map<String, dynamic> sport,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : Border.all(
                color: AppColors.grey.withValues(alpha: 0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Sport Icon - larger and fills more space
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.blue.withValues(alpha: 0.1)
                          : (sport['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      sport['icon'] as IconData,
                      size: 28,
                      color:
                          isSelected ? AppColors.blue : sport['color'] as Color,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Sport Name - smaller text
                Expanded(
                  flex: 1,
                  child: Text(
                    sport['key'].toString().tr(),
                    style: AppTextStyles.superSmall.copyWith(
                      color: isSelected ? AppColors.blue : AppColors.blackText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Selection indicator - smaller
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle,
                      color: AppColors.blue,
                      size: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateCard({
    required DateTime date,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : Border.all(
                color: AppColors.grey.withValues(alpha: 0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Month abbreviation
                Text(
                  _getMonthAbbr(date),
                  style: AppTextStyles.superSmall.copyWith(
                    color: isSelected
                        ? AppColors.blue
                        : isToday
                            ? AppColors.blue
                            : AppColors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 7,
                  ),
                ),
                // Day of month
                Text(
                  date.day.toString(),
                  style: AppTextStyles.smallCardTitle.copyWith(
                    color: isSelected ? AppColors.blue : AppColors.blackText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Day of week
                Text(
                  _getDayOfWeekAbbr(date),
                  style: AppTextStyles.superSmall.copyWith(
                    color: isSelected
                        ? AppColors.blue
                        : isToday
                            ? AppColors.blue
                            : AppColors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String time,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 80,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        border: isSelected
            ? Border.all(color: AppColors.blue, width: 2)
            : Border.all(
                color: AppColors.grey.withValues(alpha: 0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              time,
              style: AppTextStyles.small.copyWith(
                color: isSelected ? AppColors.blue : AppColors.blackText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
