
class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'welcome': 'Welcome',
      'dashboard': 'Dashboard',
      'projects': 'Projects',
      'team': 'Team',
      'polls': 'Polls',
      'create_project': 'Create New Project',
      'recent_activity': 'Recent Activity',
      'notifications': 'Notifications',
      'settings': 'Settings',
      'dark_mode': 'Dark Mode',
      'preferences': 'Preferences',
      'notifications_setting': 'Enable Notifications',
      'vibration': 'Vibration',
      'language': 'Language',
      'account': 'Account',
      'edit_profile': 'Edit Profile',
      'my_attendance': 'My Attendance',
      'about': 'About App',
      'logout': 'Logout',
    },
    'ta': {
      'welcome': 'வணக்கம்', // Vanakkam
      'good_morning': 'காலை வணக்கம்', // Kaalai Vanakkam
      'projects': 'திட்டங்கள்', // Thittangal
      'create_project': 'உங்கள் முதல் திட்டத்தை உருவாக்கவும்',
      'no_projects': 'திட்டங்கள் எதுவும் இல்லை',
      'manage_team': 'குழுவை நிர்வகிக்கவும்',
      'rename_project': 'திட்டத்தின் பெயரை மாற்றவும்',
      'delete_project': 'திட்டத்தை அழிக்கவும்',
      'settings': 'அமைப்புகள்',
      'appearance': 'தோற்றம்',
      'dark_mode': 'இருண்ட பயன்முறை',
      'preferences': 'விருப்பங்கள்',
      'notifications': 'அறிவிப்புகளை இயக்கு',
      'vibration': 'அதிர்வு',
      'language': 'மொழி',
      'account': 'கணக்கு',
      'edit_profile': 'சுயவிவரத்தைத் திருத்து',
      'my_attendance': 'எனது வருகை',
      'about': 'பயன்பாட்டைப் பற்றி',
      'logout': 'வெளியேறு',
    },
  };

  static String tr(String key, String langCode) {
    // Basic mapping: English -> en, Tamil -> ta
    String code = 'en';
    if (langCode == 'Tamil') code = 'ta';
    
    return _localizedValues[code]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
