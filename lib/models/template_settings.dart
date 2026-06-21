class TemplateSettings {
  bool showMap;
  bool showShortAddress;
  bool showFullAddress;
  bool showLatLong;
  bool showPlusCode;
  bool showDateTime;
  bool showTimeZone;
  bool showNumbering;
  bool showLogo;
  bool showNote;
  bool showPersonName;

  String noteText;
  String personNameText;

  TemplateSettings({
    this.showMap = true,
    this.showShortAddress = false,
    this.showFullAddress = true,
    this.showLatLong = true,
    this.showPlusCode = true,
    this.showDateTime = true,
    this.showTimeZone = false,
    this.showNumbering = false,
    this.showLogo = true,
    this.showNote = false,
    this.showPersonName = false,
    this.noteText = "",
    this.personNameText = "",
  });

  TemplateSettings copyWith({
    bool? showMap,
    bool? showShortAddress,
    bool? showFullAddress,
    bool? showLatLong,
    bool? showPlusCode,
    bool? showDateTime,
    bool? showTimeZone,
    bool? showNumbering,
    bool? showLogo,
    bool? showNote,
    bool? showPersonName,
    String? noteText,
    String? personNameText,
  }) {
    return TemplateSettings(
      showMap: showMap ?? this.showMap,
      showShortAddress: showShortAddress ?? this.showShortAddress,
      showFullAddress: showFullAddress ?? this.showFullAddress,
      showLatLong: showLatLong ?? this.showLatLong,
      showPlusCode: showPlusCode ?? this.showPlusCode,
      showDateTime: showDateTime ?? this.showDateTime,
      showTimeZone: showTimeZone ?? this.showTimeZone,
      showNumbering: showNumbering ?? this.showNumbering,
      showLogo: showLogo ?? this.showLogo,
      showNote: showNote ?? this.showNote,
      showPersonName: showPersonName ?? this.showPersonName,
      noteText: noteText ?? this.noteText,
      personNameText: personNameText ?? this.personNameText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showMap': showMap,
      'showShortAddress': showShortAddress,
      'showFullAddress': showFullAddress,
      'showLatLong': showLatLong,
      'showPlusCode': showPlusCode,
      'showDateTime': showDateTime,
      'showTimeZone': showTimeZone,
      'showNumbering': showNumbering,
      'showLogo': showLogo,
      'showNote': showNote,
      'showPersonName': showPersonName,
      'noteText': noteText,
      'personNameText': personNameText,
    };
  }

  factory TemplateSettings.fromJson(Map<String, dynamic> json) {
    return TemplateSettings(
      showMap: json['showMap'] ?? true,
      showShortAddress: json['showShortAddress'] ?? false,
      showFullAddress: json['showFullAddress'] ?? true,
      showLatLong: json['showLatLong'] ?? true,
      showPlusCode: json['showPlusCode'] ?? true,
      showDateTime: json['showDateTime'] ?? true,
      showTimeZone: json['showTimeZone'] ?? false,
      showNumbering: json['showNumbering'] ?? false,
      showLogo: json['showLogo'] ?? true,
      showNote: json['showNote'] ?? false,
      showPersonName: json['showPersonName'] ?? false,
      noteText: json['noteText'] ?? "",
      personNameText: json['personNameText'] ?? "",
    );
  }
}
