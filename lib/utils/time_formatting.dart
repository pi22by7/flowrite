/// Formats time differences in warm, emotional ways
class EmotionalTimeFormat {
  EmotionalTimeFormat._();

  /// Get emotional, warm time description
  static String getEmotionalTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // Just now (< 1 minute)
    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    // Minutes ago (< 1 hour)
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      if (minutes == 1) return 'A moment ago';
      if (minutes < 5) return 'A few moments ago';
      if (minutes < 30) return 'Earlier today';
      return 'Earlier today';
    }

    // Hours ago (< 24 hours)
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      if (hours == 1) return 'An hour ago';
      if (hours < 4) return 'A few hours ago';
      return 'Earlier today';
    }

    // Days ago (< 7 days)
    if (difference.inDays < 7) {
      final days = difference.inDays;
      if (days == 1) return 'Yesterday';
      if (days == 2) return '2 days ago';
      return '$days days ago';
    }

    // Weeks ago (< 4 weeks)
    if (difference.inDays < 28) {
      final weeks = (difference.inDays / 7).floor();
      if (weeks == 1) return 'Last week';
      if (weeks == 2) return '2 weeks ago';
      return '$weeks weeks ago';
    }

    // Months ago (< 12 months)
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      if (months == 1) return 'Last month';
      return '$months months ago';
    }

    // Years ago
    final years = (difference.inDays / 365).floor();
    if (years == 1) return 'Last year';
    return '$years years ago';
  }

  /// Get a poetic description of when something was written
  static String getWrittenDescription(DateTime dateTime) {
    return 'Written ${getEmotionalTime(dateTime).toLowerCase()}';
  }

  /// Get song position description (e.g., "Your 3rd song")
  static String getSongPosition(int position, int total) {
    final ordinal = _getOrdinal(position);

    if (total <= 5) {
      return 'Your $ordinal song';
    } else if (position == 1) {
      return 'Your newest song';
    } else if (position == total) {
      return 'Your first song';
    } else if (position <= 3) {
      return 'Your $ordinal song';
    } else {
      // For others, just show written time instead
      return '';
    }
  }

  /// Convert number to ordinal (1st, 2nd, 3rd, etc.)
  static String _getOrdinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }

    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  /// Get month description for stats (e.g., "this month")
  static String getMonthDescription(DateTime dateTime) {
    final now = DateTime.now();

    if (dateTime.year == now.year && dateTime.month == now.month) {
      return 'this month';
    } else if (dateTime.year == now.year && dateTime.month == now.month - 1) {
      return 'last month';
    } else if (dateTime.year == now.year) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return 'in ${months[dateTime.month - 1]}';
    } else {
      return 'in ${dateTime.year}';
    }
  }
}
