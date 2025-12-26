
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

  String get code {
    switch (this) {
      case Domain.management:
        return 'M';
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

  static Domain? fromString(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'management') return Domain.management;
    if (normalized == 'tech') return Domain.tech;
    if (normalized == 'webdev' || normalized == 'web dev') return Domain.webDev;
    if (normalized == 'content') return Domain.content;
    if (normalized == 'design') return Domain.design;
    if (normalized == 'marketing') return Domain.marketing;
    return null;
  }
}
