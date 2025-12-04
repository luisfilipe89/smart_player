/// Cost categories for filtering events
enum CostType {
  free,    // Free events
  paid,    // Paid events
}

/// Utility class to parse cost strings and determine if event is free or paid
class CostParser {
  /// Parse a cost string and return the cost type
  /// Returns null if cost cannot be determined
  static CostType? parseCostType(String cost) {
    if (cost.isEmpty || cost == '-') return null;

    final lower = cost.toLowerCase();

    // Check for free indicators
    if (lower.contains('gratis') ||
        lower.contains('gratis!') ||
        lower.contains('free') ||
        lower.contains('ontdek gratis') ||
        lower.contains('gratis proefles') ||
        lower.contains('proeftrainen gratis')) {
      return CostType.free;
    }

    // Check for paid indicators (contains € or euro)
    if (lower.contains('€') ||
        lower.contains('euro') ||
        lower.contains('per kwartaal') ||
        lower.contains('per maand') ||
        lower.contains('per jaar') ||
        lower.contains('per keer') ||
        lower.contains('per les') ||
        lower.contains('inschrijfgeld') ||
        lower.contains('inschrijfkosten')) {
      return CostType.paid;
    }

    // If contains "zie website" or "contact", assume paid (requires inquiry)
    if (lower.contains('zie website') ||
        lower.contains('contact') ||
        lower.contains('na inschrijving')) {
      return CostType.paid;
    }

    return null; // Unknown
  }

  /// Check if an event matches the selected cost type
  static bool matchesCostType(String cost, CostType? selectedType) {
    if (selectedType == null) return true; // No filter selected

    final costType = parseCostType(cost);
    if (costType == null) return false; // Can't parse, exclude

    return costType == selectedType;
  }
}



