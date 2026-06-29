/// Time Utilities
/// Pure Dart helpers for time/duration calculations.
/// Zero UI dependencies — safe to use in domain/data layers.

import 'package:flutter/material.dart';

/// Extension on [TimeOfDay] providing medication-scheduling helpers.
extension DosageTimeExtension on TimeOfDay {
  /// Returns the [Duration] remaining until the next occurrence of this
  /// [TimeOfDay], calculated from [now] (defaults to [DateTime.now()]).
  ///
  /// If the time has already passed today the result wraps to tomorrow.
  Duration untilNextOccurrence({DateTime? now}) {
    final base = now ?? DateTime.now();
    final todayTarget = DateTime(
      base.year,
      base.month,
      base.day,
      hour,
      minute,
    );
    final diff = todayTarget.difference(base);
    // If the slot is in the past, the next occurrence is tomorrow.
    return diff.isNegative ? diff + const Duration(days: 1) : diff;
  }

  /// Returns a polished, human-readable label such as:
  ///   "Next alert triggers in 4 hours and 15 minutes"
  ///   "Next alert triggers in 45 minutes"
  ///   "Next alert triggers in less than a minute"
  String nextAlertLabel({DateTime? now}) {
    final remaining = untilNextOccurrence(now: now);
    return _formatDuration(remaining);
  }

  static String _formatDuration(Duration d) {
    final totalMinutes = d.inMinutes;
    if (totalMinutes <= 0) return 'Next alert triggers in less than a minute';

    final hours = d.inHours;
    final minutes = totalMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return 'Next alert triggers in $hours ${hours == 1 ? 'hour' : 'hours'}'
          ' and $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
    if (hours > 0) {
      return 'Next alert triggers in $hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return 'Next alert triggers in $minutes'
        ' ${minutes == 1 ? 'minute' : 'minutes'}';
  }
}

/// Parses an "HH:mm" string into a [TimeOfDay].
/// Returns `null` if the string is malformed.
TimeOfDay? parseTimeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
