class RoomTemplates {
  static const defaultRoomsEn = <String>[
    'Entry',
    'Living room',
    'Kitchen',
    'Bedroom',
    'Bathroom',
    'Walls & ceiling',
    'Floors',
    'Doors & windows',
    'Appliances',
  ];

  static const defaultRoomsZhHans = <String>[
    '玄关',
    '客厅',
    '厨房',
    '卧室',
    '浴室',
    '墙面与天花板',
    '地板',
    '门窗',
    '电器',
  ];

  static List<String> forLanguageCode(String languageCode) {
    if (languageCode.toLowerCase().startsWith('zh')) {
      return defaultRoomsZhHans;
    }
    return defaultRoomsEn;
  }

  static String displayName(String roomName, String languageCode) {
    final index = _standardRoomIndex(roomName);
    if (index == null) return roomName;
    return forLanguageCode(languageCode)[index];
  }

  static int? _standardRoomIndex(String roomName) {
    final normalized = roomName.trim().toLowerCase();
    final englishIndex = defaultRoomsEn.indexWhere(
      (name) => name.toLowerCase() == normalized,
    );
    if (englishIndex != -1) return englishIndex;
    final chineseIndex = defaultRoomsZhHans.indexOf(roomName.trim());
    if (chineseIndex != -1) return chineseIndex;
    return null;
  }
}
