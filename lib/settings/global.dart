import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalSettings {
  static SharedPreferences? prefs;

  static String? get analyzeFilesPath =>
      prefs?.getString('analyze_files_path') ?? ""; // Default path if not se
  static set analyzeFilesPath(String? value) =>
      prefs?.setString('analyze_files_path', value ?? "");

  static String? get imapServer =>
      prefs?.getString('imap_server') ?? ""; // Default IMAP server if not set
  static set imapServer(String? value) =>
      prefs?.setString('imap_server', value ?? "");

  static int get imapPort => prefs?.getInt('imap_port') ?? 993; // Default port
  static set imapPort(int value) => prefs?.setInt('imap_port', value);

  static String? get mail =>
      prefs?.getString('mail') ?? ""; // Default mail if not set
  static set mail(String? value) => prefs?.setString('mail', value ?? "");

  static String? get password =>
      prefs?.getString('password') ?? ""; // Default password if not set
  static set password(String? value) =>
      prefs?.setString('password', value ?? "");

  /// Initializes global settings or configurations.
  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    if (prefs != null) {
      debugPrint("GlobalSettings initialized with SharedPreferences.");
    }
  }
}
