/// Age group categories for filtering events
enum AgeGroup {
  all, // Alle leeftijden / All ages
  toddlers, // 0-4 years
  kids, // 5-11 years
  youth, // 12-18 years
  young, // 18-25 years
  adult, // 26-55 years
  senior, // 46-65 years
  seniorPlus, // 66+ years
}

/// Utility class to parse Dutch age group strings from target_group field
class AgeGroupParser {
  /// Parse a target_group string and return matching age groups
  /// Returns null if no age groups can be determined
  static Set<AgeGroup>? parseAgeGroups(String targetGroup) {
    if (targetGroup.isEmpty || targetGroup == '-') return null;

    final lower = targetGroup.toLowerCase();

    // Check for "Alle leeftijden" (All ages)
    if (lower.contains('alle leeftijden')) {
      return {AgeGroup.all};
    }

    final groups = <AgeGroup>{};

    // Pattern: "X t/m Y jaar" or "X en Y jaar"
    final rangeRegex = RegExp(r'(\d+)\s*(?:t/m|en)\s*(\d+)\s*jaar');
    final plusRegex = RegExp(r'(\d+)\+');
    final singlePlusRegex = RegExp(r'^(\d+)\+$');

    // Find all ranges
    for (final match in rangeRegex.allMatches(lower)) {
      final min = int.tryParse(match.group(1) ?? '');
      final max = int.tryParse(match.group(2) ?? '');
      if (min != null && max != null) {
        // Determine which age groups this range overlaps with
        // Toddlers: 0-4
        if (min <= 4 && max >= 0) {
          groups.add(AgeGroup.toddlers);
        }
        // Kids: 5-11
        if (min <= 11 && max >= 5) {
          groups.add(AgeGroup.kids);
        }
        // Youth: 12-18
        if (min <= 18 && max >= 12) {
          groups.add(AgeGroup.youth);
        }
        // Young: 18-25
        if (min <= 25 && max >= 18) {
          groups.add(AgeGroup.young);
        }
        // Adult: 26-55
        if (min <= 55 && max >= 26) {
          groups.add(AgeGroup.adult);
        }
        // Senior: 46-65
        if (min <= 65 && max >= 46) {
          groups.add(AgeGroup.senior);
        }
        // Senior+: 66+
        if (max >= 66) {
          groups.add(AgeGroup.seniorPlus);
        }
      }
    }

    // Find plus patterns (e.g., "18+", "86+")
    for (final match in plusRegex.allMatches(lower)) {
      final age = int.tryParse(match.group(1) ?? '');
      if (age != null) {
        if (age >= 66) {
          groups.add(AgeGroup.seniorPlus);
        } else if (age >= 46) {
          groups.add(AgeGroup.senior);
        } else if (age >= 26) {
          groups.add(AgeGroup.adult);
        } else if (age >= 18) {
          groups.add(AgeGroup.young);
        } else if (age >= 12) {
          groups.add(AgeGroup.youth);
        } else if (age >= 5) {
          groups.add(AgeGroup.kids);
        } else {
          groups.add(AgeGroup.toddlers);
        }
      }
    }

    // Handle single age with plus (e.g., "18+")
    final singlePlusMatch = singlePlusRegex.firstMatch(lower);
    if (singlePlusMatch != null) {
      final age = int.tryParse(singlePlusMatch.group(1) ?? '');
      if (age != null) {
        if (age >= 66) {
          groups.add(AgeGroup.seniorPlus);
        } else if (age >= 46) {
          groups.add(AgeGroup.senior);
        } else if (age >= 26) {
          groups.add(AgeGroup.adult);
        } else if (age >= 18) {
          groups.add(AgeGroup.young);
        } else if (age >= 12) {
          groups.add(AgeGroup.youth);
        } else if (age >= 5) {
          groups.add(AgeGroup.kids);
        } else {
          groups.add(AgeGroup.toddlers);
        }
      }
    }

    return groups.isEmpty ? null : groups;
  }

  /// Check if an event matches the selected age group
  static bool matchesAgeGroup(String targetGroup, AgeGroup? selectedGroup) {
    if (selectedGroup == null) return true; // No filter selected

    final eventGroups = parseAgeGroups(targetGroup);
    if (eventGroups == null) return false; // Can't parse, exclude

    // If event has "all ages", it matches everything
    if (eventGroups.contains(AgeGroup.all)) return true;

    // Check if selected group is in event's groups
    return eventGroups.contains(selectedGroup);
  }
}
