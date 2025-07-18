import 'package:flutter/widgets.dart';
import 'package:nfobserver/features/home/view/home.dart';
import 'package:nfobserver/features/settings/view/format_settings_activity.dart';
import 'package:nfobserver/features/settings/view/settings_activity.dart';
import 'package:nfobserver/features/xml/view/xml_activity.dart';

class AppRouters {
  static final home = "/";
  static final settings = "/settings";
  static final formatSettings = "/settings/formats";
  static final xmls = "/xmls";

  static final Map<String, WidgetBuilder> routers = {
    home: (context) => Home(),
    settings: (context) => SettingsActivity(),
    formatSettings: (context) => FormatSettingsActivity(),
    xmls: (context) => XMLActivity(),
  };
}
