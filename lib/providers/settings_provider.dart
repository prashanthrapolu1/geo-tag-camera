import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  final bool useDMSFormat; // true for DMS (e.g. 22°25'51"N), false for Decimal
  final bool useFahrenheit; // true for °F, false for °C
  final String dateFormat; // 'dd/MM/yyyy' or 'MM/dd/yyyy'

  AppSettings({
    this.useDMSFormat = false,
    this.useFahrenheit = false,
    this.dateFormat = 'dd/MM/yyyy',
  });

  AppSettings copyWith({
    bool? useDMSFormat,
    bool? useFahrenheit,
    String? dateFormat,
  }) {
    return AppSettings(
      useDMSFormat: useDMSFormat ?? this.useDMSFormat,
      useFahrenheit: useFahrenheit ?? this.useFahrenheit,
      dateFormat: dateFormat ?? this.dateFormat,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings();

  void setUseDMSFormat(bool useDMS) {
    state = state.copyWith(useDMSFormat: useDMS);
  }

  void setUseFahrenheit(bool useF) {
    state = state.copyWith(useFahrenheit: useF);
  }

  void setDateFormat(String format) {
    state = state.copyWith(dateFormat: format);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(() {
  return AppSettingsNotifier();
});
