import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalSettings {
  static SharedPreferences? prefs;

  static String get analyzeFilesPath => prefs?.getString('analyze_files_path') ?? ""; // Default path if not se
  static set analyzeFilesPath(String? value) => prefs?.setString('analyze_files_path', value ?? "");

  static String get imapServer => prefs?.getString('imap_server') ?? ""; // Default IMAP server if not set
  static set imapServer(String? value) => prefs?.setString('imap_server', value ?? "");

  static int get imapPort => prefs?.getInt('imap_port') ?? 993; // Default port
  static set imapPort(int value) => prefs?.setInt('imap_port', value);

  static String get mail => prefs?.getString('mail') ?? ""; // Default mail if not set
  static set mail(String? value) => prefs?.setString('mail', value ?? "");

  static String get password => prefs?.getString('password') ?? ""; // Default password if not set
  static set password(String? value) => prefs?.setString('password', value ?? "");

  static String get xmlPath => prefs?.getString('xml_path') ?? ""; // Default path if not set
  static set xmlPath(String? value) => prefs?.setString('xml_path', value ?? "");

  //Uma Lista com filtros
  //Formatado e JSON:
  //{
  //  "FILE_TYPE": "<NOME_DO_TIPO>",
  //  "OPERATOR_TYPE" : "<TIPO_OPERAÇÂO>",
  //  "OCCURRENCE" : "<OCORRÊNCIA>"
  //}
  // FILE_TYPE: Irá receber o nome do tipo de arquivo suportado pelo filtro. Os tipos estarão na classe
  static List<String> get docTypeFilters =>
      prefs?.getStringList("doc_type_filters") ??
      [
        '{"FILE_TYPE": "BONUS", "OPERATOR_TYPE": "CONTAINS", "OCCURRENCE": "BONIFICAÇÃO"}',
        r'{"FILE_TYPE": "FISCAL_NOTE", "OPERATOR_TYPE": "REGEX", "OCCURRENCE": "(NF \\d*|\\s-\\s\\d+)"}',
        r'{"FILE_TYPE": "REPORT", "OPERATOR_TYPE": "REGEX", "OCCURRENCE": "^((\\d{2}|\\d{2}-\\d{2})(,\\d{2})*.\\d{2}.\\d{2})"}',
        r'{"FILE_TYPE": "PAID", "OPERATOR_TYPE": "REGEX", "OCCURRENCE": "(((À|a|A|à)\\s(VISTA|vista))|(paid|PAID))" }',
      ];
  static set docTypeFilters(List<String> value) => prefs?.setStringList("doc_type_filters", value);

  /// Initializes global settings or configurations.
  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    if (prefs != null) {
      debugPrint("GlobalSettings initialized with SharedPreferences.");
    }
  }
}
