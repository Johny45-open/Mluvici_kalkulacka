import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:math_expressions/math_expressions.dart' as math_expr;
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'update_checker.dart';
import 'currency_service.dart';

part 'models.dart';
part 'calculator_screen.dart';
part 'widgets.dart';
part 'dialogs.dart';
part 'voice_set_creation.dart';
part 'guided_set_creation.dart';
part 'dev_mode.dart';
part 'stats_storage.dart';
part 'stats_sets_dialog.dart';
part 'dialogs/stats_summary_dialog.dart';
part 'dialogs/reading_order_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScientificCalculatorApp());
}

class _FocusRestoreObserver extends NavigatorObserver {
  final Map<Route<dynamic>, FocusNode?> _openers = {};
  final Map<Route<dynamic>, Timer> _pendingRestores = {};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Nový dialog byl otevřen – zruš pending restore předchozího pop,
    // jinak by za ~150 ms vytrhl fokus novému dialogu (Windows Tab bug).
    for (final t in _pendingRestores.values) {
      t.cancel();
    }
    _pendingRestores.clear();
    _openers[route] = FocusManager.instance.primaryFocus;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final opener = _openers.remove(route);
    if (opener == null) {
      return;
    }
    final timer = Timer(const Duration(milliseconds: 150), () {
      _pendingRestores.remove(route);
      try {
        if (opener.context != null) {
          opener.requestFocus();
        }
      } catch (_) {
        // Uzel byl zničen, necháme výchozí chování.
      }
    });
    _pendingRestores[route] = timer;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _openers.remove(route);
    _pendingRestores.remove(route)?.cancel();
  }
}

class ScientificCalculatorApp extends StatefulWidget {
  final Locale? locale;

  const ScientificCalculatorApp({super.key, this.locale});

  @override
  State<ScientificCalculatorApp> createState() =>
      _ScientificCalculatorAppState();
}

class _ScientificCalculatorAppState extends State<ScientificCalculatorApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  final _FocusRestoreObserver _focusObserver = _FocusRestoreObserver();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool('themeMigratedToDark_v780') ?? false;
    final idx = prefs.getInt('themeMode');
    ThemeMode next;
    if (idx == null) {
      next = ThemeMode.dark;
      await prefs.setInt('themeMode', ThemeMode.dark.index);
    } else if (!migrated && idx == ThemeMode.system.index) {
      next = ThemeMode.dark;
      await prefs.setInt('themeMode', ThemeMode.dark.index);
    } else {
      final safeIdx = idx.clamp(0, ThemeMode.values.length - 1);
      next = ThemeMode.values[safeIdx];
    }
    if (!migrated) {
      await prefs.setBool('themeMigratedToDark_v780', true);
    }
    if (mounted) {
      setState(() {
        _themeMode = next;
      });
    } else {
      _themeMode = next;
    }
  }

  void _updateThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: widget.locale,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      navigatorObservers: [_focusObserver],
      home: CalculatorScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _updateThemeMode,
      ),
    );
  }
}
