import 'package:flutter/material.dart';

enum Domain {
  management,
  tech,
  webDev,
  content,
  design,
  marketing,
}

extension DomainExtension on Domain {
  String get label {
    switch (this) {
      case Domain.management:
        return 'Management';
      case Domain.tech:
        return 'Tech';
      case Domain.webDev:
        return 'Web Dev';
      case Domain.content:
        return 'Content';
      case Domain.design:
        return 'Design';
      case Domain.marketing:
        return 'Marketing';
    }
  }

  String get apiValue => label.toUpperCase().replaceAll(' ', '_');

  String get shortLabel {
    switch (this) {
      case Domain.management:
        return 'MM';
      case Domain.tech:
        return 'T';
      case Domain.webDev:
        return 'WD';
      case Domain.content:
        return 'C';
      case Domain.design:
        return 'D';
      case Domain.marketing:
        return 'MT';
    }
  }

  Color get badgeColor {
    switch (this) {
      case Domain.management:
        return Colors.redAccent;
      case Domain.tech:
        return Colors.blueAccent;
      case Domain.webDev:
        return Colors.greenAccent;
      case Domain.content:
        return Colors.white70;
      case Domain.design:
        return Colors.pinkAccent;
      case Domain.marketing:
        return Colors.orangeAccent;
    }
  }

  static Domain? fromString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    if (normalized.contains('management')) return Domain.management;
    if (normalized.contains('webdev')) return Domain.webDev;
    if (normalized.contains('tech')) return Domain.tech;
    if (normalized.contains('content')) return Domain.content;
    if (normalized.contains('design')) return Domain.design;
    if (normalized.contains('marketing') || normalized == 'mt') {
      return Domain.marketing;
    }
    return null;
  }
}

