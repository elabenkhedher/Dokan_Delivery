import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyWorkingHours {
  final bool enabled;
  final TimeOfDay start;
  final TimeOfDay end;

  const DailyWorkingHours({
    required this.enabled,
    required this.start,
    required this.end,
  });

  factory DailyWorkingHours.fromJson(Map<String, dynamic> json) {
    return DailyWorkingHours(
      enabled: json['enabled'] as bool,
      start: TimeOfDay(
        hour: json['startHour'] as int,
        minute: json['startMinute'] as int,
      ),
      end: TimeOfDay(
        hour: json['endHour'] as int,
        minute: json['endMinute'] as int,
      ),
    );
  }

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'startHour': start.hour,
    'startMinute': start.minute,
    'endHour': end.hour,
    'endMinute': end.minute,
  };

  DailyWorkingHours copyWith({
    bool? enabled,
    TimeOfDay? start,
    TimeOfDay? end,
  }) {
    return DailyWorkingHours(
      enabled: enabled ?? this.enabled,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  bool contains(DateTime dateTime) {
    if (!enabled) {
      return false;
    }

    final currentMinute = dateTime.hour * 60 + dateTime.minute;
    final startMinute = start.hour * 60 + start.minute;
    final endMinute = end.hour * 60 + end.minute;
    return currentMinute >= startMinute && currentMinute < endMinute;
  }
}

class WorkingHoursService {
  static const _storageKey = 'driver_weekly_working_hours';
  static const weekdays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  final Future<SharedPreferences> _preferences;
  Map<int, DailyWorkingHours> _hours = _defaultHours();
  bool _isLoaded = false;

  WorkingHoursService({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance();

  Map<int, DailyWorkingHours> get hours => Map.unmodifiable(_hours);
  bool get isLoaded => _isLoaded;

  static Map<int, DailyWorkingHours> _defaultHours() => {
    for (var day = 1; day <= 7; day++)
      day: DailyWorkingHours(
        enabled: day <= DateTime.friday,
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 17, minute: 0),
      ),
  };

  Future<void> load() async {
    final preferences = await _preferences;
    final stored = preferences.getString(_storageKey);
    if (stored == null) {
      _isLoaded = true;
      return;
    }

    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format des horaires invalide.');
    }

    final loaded = _defaultHours();
    for (final entry in decoded.entries) {
      final day = int.tryParse(entry.key);
      if (day == null || day < 1 || day > 7 || entry.value is! Map) {
        throw const FormatException('Jour de travail invalide.');
      }
      loaded[day] = DailyWorkingHours.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }

    _hours = loaded;
    _isLoaded = true;
  }

  bool isWorkingAt(DateTime dateTime) =>
      _hours[dateTime.weekday]?.contains(dateTime) ?? false;

  Future<void> updateDay(int day, DailyWorkingHours dailyHours) async {
    if (day < 1 || day > 7) {
      throw RangeError.range(day, 1, 7, 'day');
    }
    if (dailyHours.enabled &&
        _minutes(dailyHours.end) <= _minutes(dailyHours.start)) {
      throw ArgumentError('L’heure de fin doit être après l’heure de début.');
    }

    final updated = {..._hours, day: dailyHours};
    final encoded = jsonEncode({
      for (final entry in updated.entries)
        entry.key.toString(): entry.value.toJson(),
    });

    final preferences = await _preferences;
    final saved = await preferences.setString(_storageKey, encoded);
    if (!saved) {
      throw StateError('Le stockage local a refusé la sauvegarde.');
    }
    _hours = updated;
    _isLoaded = true;
  }

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;
}
