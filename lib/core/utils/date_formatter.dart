import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String formatShort(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  static String formatFull(DateTime date) {
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  static String formatWithTime(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
