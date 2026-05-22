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
}
