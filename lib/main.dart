import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'firebase_service.dart'; // Import the new service
import 'package:firebase_core/firebase_core.dart';
import 'mqtt_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert'; // For JSON encoding/decoding

// 1. تعريف مفتاح تنقل عام للوصول إلى السياق من أي مكان
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<double?> gasLevelResetNotifier = ValueNotifier<double?>(
  null,
);
// Free-plan mode: use local notifications from background DB listener.
const bool kUseFirebaseCloudPush = false;
const bool kFirebaseClosedOnlyNotifications = kUseFirebaseCloudPush;
const String kGasAlertsTopic = 'gas_alerts_all';

enum DashboardThemeStyle {
  greenSecurity,
  coolPinkNeon,
  redEmergency,
  darkMinimalBlue,
}

enum StatsRange { lastHour, last24Hours, last7Days, last30Days }

class DashboardThemePalette extends ThemeExtension<DashboardThemePalette> {
  const DashboardThemePalette({
    required this.style,
    required this.seedColor,
    required this.backgroundGradientStart,
    required this.backgroundGradientEnd,
    required this.ambientGlowColor,
    required this.headerColor,
    required this.safeColor,
    required this.warningColor,
    required this.dangerColor,
    required this.infoGlowColor,
  });

  final DashboardThemeStyle style;
  final Color seedColor;
  final Color backgroundGradientStart;
  final Color backgroundGradientEnd;
  final Color ambientGlowColor;
  final Color headerColor;
  final Color safeColor;
  final Color warningColor;
  final Color dangerColor;
  final Color infoGlowColor;

  static const DashboardThemePalette greenSecurity = DashboardThemePalette(
    style: DashboardThemeStyle.greenSecurity,
    seedColor: Color(0xFF00E676),
    backgroundGradientStart: Color(0xFF0D1B3E),
    backgroundGradientEnd: Color(0xFF02040A),
    ambientGlowColor: Color(0xFF00E676),
    headerColor: Color(0xFF8CFFB8),
    safeColor: Color(0xFF00E676),
    warningColor: Color(0xFFFFA726),
    dangerColor: Color(0xFFFF1744),
    infoGlowColor: Color(0xFF47FFC2),
  );

  static const DashboardThemePalette coolPinkNeon = DashboardThemePalette(
    style: DashboardThemeStyle.coolPinkNeon,
    seedColor: Color(0xFFFF4FA3),
    backgroundGradientStart: Color(0xFF251031),
    backgroundGradientEnd: Color(0xFF08030D),
    ambientGlowColor: Color(0xFFFF5DB8),
    headerColor: Color(0xFFFF88D1),
    safeColor: Color(0xFF56FFC8),
    warningColor: Color(0xFFFFC14D),
    dangerColor: Color(0xFFFF4F7C),
    infoGlowColor: Color(0xFFFF66CC),
  );

  static const DashboardThemePalette redEmergency = DashboardThemePalette(
    style: DashboardThemeStyle.redEmergency,
    seedColor: Color(0xFFFF3B3B),
    backgroundGradientStart: Color(0xFF2A0A0E),
    backgroundGradientEnd: Color(0xFF070102),
    ambientGlowColor: Color(0xFFFF4545),
    headerColor: Color(0xFFFF7B7B),
    safeColor: Color(0xFF57D9A3),
    warningColor: Color(0xFFFFB347),
    dangerColor: Color(0xFFFF2E2E),
    infoGlowColor: Color(0xFFFF5C5C),
  );

  static const DashboardThemePalette darkMinimalBlue = DashboardThemePalette(
    style: DashboardThemeStyle.darkMinimalBlue,
    seedColor: Color(0xFF4C8DFF),
    backgroundGradientStart: Color(0xFF0B1730),
    backgroundGradientEnd: Color(0xFF02060D),
    ambientGlowColor: Color(0xFF4C8DFF),
    headerColor: Color(0xFF89B6FF),
    safeColor: Color(0xFF56C2FF),
    warningColor: Color(0xFFFFC15B),
    dangerColor: Color(0xFFFF5B76),
    infoGlowColor: Color(0xFF6BA8FF),
  );

  static DashboardThemePalette byStyle(DashboardThemeStyle style) {
    switch (style) {
      case DashboardThemeStyle.coolPinkNeon:
        return coolPinkNeon;
      case DashboardThemeStyle.redEmergency:
        return redEmergency;
      case DashboardThemeStyle.darkMinimalBlue:
        return darkMinimalBlue;
      case DashboardThemeStyle.greenSecurity:
        return greenSecurity;
    }
  }

  @override
  DashboardThemePalette copyWith({
    DashboardThemeStyle? style,
    Color? seedColor,
    Color? backgroundGradientStart,
    Color? backgroundGradientEnd,
    Color? ambientGlowColor,
    Color? headerColor,
    Color? safeColor,
    Color? warningColor,
    Color? dangerColor,
    Color? infoGlowColor,
  }) {
    return DashboardThemePalette(
      style: style ?? this.style,
      seedColor: seedColor ?? this.seedColor,
      backgroundGradientStart:
          backgroundGradientStart ?? this.backgroundGradientStart,
      backgroundGradientEnd:
          backgroundGradientEnd ?? this.backgroundGradientEnd,
      ambientGlowColor: ambientGlowColor ?? this.ambientGlowColor,
      headerColor: headerColor ?? this.headerColor,
      safeColor: safeColor ?? this.safeColor,
      warningColor: warningColor ?? this.warningColor,
      dangerColor: dangerColor ?? this.dangerColor,
      infoGlowColor: infoGlowColor ?? this.infoGlowColor,
    );
  }

  @override
  DashboardThemePalette lerp(
    covariant ThemeExtension<DashboardThemePalette>? other,
    double t,
  ) {
    if (other is! DashboardThemePalette) return this;
    return DashboardThemePalette(
      style: t < 0.5 ? style : other.style,
      seedColor: Color.lerp(seedColor, other.seedColor, t)!,
      backgroundGradientStart: Color.lerp(
        backgroundGradientStart,
        other.backgroundGradientStart,
        t,
      )!,
      backgroundGradientEnd: Color.lerp(
        backgroundGradientEnd,
        other.backgroundGradientEnd,
        t,
      )!,
      ambientGlowColor: Color.lerp(
        ambientGlowColor,
        other.ambientGlowColor,
        t,
      )!,
      headerColor: Color.lerp(headerColor, other.headerColor, t)!,
      safeColor: Color.lerp(safeColor, other.safeColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      dangerColor: Color.lerp(dangerColor, other.dangerColor, t)!,
      infoGlowColor: Color.lerp(infoGlowColor, other.infoGlowColor, t)!,
    );
  }
}

DashboardThemeStyle _themeStyleFromStorage(String? raw) {
  switch (raw) {
    case 'cool_pink_neon':
      return DashboardThemeStyle.coolPinkNeon;
    case 'red_emergency':
      return DashboardThemeStyle.redEmergency;
    case 'dark_minimal_blue':
      return DashboardThemeStyle.darkMinimalBlue;
    case 'green_security':
    default:
      return DashboardThemeStyle.greenSecurity;
  }
}

String _themeStyleToStorage(DashboardThemeStyle style) {
  switch (style) {
    case DashboardThemeStyle.coolPinkNeon:
      return 'cool_pink_neon';
    case DashboardThemeStyle.redEmergency:
      return 'red_emergency';
    case DashboardThemeStyle.darkMinimalBlue:
      return 'dark_minimal_blue';
    case DashboardThemeStyle.greenSecurity:
      return 'green_security';
  }
}

String _notificationTypeFromPayload({
  Map<String, dynamic>? data,
  String? title,
  String? body,
}) {
  final rawType = (data?['type'] ?? '').toString().toLowerCase();
  if (rawType == 'danger' || rawType == 'warning' || rawType == 'info') {
    return rawType;
  }
  final text = '${title ?? ''} ${body ?? ''}'.toLowerCase();
  if (text.contains('danger') ||
      text.contains('خطر') ||
      text.contains('طوارئ')) {
    return 'danger';
  }
  if (text.contains('warning') || text.contains('تحذير')) {
    return 'warning';
  }
  return 'info';
}

double _gasLevelFromPayload({Map<String, dynamic>? data, String? body}) {
  final dataValue = double.tryParse((data?['gas_level'] ?? '').toString());
  if (dataValue != null) {
    return dataValue;
  }
  final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(body ?? '');
  if (match == null) {
    return 0;
  }
  return double.tryParse(match.group(1) ?? '') ?? 0;
}

Future<bool> _shouldProcessNotificationEvent(
  SharedPreferences prefs, {
  required String dedupKey,
  required String rateKey,
  Duration dedupWindow = const Duration(seconds: 90),
  Duration rateWindow = const Duration(seconds: 45),
}) async {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final lastDedupMs = prefs.getInt(dedupKey) ?? 0;
  if (nowMs - lastDedupMs < dedupWindow.inMilliseconds) {
    return false;
  }
  final lastRateMs = prefs.getInt(rateKey) ?? 0;
  if (nowMs - lastRateMs < rateWindow.inMilliseconds) {
    return false;
  }
  await prefs.setInt(dedupKey, nowMs);
  await prefs.setInt(rateKey, nowMs);
  return true;
}

class _GasAlertDecision {
  const _GasAlertDecision({required this.shouldNotify, required this.status});

  final bool shouldNotify;
  final String status;
}

String _gasStatusWithHysteresis(double level, String previousStatus) {
  switch (previousStatus) {
    case 'danger':
      if (level <= 45.0) {
        return level >= 6.0 ? 'warning' : 'safe';
      }
      return 'danger';
    case 'warning':
      if (level > 50.0) {
        return 'danger';
      }
      if (level < 5.0) {
        return 'safe';
      }
      return 'warning';
    default:
      if (level > 50.0) {
        return 'danger';
      }
      if (level >= 6.0) {
        return 'warning';
      }
      return 'safe';
  }
}

Future<_GasAlertDecision> _evaluateGasAlertDecision(
  SharedPreferences prefs,
  double gasLevel,
) async {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final previousStatus = prefs.getString('bg_last_status') ?? 'safe';
  final nextStatus = _gasStatusWithHysteresis(gasLevel, previousStatus);

  if (nextStatus == 'safe') {
    await prefs.setString('bg_last_status', 'safe');
    return const _GasAlertDecision(shouldNotify: false, status: 'safe');
  }

  final isStatusChanged = nextStatus != previousStatus;
  final cooldownMs = nextStatus == 'danger'
      ? const Duration(minutes: 2).inMilliseconds
      : const Duration(minutes: 10).inMilliseconds;
  final lastNotifyMs = prefs.getInt('bg_last_notify_$nextStatus') ?? 0;
  final cooldownPassed = nowMs - lastNotifyMs >= cooldownMs;

  final escalationDelta = nextStatus == 'danger' ? 10.0 : 5.0;
  final lastLevel = prefs.getDouble('bg_last_level_$nextStatus') ?? -1.0;
  final isEscalation =
      lastLevel < 0 || (gasLevel - lastLevel) >= escalationDelta;

  final shouldNotify = isStatusChanged || cooldownPassed || isEscalation;
  if (shouldNotify) {
    await prefs.setInt('bg_last_notify_$nextStatus', nowMs);
    await prefs.setDouble('bg_last_level_$nextStatus', gasLevel);
  }
  await prefs.setString('bg_last_status', nextStatus);

  return _GasAlertDecision(shouldNotify: shouldNotify, status: nextStatus);
}

Future<void> _appendAlertHistory(
  SharedPreferences prefs, {
  required String title,
  required String body,
  required String type,
  double? gasLevel,
}) async {
  final history = prefs.getStringList('alert_history') ?? [];
  final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  final entry = <String, dynamic>{
    'title': title,
    'body': body,
    'type': type,
    'gasLevel': gasLevel,
    'time': timestamp,
    'isRead': false,
  };
  history.insert(0, jsonEncode(entry));
  if (history.length > 200) {
    history.removeRange(50, history.length);
  }
  await prefs.setStringList('alert_history', history);
}

const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDo09di_vPt-rRSYbg9K_cV-mND0dZ6Sd0",
  appId: "1:107717002075:web:87625aebd813ebcc3d107e",
  messagingSenderId: "107717002075",
  projectId: "smartsaver-7d551",
  storageBucket: "smartsaver-7d551.firebasestorage.app",
  databaseURL: "https://smartsaver-7d551-default-rtdb.firebaseio.com/",
);

const FirebaseOptions _androidFirebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDo09di_vPt-rRSYbg9K_cV-mND0dZ6Sd0",
  appId: "1:107717002075:android:61d1a4ff71cf12e63d107e",
  messagingSenderId: "107717002075",
  projectId: "smartsaver-7d551",
  databaseURL: "https://smartsaver-7d551-default-rtdb.firebaseio.com/",
  storageBucket: "smartsaver-7d551.firebasestorage.app",
);

Future<bool> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return true;
  }
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: _webFirebaseOptions);
    } else {
      try {
        await Firebase.initializeApp();
      } catch (_) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await Firebase.initializeApp(options: _androidFirebaseOptions);
        } else {
          rethrow;
        }
      }
    }
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }
  return Firebase.apps.isNotEmpty;
}

// دالة لمعالجة الإشعارات في الخلفية (عندما يكون التطبيق مغلقاً أو في الخلفية)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    ui.DartPluginRegistrant.ensureInitialized();
    // تهيئة الإشعارات في وضع الخلفية لتجنب مشاكل الواجهة
    try {
      await NotificationService.init(isBackground: true);
    } catch (e) {
      debugPrint("Background notification init failed: $e");
    }
    await _ensureFirebaseInitialized();
    debugPrint("Handling a background message: ${message.messageId}");

    final prefs = await SharedPreferences.getInstance();
    final title =
        message.notification?.title ??
        (message.data['title']?.toString() ?? 'تنبيه');
    final body =
        message.notification?.body ?? (message.data['body']?.toString() ?? '');
    if (title.trim().isEmpty && body.trim().isEmpty) {
      return;
    }
    final type = _notificationTypeFromPayload(
      data: message.data,
      title: title,
      body: body,
    );
    final gasLevel = _gasLevelFromPayload(data: message.data, body: body);
    final dedupFingerprint = '${message.messageId ?? ''}|$type|$title|$body';
    final dedupKey = 'fcm_dedup_${dedupFingerprint.hashCode}';
    final rateKey = 'fcm_rate_$type';
    final allow = await _shouldProcessNotificationEvent(
      prefs,
      dedupKey: dedupKey,
      rateKey: rateKey,
    );
    if (!allow) {
      debugPrint('Skipped duplicate/rate-limited background notification');
      return;
    }
    await _appendAlertHistory(
      prefs,
      title: title,
      body: body,
      type: type,
      gasLevel: gasLevel,
    );

    final isDataOnlyMessage = message.notification == null;
    if (kFirebaseClosedOnlyNotifications && !isDataOnlyMessage) {
      return;
    }

    // For data-only FCM in background/terminated, explicitly show a local notification.
    // IMPORTANT: To play custom sound in background, send a DATA MESSAGE (no 'notification' key).
    if (!kIsWeb && isDataOnlyMessage) {
      final sound = prefs.getString('notification_sound') ?? 'notify.mp3';
      await NotificationService.showNotification(
        title,
        body,
        sound: sound,
        payload: <String, dynamic>{'type': type, 'gas_level': gasLevel},
        forceInClosedOnlyMode: true,
      );
    }
  } catch (e) {
    debugPrint("Error in FCM background handler: $e");
  }
}

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // التقاط أخطاء Flutter وعرضها في الكونسول بدلاً من انهيار التطبيق
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint("FLUTTER ERROR: ${details.exception}\n${details.stack}");
      };

      bool firebaseReady = await _ensureFirebaseInitialized();
      if (firebaseReady && kUseFirebaseCloudPush) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
        if (!kIsWeb) {
          await FirebaseMessaging.instance.setAutoInitEnabled(true);
        }
      } else if (kUseFirebaseCloudPush) {
        debugPrint(
          "FCM background handler is not registered: Firebase is not ready.",
        );
      } else {
        debugPrint("FCM push disabled: local-notification mode is active.");
      }

      // عرض الواجهة فوراً ثم تهيئة الخدمات في الخلفية لتقليل بطء الإقلاع.
      runApp(const SmartSaverApp());
      unawaited(_bootstrapAppServices(firebaseReady: firebaseReady));
    },
    (error, stack) {
      debugPrint("CRASH ERROR: $error\n$stack");
    },
  );
}

Future<void> _bootstrapAppServices({bool? firebaseReady}) async {
  // الإشعارات المحلية تتطلب إعدادات خاصة للويب، لذا نتجاوزها هنا لتجنب الأخطاء
  if (!kIsWeb) {
    try {
      await NotificationService.init(requestPermissions: true);
    } catch (e) {
      debugPrint("Error initializing notifications: $e");
    }
  }

  final isFirebaseReady = firebaseReady ?? await _ensureFirebaseInitialized();
  if (isFirebaseReady && !kIsWeb && kUseFirebaseCloudPush) {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      if (isFirebaseReady && !kFirebaseClosedOnlyNotifications) {
        await initializeService();
      } else if (kFirebaseClosedOnlyNotifications) {
        debugPrint("Background service disabled: Firebase-closed-only mode.");
      } else {
        debugPrint("Skipping background service: Firebase is not ready.");
      }
    } catch (e) {
      debugPrint("Error initializing background service: $e");
    }
  }
}

class SmartSaverApp extends StatefulWidget {
  const SmartSaverApp({super.key});

  @override
  State<SmartSaverApp> createState() => _SmartSaverAppState();

  static void setLocale(BuildContext context, Locale newLocale) {
    _SmartSaverAppState? state = context
        .findAncestorStateOfType<_SmartSaverAppState>();
    state?.setLocale(newLocale);
  }

  static void setDashboardThemeStyle(
    BuildContext context,
    DashboardThemeStyle style,
  ) {
    _SmartSaverAppState? state = context
        .findAncestorStateOfType<_SmartSaverAppState>();
    state?._setDashboardThemeStyle(style);
  }
}

class _SmartSaverAppState extends State<SmartSaverApp> {
  Locale _locale = const Locale('ar'); // اللغة الافتراضية العربية
  DashboardThemeStyle _themeStyle = DashboardThemeStyle.greenSecurity;

  @override
  void initState() {
    super.initState();
    _loadSavedThemeStyle();
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  Future<void> _loadSavedThemeStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final style = _themeStyleFromStorage(
      prefs.getString('dashboard_theme_style'),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _themeStyle = style;
    });
  }

  Future<void> _setDashboardThemeStyle(DashboardThemeStyle style) async {
    if (_themeStyle == style) {
      return;
    }
    setState(() {
      _themeStyle = style;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_theme_style', _themeStyleToStorage(style));
  }

  @override
  Widget build(BuildContext context) {
    final palette = DashboardThemePalette.byStyle(_themeStyle);
    final scaffoldBackgroundColor = Color.lerp(
      palette.backgroundGradientStart,
      Colors.black,
      0.2,
    )!;
    // تحديد ما إذا كان اللون المختار فاتحاً أم داكناً لضبط النصوص
    final bool isDark =
        ThemeData.estimateBrightnessForColor(scaffoldBackgroundColor) ==
        Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color cardColor = isDark ? const Color(0xFF1E2A40) : Colors.white;

    return MaterialApp(
      navigatorKey: navigatorKey, // ربط المفتاح بالتطبيق
      title: 'المنقذ الذكي',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeInOutCubic,
      theme: ThemeData(
        useMaterial3: true,
        brightness: isDark ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: palette.seedColor,
          brightness: isDark ? Brightness.dark : Brightness.light,
          surface: isDark ? const Color(0xFF121B2C) : const Color(0xFFF5F5F5),
          onSurface: textColor,
        ),
        scaffoldBackgroundColor: scaffoldBackgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: scaffoldBackgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.tajawal(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: textColor),
        ),
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
        // Cairo is excellent for both Arabic and English text
        textTheme: GoogleFonts.cairoTextTheme(
          isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
        ),
        extensions: <ThemeExtension<dynamic>>[palette],
      ),
      home: const SplashScreen(),
    );
  }
}

class AppFuturisticBackground extends StatelessWidget {
  const AppFuturisticBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<DashboardThemePalette>() ??
        DashboardThemePalette.greenSecurity;
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.2),
              radius: 1.2,
              colors: [
                palette.backgroundGradientStart,
                palette.backgroundGradientEnd,
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
        ...List.generate(5, (index) {
          final random = math.Random(index);
          return Positioned(
            top: random.nextDouble() * 800,
            left: random.nextDouble() * 400,
            child: Opacity(
              opacity: 0.3,
              child: Container(
                width: random.nextDouble() * 4 + 2,
                height: random.nextDouble() * 4 + 2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: palette.infoGlowColor,
                      blurRadius: random.nextDouble() * 10 + 5,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Positioned(
          top: -100,
          left: -50,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.ambientGlowColor.withValues(alpha: 0.09),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isExiting = false;
  bool _isBooting = false;
  bool _bootFailed = false;
  String _loadingMessageKey = 'splash_loading_boot';

  @override
  void initState() {
    super.initState();
    // تفعيل وضع ملء الشاشة هنا بدلاً من main لضمان استقرار التطبيق عند البدء
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      debugPrint("Error setting system UI mode: $e");
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _startBootFlow();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startBootFlow() async {
    if (_isBooting) {
      return;
    }
    _isBooting = true;
    if (mounted) {
      setState(() {
        _bootFailed = false;
        _isExiting = false;
        _loadingMessageKey = 'splash_loading_boot';
      });
    }
    try {
      final start = DateTime.now();
      setState(() {
        _loadingMessageKey = 'splash_loading_prefs';
      });
      await SharedPreferences.getInstance();

      if (!mounted) {
        _isBooting = false;
        return;
      }
      setState(() {
        _loadingMessageKey = 'splash_loading_assets';
      });
      try {
        await precacheImage(
          const AssetImage('assets/images/Logo.png'),
          context,
        );
      } catch (e) {
        debugPrint("Failed to load logo asset: $e");
      }

      final elapsed = DateTime.now().difference(start);
      const minDuration = Duration(milliseconds: 5000);
      if (elapsed < minDuration) {
        await Future.delayed(minDuration - elapsed);
      }

      if (!mounted) {
        _isBooting = false;
        return;
      }
      setState(() {
        _isExiting = true;
      });
      await Future.delayed(const Duration(milliseconds: 280));
      if (!mounted) {
        _isBooting = false;
        return;
      }
      _isBooting = false;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, animation, secondaryAnimation) =>
              const MainDashboard(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      debugPrint('Splash boot failed: $e');
      if (!mounted) {
        _isBooting = false;
        return;
      }
      setState(() {
        _bootFailed = true;
        _loadingMessageKey = 'splash_loading_failed';
      });
      _isBooting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final palette =
        Theme.of(context).extension<DashboardThemePalette>() ??
        DashboardThemePalette.greenSecurity;
    return Scaffold(
      body: AnimatedOpacity(
        opacity: _isExiting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        child: Stack(
          children: [
            const Positioned.fill(child: AppFuturisticBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final logoSize = (constraints.maxWidth * 0.38).clamp(
                    140.0,
                    200.0,
                  );
                  return Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Hero(
                                  tag: 'app_logo_hero',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: palette.ambientGlowColor
                                              .withValues(alpha: 0.24),
                                          blurRadius: 42,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/Logo.png',
                                      width: logoSize,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  strings.get('title'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                strings.get('splash_tagline'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 16,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 42),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: _bootFailed
                                    ? Column(
                                        key: const ValueKey('boot_failed'),
                                        children: [
                                          Icon(
                                            Icons.error_outline_rounded,
                                            color: palette.dangerColor,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            strings.get(_loadingMessageKey),
                                            style: GoogleFonts.cairo(
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          ElevatedButton.icon(
                                            onPressed: _startBootFlow,
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                            ),
                                            label: Text(strings.get('retry')),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  palette.seedColor,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        key: const ValueKey('boot_loading'),
                                        children: [
                                          CircularProgressIndicator(
                                            color: palette.seedColor,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            strings.get(_loadingMessageKey),
                                            style: GoogleFonts.cairo(
                                              color: Colors.white.withValues(
                                                alpha: 0.66,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FirstRunStep { loading, onboarding, setup }

class FirstRunFlowScreen extends StatefulWidget {
  const FirstRunFlowScreen({super.key, this.startAtSetup = false});

  final bool startAtSetup;

  @override
  State<FirstRunFlowScreen> createState() => _FirstRunFlowScreenState();
}

class _FirstRunFlowScreenState extends State<FirstRunFlowScreen> {
  _FirstRunStep _step = _FirstRunStep.loading;
  final PageController _onboardingController = PageController();
  int _onboardingIndex = 0;

  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _networkNameController = TextEditingController();
  final TextEditingController _brokerController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final List<String> _knownNetworks = [];
  String _selectedNetworkName = '';
  bool _connectionTested = false;
  bool _isTestingConnection = false;
  bool? _deviceConnected;
  String _setupStatusMessage = '';
  String _setupLastSeenText = '--';
  String _setupLatestLevelText = '--';
  String _setupWifiText = '--';

  @override
  void initState() {
    super.initState();
    _loadFirstRunState();
  }

  @override
  void dispose() {
    _onboardingController.dispose();
    _deviceNameController.dispose();
    _networkNameController.dispose();
    _brokerController.dispose();
    _topicController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstRunState() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    
    // تنظيف سجل التنبيهات القديم إذا كان المستخدم جديداً (لم ينهِ الترحيب بعد)
    if (!onboardingDone) {
      await prefs.remove('alert_history');
    }

    final setupDone = prefs.getBool('initial_setup_done') ?? false;

    _deviceNameController.text =
        prefs.getString('device_name') ?? 'SmartSaver Device';
    _networkNameController.text = prefs.getString('network_name') ?? '';
    final savedNetworks =
        prefs.getStringList('known_network_names') ?? <String>[];
    _knownNetworks
      ..clear()
      ..addAll(savedNetworks.where((e) => e.trim().isNotEmpty));
    if (_networkNameController.text.trim().isNotEmpty &&
        !_knownNetworks.contains(_networkNameController.text.trim())) {
      _knownNetworks.insert(0, _networkNameController.text.trim());
    }
    _selectedNetworkName = _networkNameController.text.trim().isEmpty
        ? '__manual__'
        : _networkNameController.text.trim();
    _brokerController.text =
        prefs.getString('setup_broker_address') ?? 'broker.emqx.io';
    _topicController.text =
        prefs.getString('setup_topic') ?? 'home/gas_sensor/level';
    _portController.text = prefs.getString('setup_port') ?? '1883';

    if (!mounted) return;
    if (widget.startAtSetup) {
      setState(() {
        _step = _FirstRunStep.setup;
      });
      return;
    }
    if (onboardingDone && setupDone) {
      _goToDashboard();
      return;
    }
    setState(() {
      _step = onboardingDone ? _FirstRunStep.setup : _FirstRunStep.onboarding;
    });
  }

  void _goToDashboard() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainDashboard()));
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    setState(() {
      _step = _FirstRunStep.setup;
    });
  }

  Future<void> _testSetupConnection() async {
    final strings = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_deviceNameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.get('setup_device_name_required'))),
      );
      return;
    }
    setState(() {
      _isTestingConnection = true;
      _deviceConnected = null;
      _setupStatusMessage = strings.get('setup_checking_device');
    });
    try {
      final sensorRef = FirebaseDatabase.instance.ref('home/gas_sensor');
      final firstSnapshot = await sensorRef.get();
      await Future.delayed(const Duration(milliseconds: 3500));
      final secondSnapshot = await sensorRef.get();

      final firstData =
          (firstSnapshot.value as Map?)?.cast<dynamic, dynamic>() ?? {};
      final secondData =
          (secondSnapshot.value as Map?)?.cast<dynamic, dynamic>() ?? {};

      final status = (secondData['status'] ?? '').toString().toLowerCase();
      final firstLastUpdate =
          int.tryParse((firstData['last_update'] ?? '').toString()) ?? -1;
      final secondLastUpdate =
          int.tryParse((secondData['last_update'] ?? '').toString()) ?? -1;
      final heartbeatMoved = secondLastUpdate > firstLastUpdate;
      final hasLevel = secondData['level'] != null;
      final online = status == 'online' && (heartbeatMoved || hasLevel);

      final levelNum = double.tryParse((secondData['level'] ?? '').toString());
      final wifiSsid = (secondData['wifi_ssid'] ?? '--').toString();
      final lastSeen = secondLastUpdate >= 0 ? strings.get('setup_now') : '--';

      setState(() {
        _deviceConnected = online;
        _connectionTested = online;
        _setupStatusMessage = online
            ? strings.get('setup_device_connected')
            : strings.get('setup_device_disconnected');
        _setupLastSeenText = lastSeen;
        _setupLatestLevelText = levelNum == null
            ? '--'
            : '${levelNum.toStringAsFixed(1)} PPM';
        _setupWifiText = wifiSsid;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            online
                ? strings.get('setup_test_success')
                : strings.get('setup_device_disconnected'),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _deviceConnected = false;
        _connectionTested = false;
        _setupStatusMessage = strings.get('setup_device_disconnected');
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${strings.get('error_prefix')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _finishSetup() async {
    final strings = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!_connectionTested) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.get('setup_test_first'))),
      );
      return;
    }
    final selectedNetwork = _selectedNetworkName == '__manual__'
        ? _networkNameController.text.trim()
        : _selectedNetworkName.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', _deviceNameController.text.trim());
    await prefs.setString('network_name', selectedNetwork);
    final mergedNetworks = <String>{
      ..._knownNetworks.where((e) => e.trim().isNotEmpty),
      if (selectedNetwork.isNotEmpty) selectedNetwork,
    }.toList();
    await prefs.setStringList('known_network_names', mergedNetworks);
    await prefs.setString(
      'setup_broker_address',
      _brokerController.text.trim(),
    );
    await prefs.setString('setup_topic', _topicController.text.trim());
    await prefs.setString('setup_port', _portController.text.trim());
    await prefs.setBool('initial_setup_done', true);
    if (!mounted) return;
    _goToDashboard();
  }

  Widget _buildOnboarding(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final pages = [
      (
        icon: Icons.shield_rounded,
        title: strings.get('onboarding_title_1'),
        body: strings.get('onboarding_body_1'),
      ),
      (
        icon: Icons.notifications_active_rounded,
        title: strings.get('onboarding_title_2'),
        body: strings.get('onboarding_body_2'),
      ),
      (
        icon: Icons.settings_ethernet_rounded,
        title: strings.get('onboarding_title_3'),
        body: strings.get('onboarding_body_3'),
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _onboardingController,
            itemCount: pages.length,
            onPageChanged: (index) => setState(() => _onboardingIndex = index),
            itemBuilder: (context, index) {
              final page = pages[index];
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      page.icon,
                      size: 90,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      page.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pages.length, (i) {
            final active = i == _onboardingIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white38,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            children: [
              TextButton(
                onPressed: _completeOnboarding,
                child: Text(strings.get('skip')),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (_onboardingIndex == pages.length - 1) {
                    _completeOnboarding();
                    return;
                  }
                  _onboardingController.nextPage(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Text(
                  _onboardingIndex == pages.length - 1
                      ? strings.get('get_started')
                      : strings.get('next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetupForm(BuildContext context) {
    final strings = AppLocalizations.of(context);
    InputDecoration deco(String label, {IconData? icon}) => InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.get('setup_title'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            strings.get('setup_subtitle'),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _deviceNameController,
            decoration: deco(
              strings.get('setup_device_name'),
              icon: Icons.memory_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.get('setup_network_name'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue:
                (_selectedNetworkName.isNotEmpty &&
                    (_selectedNetworkName == '__manual__' ||
                        _knownNetworks.contains(_selectedNetworkName)))
                ? _selectedNetworkName
                : (_knownNetworks.isNotEmpty
                      ? _knownNetworks.first
                      : '__manual__'),
            decoration: deco(
              strings.get('select_network_name'),
              icon: Icons.wifi_rounded,
            ),
            items: [
              ..._knownNetworks.map(
                (name) =>
                    DropdownMenuItem<String>(value: name, child: Text(name)),
              ),
              DropdownMenuItem<String>(
                value: '__manual__',
                child: Text(strings.get('network_manual_entry')),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedNetworkName = value;
                if (value != '__manual__') {
                  _networkNameController.text = value;
                }
              });
            },
          ),
          if (_selectedNetworkName == '__manual__') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _networkNameController,
              decoration: deco(
                strings.get('setup_network_name'),
                icon: Icons.edit_rounded,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            strings.get('setup_password_hint'),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isTestingConnection ? null : _testSetupConnection,
                icon: const Icon(Icons.network_check_rounded),
                label: Text(
                  _isTestingConnection
                      ? strings.get('setup_checking_device')
                      : strings.get('test_connection'),
                ),
              ),
              const SizedBox(width: 12),
              if (_connectionTested)
                Text(
                  strings.get('setup_test_passed'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (_setupStatusMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).cardTheme.color?.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      (_deviceConnected == true
                              ? Colors.green
                              : (_deviceConnected == false
                                    ? Colors.red
                                    : Colors.white38))
                          .withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _deviceConnected == true
                            ? Icons.check_circle
                            : (_deviceConnected == false
                                  ? Icons.error
                                  : Icons.hourglass_top),
                        color: _deviceConnected == true
                            ? Colors.green
                            : (_deviceConnected == false
                                  ? Colors.red
                                  : Colors.orange),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _setupStatusMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${strings.get('setup_last_seen')}: $_setupLastSeenText',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${strings.get('setup_latest_level')}: $_setupLatestLevelText',
                  ),
                  const SizedBox(height: 4),
                  Text('${strings.get('setup_wifi_ssid')}: $_setupWifiText'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _finishSetup,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(strings.get('finish_setup')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppFuturisticBackground()),
          SafeArea(
            child: _step == _FirstRunStep.loading
                ? Center(
                    child: Text(
                      strings.get('loading'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : (_step == _FirstRunStep.onboarding
                      ? _buildOnboarding(context)
                      : _buildSetupForm(context)),
          ),
        ],
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with SingleTickerProviderStateMixin {
  static const int _maxHistoryForUi = 50;
  static const int _maxPersistedStatsPoints = 500;
  static const String _statsHistoryKey = 'gas_stats_history_v1';
  int _selectedIndex = 0;
  double _currentGasLevel = 0.0; // نبدأ من الصفر لتجنب القيم الوهمية
  double _alertThreshold = 50.0;
  List<String> _alertHistory = [];
  String _selectedAlarmSound = 'alarm.mp3'; // النغمة الافتراضية
  String _selectedNotificationSound = 'notify.mp3'; // نغمة الإشعارات

  // Firebase Service Instance
  final FirebaseService _firebaseService = FirebaseService();
  // MQTT Service Instance
  final MqttService _mqttService = MqttService();

  final List<FlSpot> _gasLevelHistory = [];
  final List<DateTime> _gasLevelTimestamps = [];
  double _timeCounter = 0;
  StatsRange _selectedStatsRange = StatsRange.last24Hours;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _lastAlertStatus = 'safe'; // تتبع حالة التنبيه (safe, warning, danger)
  bool _dataListenersAttached = false;
  Timer? _historyRefreshDebounce;
  Timer? _statsPersistDebounce;

  // Animation for Futuristic UI
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _breathingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _setupAudio();
    _loadPersistedStats();
    _updateGraphData();
    _loadPreferences();
    _attachDataListenersOnce();
    _listenToService();
    gasLevelResetNotifier.addListener(_onGasLevelResetRequested);
    _setupFCM(); // تفعيل إعدادات الإشعارات
  }

  @override
  void dispose() {
    _historyRefreshDebounce?.cancel();
    _statsPersistDebounce?.cancel();
    unawaited(_persistStatsHistory());
    _firebaseService.lastError.removeListener(_onFirebaseErrorChanged);
    _firebaseService.gasLevel.removeListener(_onFirebaseGasLevelChanged);
    _mqttService.gasLevel.removeListener(_onMqttGasLevelChanged);
    gasLevelResetNotifier.removeListener(_onGasLevelResetRequested);
    _breathingController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onGasLevelResetRequested() {
    final value = gasLevelResetNotifier.value;
    if (value == null || !mounted) {
      return;
    }
    setState(() {
      _currentGasLevel = value;
      _updateGraphData();
      _handleAlarmSound();
    });
    gasLevelResetNotifier.value = null;
  }

  // إعدادات Firebase Cloud Messaging
  Future<void> _setupFCM() async {
    try {
      if (!kUseFirebaseCloudPush) {
        debugPrint("Skipping FCM setup: local-notification mode is active.");
        return;
      }
      final firebaseReady = await _ensureFirebaseInitialized();
      if (!firebaseReady) {
        debugPrint("Skipping FCM setup: Firebase is not ready.");
        return;
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // تسجيل المستمعات أولاً حتى لا تضيع رسائل foreground إذا فشل جلب التوكن.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        try {
          debugPrint('Got a message whilst in the foreground!');
          if (kFirebaseClosedOnlyNotifications) {
            debugPrint(
              "Foreground FCM received and suppressed (closed-only mode).",
            );
            return;
          }
          final dataGasLevel = message.data['gas_level']?.toString();
          final title =
              message.notification?.title ??
              (message.data['title']?.toString() ?? 'تنبيه');
          final body =
              message.notification?.body ??
              (message.data['body']?.toString() ??
                  (dataGasLevel == null ? '' : 'Gas level: $dataGasLevel PPM'));
          if (title.trim().isEmpty && body.trim().isEmpty) {
            return;
          }
          final prefs = await SharedPreferences.getInstance();
          final type = _notificationTypeFromPayload(
            data: message.data,
            title: title,
            body: body,
          );
          final gasLevel = _gasLevelFromPayload(data: message.data, body: body);
          final dedupFingerprint =
              '${message.messageId ?? ''}|$type|$title|$body|${message.data['gas_level'] ?? ''}';
          final dedupKey = 'fcm_dedup_${dedupFingerprint.hashCode}';
          final rateKey = 'fcm_rate_$type';
          final allow = await _shouldProcessNotificationEvent(
            prefs,
            dedupKey: dedupKey,
            rateKey: rateKey,
          );
          if (!allow) {
            debugPrint(
              'Skipped duplicate/rate-limited foreground notification',
            );
            return;
          }
          await _appendAlertHistory(
            prefs,
            title: title,
            body: body,
            type: type,
            gasLevel: gasLevel,
          );
          await _reloadAlertHistoryFromPrefs(prefs: prefs);
          await NotificationService.showNotification(
            title,
            body,
            sound: _selectedNotificationSound,
            payload: <String, dynamic>{'type': type, 'gas_level': gasLevel},
          );
        } catch (e) {
          debugPrint("Foreground FCM handler error: $e");
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message);
      });

      messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationClick(message);
        }
      });

      try {
        await messaging.setAutoInitEnabled(true);
      } catch (e) {
        debugPrint("FCM auto-init setup failed: $e");
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await messaging.setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
        } catch (e) {
          debugPrint("iOS foreground presentation setup failed: $e");
        }
      }

      // طلب الإذن للإشعارات (مهم للـ iOS و Android 13+)
      try {
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('User granted permission');
        } else {
          debugPrint('Notification permission is not granted.');
        }
      } catch (e) {
        debugPrint("FCM permission request failed: $e");
      }

      try {
        await messaging.subscribeToTopic(kGasAlertsTopic);
        debugPrint("Subscribed to FCM topic: $kGasAlertsTopic");
      } catch (e) {
        debugPrint("FCM topic subscribe failed: $e");
      }

      // طباعة التوكن (يمكنك استخدامه لإرسال إشعارات تجريبية من Firebase Console)
      try {
        final token = await messaging.getToken();
        debugPrint("FCM Token: $token");
      } catch (e) {
        debugPrint("FCM getToken failed: $e");
      }

      messaging.onTokenRefresh.listen((newToken) {
        debugPrint("FCM Token refreshed: $newToken");
        messaging.subscribeToTopic(kGasAlertsTopic).catchError((e) {
          debugPrint("FCM topic re-subscribe failed: $e");
        });
      });
    } catch (e) {
      debugPrint("FCM setup failed: $e");
    }
  }

  void _handleNotificationClick([RemoteMessage? message]) {
    _loadPreferences(); // تحديث القائمة لضمان ظهور الإشعار الجديد
    final title =
        message?.notification?.title ??
        (message?.data['title']?.toString() ?? 'تنبيه');
    final body =
        message?.notification?.body ??
        (message?.data['body']?.toString() ?? '');
    final type = _notificationTypeFromPayload(
      data: message?.data,
      title: title,
      body: body,
    );
    final payloadGas = _gasLevelFromPayload(data: message?.data, body: body);
    final initialLevel = payloadGas > 0
        ? payloadGas
        : (_currentGasLevel > 0 ? _currentGasLevel : 60.0);
    if (type != 'danger') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationDetailsScreen(
            title: title,
            body: body,
            type: type,
            gasLevel: payloadGas,
          ),
        ),
      ).then((_) {
        if (mounted) setState(() => _selectedIndex = 0);
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        // 3. تعديل فتح الإشعار ليذهب لصفحة الطوارئ بدلاً من السجل
        builder: (context) => EmergencyScreen(
          initialGasLevel:
              initialLevel, // تمرير القيمة الحالية أو قيمة خطر افتراضية
          threshold: _alertThreshold,
          onGasLevelChanged: (val) {
            setState(() {
              _currentGasLevel = val;
              _updateGraphData();
              _handleAlarmSound();
            });
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _selectedIndex = 0); // الرجوع للرئيسية
        _loadPreferences(); // تحديث العداد عند العودة
      }
    });
  }

  Future<void> _setupAudio() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );
    } catch (e) {
      debugPrint("Error setting up audio: $e");
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // إضافة هذا السطر سيقوم بمسح السجل بالكامل عند فتح التطبيق
    //await prefs.remove('alert_history');

    final loadedThreshold = prefs.getDouble('alert_threshold') ?? 50.0;
    final loadedHistory = (prefs.getStringList('alert_history') ?? [])
        .take(_maxHistoryForUi)
        .toList(growable: false);
    final loadedAlarmSound = prefs.getString('alarm_sound') ?? 'alarm.mp3';
    final loadedNotificationSound =
        prefs.getString('notification_sound') ?? 'notify.mp3';
    if (!mounted) {
      return;
    }
    if (_alertThreshold == loadedThreshold &&
        _selectedAlarmSound == loadedAlarmSound &&
        _selectedNotificationSound == loadedNotificationSound &&
        listEquals(_alertHistory, loadedHistory)) {
      return;
    }
    setState(() {
      _alertThreshold = loadedThreshold;
      _alertHistory = loadedHistory;
      _selectedAlarmSound = loadedAlarmSound;
      _selectedNotificationSound = loadedNotificationSound;
    });
  }

  void _attachDataListenersOnce() {
    if (_dataListenersAttached) {
      return;
    }
    _dataListenersAttached = true;

    _firebaseService.init();

    // _mqttService.connect("esp32@smartsaver.com", "12345678");
    _firebaseService.lastError.addListener(_onFirebaseErrorChanged);
    _firebaseService.gasLevel.addListener(_onFirebaseGasLevelChanged);
    _mqttService.gasLevel.addListener(_onMqttGasLevelChanged);
  }

  void _onFirebaseErrorChanged() {
    if (!mounted || _firebaseService.lastError.value == null) {
      return;
    }
    final strings = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${strings.get('error_prefix')}: ${_firebaseService.lastError.value}',
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _onFirebaseGasLevelChanged() {
    debugPrint(
      'تم تحديث البيانات: مستوى الغاز الجديد هو ${_firebaseService.gasLevel.value}',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _currentGasLevel = _firebaseService.gasLevel.value;
      _updateGraphData();
      _handleAlarmSound();
    });
  }

  void _onMqttGasLevelChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentGasLevel = _mqttService.gasLevel.value;
      _updateGraphData();
      _handleAlarmSound();
    });
  }

  Future<void> _reloadAlertHistoryFromPrefs({SharedPreferences? prefs}) async {
    final localPrefs = prefs ?? await SharedPreferences.getInstance();
    final history = (localPrefs.getStringList('alert_history') ?? [])
        .take(_maxHistoryForUi)
        .toList(growable: false);
    if (!mounted || listEquals(_alertHistory, history)) {
      return;
    }
    setState(() {
      _alertHistory = history;
    });
  }

  Future<void> _saveAlarmSound(String sound) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_sound', sound);
  }

  Future<void> _saveNotificationSound(String sound) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sound', sound);
    // تحديث الخدمة الخلفية فوراً بالتغييرات لضمان استخدام النغمة الجديدة
    FlutterBackgroundService().invoke('sync_prefs');
  }

  Future<void> _addHistoryLog(String message) async {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final timestamp = formatter.format(now);

    Map<String, dynamic> notificationData = {
      'title': message.contains(':') ? message.split(':')[0] : 'تنبيه',
      'body': message.contains(':')
          ? message.substring(message.indexOf(':') + 1).trim()
          : message,
      'time': timestamp,
      'isRead': false,
    };
    final logEntry = jsonEncode(notificationData);

    setState(() {
      _alertHistory.insert(0, logEntry);
      if (_alertHistory.length > 50) {
        _alertHistory.removeRange(50, _alertHistory.length);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('alert_history', _alertHistory);
  }

  Future<void> _clearHistory() async {
    setState(() {
      _alertHistory.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('alert_history', <String>[]);
    //await prefs.remove('alert_history');
    try {
      await NotificationService.clearAll();
    } catch (e) {
      debugPrint('Failed to clear system notifications: $e');
    }
  }

  int _countUnreadFast(List<String> history) {
    var unread = 0;
    for (final item in history) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          final isRead = decoded['isRead'] == true;
          if (!isRead) {
            unread++;
          }
          continue;
        }
      } catch (_) {}
      // Legacy fallback: if the value does not explicitly mark read=true, treat as unread.
      if (!item.contains('"isRead":true') && !item.contains('"isRead": true')) {
        unread++;
      }
    }
    return unread;
  }

  void _updateGraphData() {
    _timeCounter++;
    _gasLevelHistory.add(FlSpot(_timeCounter, _currentGasLevel));
    _gasLevelTimestamps.add(DateTime.now());
    if (_gasLevelHistory.length > 500) {
      _gasLevelHistory.removeAt(0);
      _gasLevelTimestamps.removeAt(0);
    }
    _schedulePersistStats();
  }

  Future<void> _loadPersistedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_statsHistoryKey) ?? const <String>[];
    if (raw.isEmpty || !mounted) {
      return;
    }

    final values = <double>[];
    final timestamps = <DateTime>[];
    for (final item in raw) {
      final separator = item.indexOf('|');
      if (separator <= 0 || separator >= item.length - 1) {
        continue;
      }
      final tsMs = int.tryParse(item.substring(0, separator));
      final value = double.tryParse(item.substring(separator + 1));
      if (tsMs == null || value == null) {
        continue;
      }
      timestamps.add(DateTime.fromMillisecondsSinceEpoch(tsMs));
      values.add(value);
    }
    if (values.isEmpty || timestamps.length != values.length) {
      return;
    }

    setState(() {
      _gasLevelHistory
        ..clear()
        ..addAll(
          List<FlSpot>.generate(
            values.length,
            (i) => FlSpot((i + 1).toDouble(), values[i]),
          ),
        );
      _gasLevelTimestamps
        ..clear()
        ..addAll(timestamps);
      _timeCounter = values.length.toDouble();
    });
  }

  void _schedulePersistStats() {
    _statsPersistDebounce?.cancel();
    _statsPersistDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_persistStatsHistory());
    });
  }

  Future<void> _persistStatsHistory() async {
    final limit = math.min(_gasLevelHistory.length, _gasLevelTimestamps.length);
    if (limit == 0) {
      return;
    }
    final start = math.max(0, limit - _maxPersistedStatsPoints);
    final serialized = <String>[];
    for (int i = start; i < limit; i++) {
      serialized.add(
        '${_gasLevelTimestamps[i].millisecondsSinceEpoch}|${_gasLevelHistory[i].y.toStringAsFixed(3)}',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_statsHistoryKey, serialized);
  }

  void _handleAlarmSound() async {
    final strings = AppLocalizations.of(context);
    // تحديد الحالة الحالية
    String currentStatus = 'safe';
    if (_currentGasLevel > 50.0) {
      currentStatus = 'danger';
    } else if (_currentGasLevel >= 6.0) {
      currentStatus = 'warning';
    }

    // إرسال الإشعارات وتسجيل السجل عند تغير الحالة فقط (مثلاً من تحذير إلى خطر)
    if (currentStatus != 'safe' && currentStatus != _lastAlertStatus) {
      _lastAlertStatus = currentStatus;
      Future.microtask(() async {
        if (mounted) {
          bool isDanger = currentStatus == 'danger';
          String title = isDanger
              ? strings.get('status_danger_hero')
              : strings.get('warning');
          String body =
              '${strings.get('current_gas')}: ${_currentGasLevel.toInt()} PPM';

          await _addHistoryLog('$title: $body');
          if (!kIsWeb && !kFirebaseClosedOnlyNotifications) {
            await NotificationService.showNotification(
              title,
              body,
              sound: _selectedNotificationSound,
            ); // تمرير النغمة المختارة
          }
        }
      });
    } else if (currentStatus == 'safe') {
      _lastAlertStatus = 'safe';
    }

    // تشغيل الصوت إذا تجاوز الحد المسموح (مستقل عن الإشعارات)
    if (_currentGasLevel > _alertThreshold) {
      // تشغيل الصوت فقط إذا تجاوز الحد الذي حدده المستخدم (أو الخطر الأحمر)
      // حساب حدة الصوت بناءً على نسبة تجاوز الحد المسموح (من 0.1 إلى 1.0)
      double intensity =
          (_currentGasLevel - _alertThreshold) / (100 - _alertThreshold);
      intensity = intensity.clamp(1.0, 1.0);

      if (_audioPlayer.state != PlayerState.playing) {
        debugPrint("Attempting to play alarm sound...");
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        // يرجى التأكد من وجود ملف alarm.mp3 في مجلد assets/sounds/
        try {
          await _audioPlayer.stop(); // إيقاف أي عملية سابقة لضمان التشغيل
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(AssetSource('sounds/$_selectedAlarmSound'));
        } catch (e) {
          debugPrint("Error playing sound: $e");
          if (kIsWeb && e.toString().contains('NotAllowedError')) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(strings.get('tap_to_enable_alarm_sound')),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 10),
                  action: SnackBarAction(
                    label: strings.get('activate'),
                    textColor: Colors.white,
                    onPressed: () async {
                      try {
                        await _audioPlayer.stop();
                        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
                        await _audioPlayer.play(
                          AssetSource('sounds/$_selectedAlarmSound'),
                        );
                      } catch (e) {
                        debugPrint("Error playing sound manually: $e");
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${strings.get('error_prefix')}: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            }
          }
        }
      }
      await _audioPlayer.setVolume(intensity);
    } else {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
    }
  }

  void _listenToService() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      // تم تعطيل المحاكاة المحلية لمنع التعارض مع بيانات MQTT الحقيقية.
      // _startLocalSimulation();
      return;
    }
    FlutterBackgroundService().on('update').listen((event) {
      // Ignore service update stream here to avoid unnecessary rebuilds.
    });
    FlutterBackgroundService().on('history_updated').listen((event) {
      _historyRefreshDebounce?.cancel();
      _historyRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
        _reloadAlertHistoryFromPrefs();
      });
    });
  }

  Widget? _buildFab(BuildContext context) {
    if (_selectedIndex != 0) {
      return null;
    }
    final strings = AppLocalizations.of(context);
    final bool isDanger = _currentGasLevel > 50.0;
    final bool isWarning = _currentGasLevel >= 6.0 && !isDanger;

    if (isDanger) {
      return _PulsingDangerFab(
        key: const ValueKey('danger'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyScreen(
                initialGasLevel: _currentGasLevel,
                threshold: _alertThreshold,
                onGasLevelChanged: (val) {
                  setState(() {
                    _currentGasLevel = val;
                    _updateGraphData();
                    _handleAlarmSound();
                  });
                },
              ),
            ),
          ).then((_) {
            if (mounted) setState(() => _selectedIndex = 0);
          });
        },
        tooltip: strings.get('fab_danger_tooltip'),
      );
    } else if (isWarning) {
      return FloatingActionButton(
        key: const ValueKey('warning'),
        onPressed: () => showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(strings.get('warning')),
            content: Text(strings.get('tips_warning')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(strings.get('dismiss')),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFFF9100),
        foregroundColor: Colors.white,
        tooltip: strings.get('fab_warning_tooltip'),
        child: const Icon(Icons.help_outline),
      );
    } else {
      return FloatingActionButton(
        key: const ValueKey('safe'),
        onPressed: () => setState(() => _selectedIndex = 1),
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.white,
        tooltip: strings.get('fab_safe_tooltip'),
        child: const Icon(Icons.info_outline),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<DashboardThemePalette>() ??
        DashboardThemePalette.greenSecurity;
    final strings = AppLocalizations.of(context);

    // منع إغلاق التطبيق عند الضغط على زر الرجوع في الإعدادات، والعودة للرئيسية بدلاً من ذلك
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true, // Important for the futuristic background
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'app_logo_hero',
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/Logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  strings.get('title'),
                  style: GoogleFonts.tajawal(
                    color: palette.headerColor,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: palette.headerColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: palette.headerColor),
          actions: [
            // مؤشر حالة الجهاز في الشريط العلوي
            ValueListenableBuilder<String>(
              valueListenable: _firebaseService.deviceStatus,
              builder: (context, status, child) {
                final isOnline = status.toLowerCase() == 'online';
                final statusColor = isOnline ? Colors.green : Colors.red;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline
                            ? strings.get('connected')
                            : strings.get('disconnected'),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: Builder(
                builder: (context) {
                  final unreadCount = _countUnreadFast(_alertHistory);
                  return Badge(
                    label: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    backgroundColor: Colors.red,
                    isLabelVisible: unreadCount > 0,
                    child: const Icon(CupertinoIcons.bell),
                  );
                },
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryScreen(
                      logs: _alertHistory
                          .take(_maxHistoryForUi)
                          .toList(growable: false),
                      onClear: _clearHistory,
                    ),
                  ),
                ).then((_) {
                  if (mounted) {
                    setState(() => _selectedIndex = 0); // الرجوع للرئيسية
                    _loadPreferences();
                  }
                });
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        floatingActionButton: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: _buildFab(context),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Stack(
          children: [
            const Positioned.fill(child: AppFuturisticBackground()),

            // Tab Content
            SafeArea(
              top: false, // Let content flow behind AppBar
              child: Padding(
                padding: EdgeInsets.only(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top,
                ),
                child: [
                  _buildHomeTab(context, colorScheme),
                  buildStatsTab(context, colorScheme),
                  _buildSettingsTab(context, colorScheme),
                ][_selectedIndex],
              ),
            ),
          ],
        ),
        drawer: NavigationDrawer(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
            Navigator.pop(context);
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 50, 28, 30),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.transparent,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/Logo.png',
                          fit: BoxFit.cover,
                          width: 90,
                          height: 90,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.get('title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      strings.get('smart_home_system'),
                      style: TextStyle(
                        color: Color(0xFF8FA1C6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            NavigationDrawerDestination(
              icon: const Icon(CupertinoIcons.home),
              label: Text(strings.get('home')),
            ),
            NavigationDrawerDestination(
              icon: const Icon(CupertinoIcons.graph_square),
              label: Text(strings.get('stats')),
            ),
            NavigationDrawerDestination(
              icon: const Icon(CupertinoIcons.settings),
              label: Text(strings.get('settings')),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              child: Divider(color: Color(0x33FFFFFF)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutAppScreen(),
                    ),
                  );
                },
                icon: const Icon(CupertinoIcons.info, color: Color(0xFF8CFFB8)),
                label: Text(
                  strings.get('about_app'),
                  style: const TextStyle(color: Color(0xFF8CFFB8)),
                ),
                style: TextButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, ColorScheme colorScheme) {
    final strings = AppLocalizations.of(context);
    final palette =
        Theme.of(context).extension<DashboardThemePalette>() ??
        DashboardThemePalette.greenSecurity;

    // Determine Status
    final bool isDanger = _currentGasLevel > 50.0;
    final bool isWarning = _currentGasLevel >= 6.0 && !isDanger;

    Color statusColor;
    String statusText;

    if (isDanger) {
      statusColor = palette.dangerColor;
      statusText = strings.get('status_danger');
    } else if (isWarning) {
      statusColor = palette.warningColor;
      statusText = strings.get('status_warning');
    } else {
      statusColor = palette.safeColor;
      statusText = strings.get('status_safe');
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Hero Status Header
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.22),
                          blurRadius: 26,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            color: statusColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          statusText,
                          style: GoogleFonts.tajawal(
                            color: statusColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: statusColor.withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const SizedBox(height: 20),

              // عرض رسالة الخطأ إن وجدت
              ValueListenableBuilder<String?>(
                valueListenable: _firebaseService.lastError,
                builder: (context, error, child) {
                  if (error == null) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withValues(alpha: 0.2),
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Futuristic Gauge
              SizedBox(
                height: 280,
                width: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated Glow Background
                    AnimatedBuilder(
                      animation: _breathingAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(
                                  alpha:
                                      0.1 + (_breathingAnimation.value * 0.1),
                                ),
                                blurRadius:
                                    40 + (_breathingAnimation.value * 20),
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // The Gauge Painter
                    CustomPaint(
                      size: const Size(280, 280),
                      painter: _FuturisticGaugePainter(
                        _currentGasLevel,
                        statusColor,
                      ),
                    ),
                    // Center Text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${_currentGasLevel.toInt()}",
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "PPM",
                          style: GoogleFonts.orbitron(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.get('gas_concentration'),
                          style: GoogleFonts.exo2(
                            color: statusColor.withValues(alpha: 0.7),
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            strings.get('live_monitoring'),
                            style: GoogleFonts.tajawal(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Status Message
              Text(
                isDanger
                    ? strings.get('home_msg_danger')
                    : (isWarning
                          ? strings.get('home_msg_warning')
                          : strings.get('home_msg_safe')),
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 40),

              // Info Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGlassInfoCard(
                        strings.get('latest_reading'),
                        "${_currentGasLevel.toInt()} PPM",
                        Icons.analytics_outlined,
                        palette.headerColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGlassInfoCard(
                        strings.get('temperature'),
                        "27\u00B0C",
                        Icons.thermostat_rounded,
                        palette.warningColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _firebaseService.deviceStatus,
                        builder: (context, status, _) {
                          return _buildGlassInfoCard(
                            strings.get('connection'),
                            status == 'online'
                                ? strings.get('connected')
                                : strings.get('disconnected'),
                            Icons.wifi_rounded,
                            palette.infoGlowColor,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInfoCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          height: 130,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.45),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: 0.5,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.01),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accentColor, size: 24),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.tajawal(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStatsTab(BuildContext context, ColorScheme colorScheme) {
    final strings = AppLocalizations.of(context);
    final palette =
        Theme.of(context).extension<DashboardThemePalette>() ??
        DashboardThemePalette.greenSecurity;
    final entries = _statsEntries();
    final spots = entries.map((e) => e.key).toList();
    final Map<double, DateTime> timeByX = {
      for (final e in entries) e.key.x: e.value,
    };

    // Calculate stats
    double avg = 0;
    double max = 0;
    double min = 0;

    int safeCount = 0;
    int warningCount = 0;
    int dangerCount = 0;

    if (spots.isNotEmpty) {
      final values = spots.map((e) => e.y).toList();
      max = values.reduce(math.max);
      min = values.reduce(math.min);
      avg = values.reduce((a, b) => a + b) / values.length;

      for (final v in values) {
        if (v > 50) {
          dangerCount++;
        } else if (v >= 6) {
          warningCount++;
        } else {
          safeCount++;
        }
      }
    }

    double minX = spots.isNotEmpty ? spots.first.x : 0;
    double maxX = spots.isNotEmpty ? spots.last.x : 1;
    if (minX == maxX) {
      maxX = minX + 1;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.get('stats'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 10,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings.get('live_monitor'),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: StatsRange.values.map((range) {
                  return ChoiceChip(
                    label: Text(_rangeLabel(strings, range)),
                    selected: _selectedStatsRange == range,
                    onSelected: (_) {
                      setState(() {
                        _selectedStatsRange = range;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Chart Card
              Container(
                height: 350,
                padding: const EdgeInsets.fromLTRB(16, 24, 24, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            strings.get('gas_levels'),
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(Icons.show_chart, color: colorScheme.primary),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 12,
                      ),
                      child: Row(
                        children: [
                          _buildLegendItem(
                            colorScheme,
                            palette.warningColor,
                            '${strings.get('threshold_warning')} 6 PPM',
                          ),
                          const SizedBox(width: 14),
                          _buildLegendItem(
                            colorScheme,
                            palette.dangerColor,
                            '${strings.get('threshold_danger')} 50 PPM',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: spots.isEmpty
                          ? Center(
                              child: Text(
                                strings.get('no_stats_data'),
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            )
                          : LineChart(
                              LineChartData(
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: 6,
                                      color: palette.warningColor.withValues(
                                        alpha: 0.85,
                                      ),
                                      strokeWidth: 1.2,
                                      dashArray: [6, 4],
                                    ),
                                    HorizontalLine(
                                      y: 50,
                                      color: palette.dangerColor.withValues(
                                        alpha: 0.9,
                                      ),
                                      strokeWidth: 1.4,
                                      dashArray: [6, 4],
                                    ),
                                  ],
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 20,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.05,
                                    ),
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 20,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) => Text(
                                        '${value.toInt()}',
                                        style: TextStyle(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                ),
                                minX: minX,
                                maxX: maxX,
                                minY: 0,
                                maxY: 100,
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    tooltipBgColor: colorScheme.surface,
                                    tooltipRoundedRadius: 8,
                                    getTooltipItems:
                                        (List<LineBarSpot> touchedBarSpots) {
                                          return touchedBarSpots.map((barSpot) {
                                            final at = timeByX[barSpot.x];
                                            final timeText = at == null
                                                ? '--:--:--'
                                                : DateFormat(
                                                    'HH:mm:ss',
                                                  ).format(at);
                                            final status = _statsStatusForValue(
                                              barSpot.y,
                                              strings,
                                            );
                                            return LineTooltipItem(
                                              '${barSpot.y.toInt()} PPM\n$timeText\n$status',
                                              TextStyle(
                                                color: colorScheme.onSurface,
                                                fontWeight: FontWeight.bold,
                                                height: 1.4,
                                              ),
                                            );
                                          }).toList();
                                        },
                                  ),
                                  handleBuiltInTouches: true,
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    curveSmoothness: 0.4,
                                    color: colorScheme.primary,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          colorScheme.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          colorScheme.primary.withValues(
                                            alpha: 0.0,
                                          ),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stats Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: (constraints.maxWidth - 16) / 2,
                        child: _buildStatCard(
                          context,
                          strings.get('avg_level'),
                          '${avg.toInt()} PPM',
                          Icons.analytics_outlined,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - 16) / 2,
                        child: _buildStatCard(
                          context,
                          strings.get('peak_level'),
                          '${max.toInt()} PPM',
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - 16) / 2,
                        child: _buildStatCard(
                          context,
                          strings.get('min_level'),
                          '${min.toInt()} PPM',
                          Icons.trending_down,
                          Colors.green,
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - 16) / 2,
                        child: _buildStatCard(
                          context,
                          strings.get('status_label'),
                          avg > 50.0
                              ? strings.get('status_danger_hero')
                              : (avg >= 6.0
                                    ? strings.get('warning')
                                    : strings.get('safe')),
                          avg > 50.0
                              ? Icons.dangerous
                              : (avg >= 6.0
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline),
                          avg > 50.0
                              ? Colors.red
                              : (avg >= 6.0 ? Colors.orange : Colors.teal),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Pie Chart Section
              if (spots.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.get('distribution_analysis'),
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: Row(
                          children: [
                            Expanded(
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  sections: [
                                    if (safeCount > 0)
                                      PieChartSectionData(
                                        color: Colors.green,
                                        value: safeCount.toDouble(),
                                        title:
                                            '${((safeCount / spots.length) * 100).toInt()}%',
                                        radius: 50,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    if (warningCount > 0)
                                      PieChartSectionData(
                                        color: Colors.orange,
                                        value: warningCount.toDouble(),
                                        title:
                                            '${((warningCount / spots.length) * 100).toInt()}%',
                                        radius: 50,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    if (dangerCount > 0)
                                      PieChartSectionData(
                                        color: Colors.red,
                                        value: dangerCount.toDouble(),
                                        title:
                                            '${((dangerCount / spots.length) * 100).toInt()}%',
                                        radius: 60,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLegendItem(
                                  colorScheme,
                                  Colors.green,
                                  strings.get('safe'),
                                ),
                                const SizedBox(height: 8),
                                _buildLegendItem(
                                  colorScheme,
                                  Colors.orange,
                                  strings.get('warning'),
                                ),
                                const SizedBox(height: 8),
                                _buildLegendItem(
                                  colorScheme,
                                  Colors.red,
                                  strings.get('status_danger_hero'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(ColorScheme colorScheme, Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContactDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentNumber = prefs.getString('emergency_number') ?? '911';
    final controller = TextEditingController(text: currentNumber);

    if (!mounted) {
      return;
    }
    final strings = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.get('emergency_contact')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: strings.get('enter_emergency_number'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.get('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await prefs.setString('emergency_number', controller.text);
              if (mounted) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(strings.get('number_saved'))),
                );
              }
            },
            child: Text(strings.get('save')),
          ),
        ],
      ),
    );
  }

  String _themeNameArabic(DashboardThemeStyle style) {
    switch (style) {
      case DashboardThemeStyle.greenSecurity:
        return 'الحماية الخضراء';
      case DashboardThemeStyle.coolPinkNeon:
        return 'نيون وردي';
      case DashboardThemeStyle.redEmergency:
        return 'طوارئ حمراء';
      case DashboardThemeStyle.darkMinimalBlue:
        return 'أزرق ليلي';
    }
  }

  Widget _buildThemeOptionButton({
    required DashboardThemeStyle style,
    required DashboardThemeStyle activeStyle,
    required ColorScheme colorScheme,
  }) {
    final palette = DashboardThemePalette.byStyle(style);
    final isSelected = style == activeStyle;
    return AnimatedScale(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      scale: isSelected ? 1.0 : 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? palette.headerColor.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.4 : 1.0,
          ),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: isSelected ? 0.13 : 0.05),
              Colors.white.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? palette.infoGlowColor : Colors.black)
                  .withValues(alpha: isSelected ? 0.35 : 0.12),
              blurRadius: isSelected ? 18 : 10,
              spreadRadius: isSelected ? 0.8 : 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.selectionClick();
              SmartSaverApp.setDashboardThemeStyle(context, style);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: palette.seedColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.seedColor.withValues(alpha: 0.5),
                          blurRadius: isSelected ? 10 : 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _themeNameArabic(style),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: isSelected
                            ? palette.headerColor
                            : colorScheme.onSurface.withValues(alpha: 0.86),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  DateTime? _statsRangeCutoff() {
    final now = DateTime.now();
    switch (_selectedStatsRange) {
      case StatsRange.lastHour:
        return now.subtract(const Duration(hours: 1));
      case StatsRange.last24Hours:
        return now.subtract(const Duration(hours: 24));
      case StatsRange.last7Days:
        return now.subtract(const Duration(days: 7));
      case StatsRange.last30Days:
        return now.subtract(const Duration(days: 30));
    }
  }

  List<MapEntry<FlSpot, DateTime>> _statsEntries() {
    final limit = math.min(_gasLevelHistory.length, _gasLevelTimestamps.length);
    final entries = <MapEntry<FlSpot, DateTime>>[];
    for (int i = 0; i < limit; i++) {
      entries.add(MapEntry(_gasLevelHistory[i], _gasLevelTimestamps[i]));
    }
    final cutoff = _statsRangeCutoff();
    if (cutoff == null) {
      return entries;
    }
    return entries.where((e) => !e.value.isBefore(cutoff)).toList();
  }

  String _statsStatusForValue(double value, AppLocalizations strings) {
    if (value > 50) return strings.get('status_danger');
    if (value >= 6) return strings.get('status_warning');
    return strings.get('status_safe');
  }

  String _rangeLabel(AppLocalizations strings, StatsRange range) {
    switch (range) {
      case StatsRange.lastHour:
        return strings.get('stats_range_1h');
      case StatsRange.last24Hours:
        return strings.get('stats_range_24h');
      case StatsRange.last7Days:
        return strings.get('stats_range_7d');
      case StatsRange.last30Days:
        return strings.get('stats_range_30d');
    }
  }

  Widget _buildSettingsTab(BuildContext context, ColorScheme colorScheme) {
    final strings = AppLocalizations.of(context);
    final activePalette =
        Theme.of(context).extension<DashboardThemePalette>() ??
        DashboardThemePalette.greenSecurity;
    final activeStyle = activePalette.style;
    const styles = [
      DashboardThemeStyle.greenSecurity,
      DashboardThemeStyle.coolPinkNeon,
      DashboardThemeStyle.redEmergency,
      DashboardThemeStyle.darkMinimalBlue,
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListTileTheme(
          data: ListTileThemeData(
            textColor: colorScheme.onSurface,
            iconColor: colorScheme.onSurface,
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: Text(strings.get('change_language')),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            final currentLocale = Localizations.localeOf(
                              context,
                            );
                            final newLocale = currentLocale.languageCode == 'ar'
                                ? const Locale('en')
                                : const Locale('ar');
                            SmartSaverApp.setLocale(context, newLocale);
                            if (mounted) {
                              setState(() => _selectedIndex = 0);
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.volume_up),
                          title: Text(strings.get('alarm_sound')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.play_circle_fill,
                                  color: colorScheme.onSurface,
                                ),
                                tooltip: strings.get('test_sound'),
                                onPressed: () async {
                                  await _audioPlayer.stop();
                                  await _audioPlayer.setReleaseMode(
                                    ReleaseMode.stop,
                                  );
                                  await _audioPlayer.play(
                                    AssetSource('sounds/$_selectedAlarmSound'),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value:
                                    [
                                      'alarm.mp3',
                                      'siren.mp3',
                                      'beep.mp3',
                                    ].contains(_selectedAlarmSound)
                                    ? _selectedAlarmSound
                                    : 'alarm.mp3',
                                dropdownColor: const Color(0xFF1A2437),
                                underline: Container(),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(
                                      () => _selectedAlarmSound = newValue,
                                    );
                                    _saveAlarmSound(newValue);
                                    _audioPlayer.stop();
                                    _audioPlayer.setReleaseMode(
                                      ReleaseMode.stop,
                                    );
                                    _audioPlayer.play(
                                      AssetSource('sounds/$newValue'),
                                    );
                                  }
                                },
                                items: [
                                  DropdownMenuItem(
                                    value: 'alarm.mp3',
                                    child: Text(strings.get('sound_default')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'siren.mp3',
                                    child: Text(strings.get('sound_siren')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'beep.mp3',
                                    child: Text(strings.get('sound_beep')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.notifications_active),
                          title: Text(strings.get('notification_sound_settings')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.play_circle_fill,
                                  color: colorScheme.onSurface,
                                ),
                                tooltip: strings.get('test_sound'),
                                onPressed: () async {
                                  if (_selectedNotificationSound == 'silent') return;
                                  try {
                                    await _audioPlayer.stop();
                                    await _audioPlayer
                                        .setReleaseMode(ReleaseMode.stop);
                                    await _audioPlayer.play(AssetSource(
                                        'sounds/$_selectedNotificationSound'));
                                  } catch (e) {
                                    debugPrint("Error playing sound: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("خطأ: الملف الصوتي غير موجود في assets/sounds أو لم يتم تعريفه في pubspec.yaml")),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: [
                                  'notify.mp3',
                                  'notify_1.mp3',
                                  'alert.mp3',
                                  'alert_1.mp3',
                                  'alert_2.mp3',
                                  'silent'
                                ].contains(_selectedNotificationSound)
                                    ? _selectedNotificationSound
                                    : 'notify.mp3',
                                dropdownColor: const Color(0xFF1A2437),
                                underline: Container(),
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: Colors.white),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (String? newValue) async {
                                  if (newValue != null) {
                                    setState(() =>
                                        _selectedNotificationSound = newValue);
                                    _saveNotificationSound(newValue);
                                    if (newValue != 'silent') {
                                      try {
                                        await _audioPlayer.stop();
                                        await _audioPlayer
                                            .setReleaseMode(ReleaseMode.stop);
                                        await _audioPlayer
                                            .play(AssetSource('sounds/$newValue'));
                                      } catch (_) {}
                                    }
                                  }
                                },
                                items: [
                                  DropdownMenuItem(
                                    value: 'notify.mp3',
                                    child: Text(strings.get('sound_notify')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'notify_1.mp3',
                                    child: Text(strings.get('sound_notify_1')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'alert.mp3',
                                    child: Text(strings.get('sound_alert')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'alert_1.mp3',
                                    child: Text(strings.get('sound_alert_1')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'alert_2.mp3',
                                    child: Text(strings.get('sound_alert_2')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'silent',
                                    child: Text(strings.get('sound_silent')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const Icon(CupertinoIcons.bell),
                          title: Text(strings.get('notifications')),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HistoryScreen(
                                  logs: _alertHistory
                                      .take(_maxHistoryForUi)
                                      .toList(growable: false),
                                  onClear: _clearHistory,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() => _selectedIndex = 0);
                                _loadPreferences();
                              }
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.contact_phone),
                          title: Text(strings.get('emergency_contact')),
                          trailing: const Icon(Icons.edit, size: 16),
                          onTap: _showEmergencyContactDialog,
                        ),
                        ListTile(
                          leading: const Icon(Icons.security),
                          title: Text(strings.get('security')),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SecurityScreen(),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() => _selectedIndex = 0);
                              }
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: Text(strings.get('help')),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HelpScreen(),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() => _selectedIndex = 0);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: activePalette.headerColor.withValues(
                          alpha: 0.38,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: activePalette.infoGlowColor.withValues(
                            alpha: 0.24,
                          ),
                          blurRadius: 22,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.palette_rounded,
                              color: activePalette.headerColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.get('theme'),
                              style: GoogleFonts.cairo(
                                color: activePalette.headerColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          childAspectRatio: 2.35,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: styles
                              .map(
                                (style) => _buildThemeOptionButton(
                                  style: style,
                                  activeStyle: activeStyle,
                                  colorScheme: colorScheme,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.96,
                                  end: 1.0,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            key: ValueKey(activeStyle),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  activePalette.backgroundGradientStart
                                      .withValues(alpha: 0.7),
                                  activePalette.backgroundGradientEnd
                                      .withValues(alpha: 0.7),
                                ],
                              ),
                              border: Border.all(
                                color: activePalette.headerColor.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'السمة الحالية: ${_themeNameArabic(activeStyle)}',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: activePalette.headerColor,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () {
                              SmartSaverApp.setDashboardThemeStyle(
                                context,
                                DashboardThemeStyle.greenSecurity,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.get('default_theme_restored'),
                                  ),
                                  duration: const Duration(milliseconds: 1300),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.restart_alt_rounded,
                              color: activePalette.headerColor,
                            ),
                            label: Text(
                              strings.get('restore_default_theme'),
                              style: GoogleFonts.cairo(
                                color: activePalette.headerColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: activePalette.headerColor.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDangerFab extends StatefulWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const _PulsingDangerFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_PulsingDangerFab> createState() => _PulsingDangerFabState();
}

class _PulsingDangerFabState extends State<_PulsingDangerFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 4.0,
      end: 15.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: const Color(0xFFFF1744),
        foregroundColor: Colors.white,
        tooltip: widget.tooltip,
        elevation: 0,
        child: const Icon(Icons.dangerous),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
    });
  }

  Future<void> _saveProfile() async {
    if (!mounted) return;
    final strings = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.get('name_saved'))),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('profile'))),
      body: Stack(
        children: [
          const Positioned.fill(child: AppFuturisticBackground()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.transparent,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/Logo.png',
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: strings.get('enter_name'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "user@example.com",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _saveProfile,
                  child: Text(strings.get('save')),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    strings.get('logout'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final List<String> logs;
  final Future<void> Function() onClear;

  const HistoryScreen({super.key, required this.logs, required this.onClear});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryListEntry {
  final String? header;
  final Map<String, dynamic>? log;

  const _HistoryListEntry.header(this.header) : log = null;
  const _HistoryListEntry.log(this.log) : header = null;

  bool get isHeader => header != null;
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const String _filterAll = 'all';
  static const String _filterUnread = 'unread';
  static const String _filterDanger = 'danger';
  static const String _filterWarning = 'warning';
  static const int _maxLogsOnScreen = 50;

  late List<Map<String, dynamic>> _parsedLogs;
  List<_HistoryListEntry> _visibleEntries = [];
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = _filterAll;
  String _searchQuery = '';
  String? _localeCode;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _parseLogs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context).languageCode;
    if (_localeCode != currentLocale) {
      _localeCode = currentLocale;
      _rebuildVisibleEntries();
    }
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.logs, widget.logs)) {
      _parseLogs();
      _rebuildVisibleEntries();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _parseLogs() {
    _parsedLogs = widget.logs.map<Map<String, dynamic>>((log) {
      try {
        final dynamic decoded = jsonDecode(log);
        if (decoded is Map<String, dynamic>) {
          final title = (decoded['title'] ?? 'تنبيه').toString();
          final body = (decoded['body'] ?? '').toString();
          final time = (decoded['time'] ?? '').toString();
          final titleLc = title.toLowerCase();
          final bodyLc = body.toLowerCase();
          final isDanger =
              titleLc.contains('danger') ||
              titleLc.contains('خطر') ||
              bodyLc.contains('danger') ||
              bodyLc.contains('خطر');
          final isWarning =
              !isDanger &&
              (titleLc.contains('warning') ||
                  titleLc.contains('تحذير') ||
                  bodyLc.contains('warning') ||
                  bodyLc.contains('تحذير'));
          return {
            'title': title,
            'body': body,
            'time': time,
            'isRead': decoded['isRead'] ?? false,
            if (decoded.containsKey('type')) 'type': decoded['type'],
            if (decoded.containsKey('gasLevel'))
              'gasLevel': decoded['gasLevel'],
            '_titleLc': titleLc,
            '_bodyLc': bodyLc,
            '_isDanger': isDanger,
            '_isWarning': isWarning,
            '_timeMs': _timeToMillis(time),
          };
        }
        return {
          'title': 'غير معروف',
          'body': log.toString(),
          'time': '',
          'isRead': true,
        };
      } catch (e) {
        // التعامل مع السجلات القديمة (نص عادي)
        final parts = log.split('\n');
        if (parts.length >= 2) {
          // محاولة استخراج الوقت والعنوان من الصيغة القديمة
          final title = parts[1];
          final body = parts.sublist(2).join(' ');
          final time = parts[0];
          final titleLc = title.toLowerCase();
          final bodyLc = body.toLowerCase();
          final isDanger =
              titleLc.contains('danger') ||
              titleLc.contains('خطر') ||
              bodyLc.contains('danger') ||
              bodyLc.contains('خطر');
          final isWarning =
              !isDanger &&
              (titleLc.contains('warning') ||
                  titleLc.contains('تحذير') ||
                  bodyLc.contains('warning') ||
                  bodyLc.contains('تحذير'));
          return {
            'title': title,
            'body': body,
            'time': time,
            'isRead': true,
            '_titleLc': titleLc,
            '_bodyLc': bodyLc,
            '_isDanger': isDanger,
            '_isWarning': isWarning,
            '_timeMs': _timeToMillis(time),
          };
        }
        return {
          'title': 'غير معروف',
          'body': parts.isNotEmpty ? parts[0] : '',
          'time': '',
          'isRead': true,
        };
      }
    }).toList();
    if (_parsedLogs.length > _maxLogsOnScreen) {
      _parsedLogs = _parsedLogs.sublist(0, _maxLogsOnScreen);
      unawaited(_saveLogs());
    }
  }

  int? _timeToMillis(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).parse(trimmed).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  bool _isDangerLog(Map<String, dynamic> log) {
    return log['_isDanger'] == true;
  }

  bool _isWarningLog(Map<String, dynamic> log) {
    return log['_isWarning'] == true;
  }

  String _dateGroupLabel(DateTime date, AppLocalizations strings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return strings.get('today');
    if (diff == 1) return strings.get('yesterday');
    if (diff <= 7) return strings.get('this_week');
    return DateFormat('yyyy/MM/dd').format(date);
  }

  void _rebuildVisibleEntries() {
    if (!mounted) {
      return;
    }
    final strings = AppLocalizations.of(context);
    final query = _searchQuery.trim().toLowerCase();
    final Map<String, List<Map<String, dynamic>>> groupedLogs = {};

    for (final log in _parsedLogs) {
      final isRead = log['isRead'] == true;
      final matchFilter = switch (_activeFilter) {
        _filterUnread => !isRead,
        _filterDanger => _isDangerLog(log),
        _filterWarning => _isWarningLog(log),
        _ => true,
      };
      if (!matchFilter) {
        continue;
      }
      if (query.isEmpty) {
        // no-op
      } else {
        final title = (log['_titleLc'] ?? '').toString();
        final body = (log['_bodyLc'] ?? '').toString();
        if (!title.contains(query) && !body.contains(query)) {
          continue;
        }
      }

      final timeMs = log['_timeMs'] as int?;
      final key = timeMs == null
          ? strings.get('date_unknown')
          : _dateGroupLabel(
              DateTime.fromMillisecondsSinceEpoch(timeMs),
              strings,
            );
      groupedLogs.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(log);
    }

    final entries = <_HistoryListEntry>[];
    for (final entry in groupedLogs.entries) {
      entries.add(_HistoryListEntry.header(entry.key));
      for (final log in entry.value) {
        entries.add(_HistoryListEntry.log(log));
      }
    }

    setState(() {
      _visibleEntries = entries;
    });
  }

  Future<void> _markAsReadLog(Map<String, dynamic> log) async {
    if (log['isRead'] == true) {
      return;
    }

    log['isRead'] = true;
    _rebuildVisibleEntries();
    await _saveLogs();
  }

  Future<void> _markAllAsRead() async {
    for (var log in _parsedLogs) {
      log['isRead'] = true;
    }
    _rebuildVisibleEntries();
    await _saveLogs();
  }

  Future<void> _deleteLog(Map<String, dynamic> log) async {
    _parsedLogs.remove(log);
    _rebuildVisibleEntries();
    await _saveLogs();
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stringLogs = _parsedLogs.map((e) {
      final clean = <String, dynamic>{
        'title': e['title'] ?? 'تنبيه',
        'body': e['body'] ?? '',
        'time': e['time'] ?? '',
        'isRead': e['isRead'] ?? false,
      };
      if (e.containsKey('type')) {
        clean['type'] = e['type'];
      }
      if (e.containsKey('gasLevel')) {
        clean['gasLevel'] = e['gasLevel'];
      }
      return jsonEncode(clean);
    }).toList();
    await prefs.setStringList('alert_history', stringLogs);
  }

  Future<void> _clearAllHistory() async {
    try {
      await widget.onClear();
    } catch (e) {
      debugPrint('History onClear callback failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('alert_history', <String>[]);
      await prefs.remove('alert_history');
    } catch (e) {
      debugPrint('History storage clear fallback failed: $e');
    }

    try {
      await NotificationService.clearAll();
    } catch (e) {
      debugPrint('History system notification clear failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.get('history_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: strings.get('mark_all_read'),
            onPressed: _markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(strings.get('warning')),
                  content: Text(strings.get('confirm_delete_history')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(strings.get('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        strings.get('delete'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _clearAllHistory();
                if (!mounted) return;
                setState(() {
                  _parsedLogs.clear();
                  _visibleEntries.clear();
                  _searchQuery = '';
                });
                _searchController.clear();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppFuturisticBackground()),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 220),
                      () {
                        if (!mounted) {
                          return;
                        }
                        _searchQuery = value;
                        _rebuildVisibleEntries();
                      },
                    );
                    if (_searchQuery.isNotEmpty && value.isEmpty) {
                      _searchQuery = '';
                      _rebuildVisibleEntries();
                    } else {
                      setState(() {});
                    }
                  },
                  decoration: InputDecoration(
                    hintText: strings.get('search_notifications'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _rebuildVisibleEntries();
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).cardTheme.color?.withValues(alpha: 0.86),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildFilterChip(strings.get('filter_all'), _filterAll),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      strings.get('filter_unread'),
                      _filterUnread,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      strings.get('filter_danger'),
                      _filterDanger,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      strings.get('filter_warning'),
                      _filterWarning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _visibleEntries.isEmpty
                    ? Center(
                        child: Text(
                          strings.get('no_alerts_yet'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _visibleEntries.length,
                        itemBuilder: (context, index) {
                          final entry = _visibleEntries[index];
                          if (entry.isHeader) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                entry.header!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          final log = entry.log!;
                          final bool isRead = log['isRead'] == true;
                          final bool isDanger = _isDangerLog(log);
                          final bool isWarning = _isWarningLog(log);
                          final accent = isDanger
                              ? Colors.red
                              : (isWarning
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.primary);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Dismissible(
                              key: Key(
                                '${log['time']}_${log['title']}_${log.hashCode}',
                              ),
                              direction: DismissDirection.horizontal,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.done,
                                  color: Colors.white,
                                ),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  await _markAsReadLog(log);
                                  return false;
                                }
                                return true;
                              },
                              onDismissed: (_) => _deleteLog(log),
                              child: Card(
                                elevation: isRead ? 0 : 2,
                                color: isRead
                                    ? Theme.of(context).cardTheme.color
                                    : Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isRead
                                      ? BorderSide.none
                                      : BorderSide(
                                          color: accent.withValues(alpha: 0.45),
                                        ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: accent.withValues(
                                      alpha: 0.12,
                                    ),
                                    child: Icon(
                                      isDanger
                                          ? Icons.dangerous
                                          : (isWarning
                                                ? Icons.warning_amber_rounded
                                                : Icons
                                                      .notifications_active_outlined),
                                      color: accent,
                                    ),
                                  ),
                                  title: Text(
                                    log['title'],
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        log['body'],
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        log['time'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: !isRead
                                      ? Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : null,
                                  onTap: () => _markAsReadLog(log),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = _activeFilter == value;
    return ChoiceChip(
      selected: isActive,
      label: Text(label),
      onSelected: (_) {
        _activeFilter = value;
        _rebuildVisibleEntries();
      },
    );
  }
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _biometricEnabled = false;
  bool _pinEnabled = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('security_settings'))),
      body: Stack(
        children: [
          const Positioned.fill(child: AppFuturisticBackground()),
          ListView(
            children: [
              SwitchListTile(
                title: Text(strings.get('enable_pin')),
                value: _pinEnabled,
                onChanged: (val) => setState(() => _pinEnabled = val),
                secondary: const Icon(Icons.lock),
              ),
              if (_pinEnabled)
                ListTile(
                  title: Text(strings.get('change_pin')),
                  leading: const Icon(Icons.pin),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.get('coming_soon'))),
                    );
                  },
                ),
              SwitchListTile(
                title: Text(strings.get('biometric')),
                value: _biometricEnabled,
                onChanged: (val) => setState(() => _biometricEnabled = val),
                secondary: const Icon(Icons.fingerprint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('help'))),
      body: Stack(
        children: [
          const Positioned.fill(child: AppFuturisticBackground()),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                strings.get('faq'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ExpansionTile(
                title: Text(strings.get('q1')),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(strings.get('a1')),
                  ),
                ],
              ),
              ExpansionTile(
                title: Text(strings.get('q2')),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(strings.get('a2')),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'support@smartsaver.com',
                  );
                  if (await canLaunchUrl(emailLaunchUri)) {
                    await launchUrl(emailLaunchUri);
                  }
                },
                icon: const Icon(Icons.email),
                label: Text(strings.get('contact_support')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<DashboardThemePalette>() ??
        DashboardThemePalette.greenSecurity;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.get('about_app')),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppFuturisticBackground()),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
            child: Column(
              children: [
                // Logo & App Name
                Hero(
                  tag: 'app_logo_hero_about',
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: palette.seedColor.withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/images/Logo.png'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.get('title'),
                  style: GoogleFonts.tajawal(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: palette.seedColor,
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 32),

                // Content Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2437).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        strings.get('about_app_desc'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Text(
                  "Designed & Developed with ❤️",
                  style: GoogleFonts.cairo(
                    color: Colors.white30,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModernGasGauge extends StatefulWidget {
  final double value;
  final double maxValue;
  final Color statusColor;
  final bool isPulsing;

  const ModernGasGauge({
    super.key,
    required this.value,
    required this.maxValue,
    required this.statusColor,
    this.isPulsing = false,
  });

  @override
  State<ModernGasGauge> createState() => _ModernGasGaugeState();
}

class _ModernGasGaugeState extends State<ModernGasGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = widget.isPulsing ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: widget.isPulsing
                  ? [
                      BoxShadow(
                        color: widget.statusColor.withValues(alpha: 0.6),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: child,
          ),
        );
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: widget.value),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
        builder: (context, animatedValue, child) {
          final percent = (animatedValue / widget.maxValue).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(260, 260),
                painter: _ArcGaugePainter(
                  value: percent,
                  color: widget.statusColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${animatedValue.toInt()} PPM',
                    style: TextStyle(
                      color: widget.statusColor,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).get('gas_level_gauge'),
                    style: TextStyle(
                      color: widget.statusColor.withValues(alpha: 0.7),
                      fontSize: 14,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  _ArcGaugePainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const startAngle = 135 * math.pi / 180;
    const sweepAngle = 270 * math.pi / 180;

    final trackPaint = Paint()
      ..color = const Color(0xFF1A2437)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [color.withValues(alpha: 0.7), color],
    );
    final progressPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    final progressSweep = sweepAngle * value.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressSweep,
      false,
      progressPaint,
    );

    final dotPaint = Paint()..color = color;
    final dotAngle = startAngle + progressSweep;
    final dotX = center.dx + radius * math.cos(dotAngle);
    final dotY = center.dy + radius * math.sin(dotAngle);
    canvas.drawCircle(Offset(dotX, dotY), 8, dotPaint);
    canvas.drawCircle(Offset(dotX, dotY), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class CarSpeedometerGauge extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color statusColor;

  const CarSpeedometerGauge({
    super.key,
    required this.value,
    required this.maxValue,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF151515), // خلفية داكنة تشبه طبلون السيارة
        border: Border.all(color: const Color(0xFF333333), width: 6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(260, 260),
            painter: _CarGaugePainter(
              value: value,
              maxValue: maxValue,
              color: statusColor,
            ),
          ),
          Positioned(
            bottom: 60,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Text(
                    value.toInt().toString().padLeft(3, '0'),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 28,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'PPM',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarGaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color color;

  _CarGaugePainter({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const startAngle = 135 * math.pi / 180;
    const sweepAngle = 270 * math.pi / 180;

    // رسم التدريجات
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i <= 50; i++) {
      final percent = i / 50.0;
      final angle = startAngle + (sweepAngle * percent);
      final isMajor = i % 5 == 0;

      final outerRadius = radius - 5;
      final innerRadius = outerRadius - (isMajor ? 15 : 8);

      // تلوين المناطق (أحمر للخطر)
      Color tickColor = Colors.white;
      if (percent > 0.8) {
        tickColor = Colors.red;
      } else if (percent > 0.5) {
        tickColor = Colors.orange;
      }

      tickPaint.color = isMajor ? tickColor : tickColor.withValues(alpha: 0.5);
      tickPaint.strokeWidth = isMajor ? 2.5 : 1;

      final p1 = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);

      if (isMajor && i % 10 == 0) {
        final val = (maxValue * percent).toInt();
        textPainter.text = TextSpan(
          text: '$val',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        final tp = Offset(
          center.dx +
              (innerRadius - 15) * math.cos(angle) -
              textPainter.width / 2,
          center.dy +
              (innerRadius - 15) * math.sin(angle) -
              textPainter.height / 2,
        );
        textPainter.paint(canvas, tp);
      }
    }

    // رسم المؤشر
    final needleAngle =
        startAngle + (sweepAngle * (value / maxValue).clamp(0.0, 1.0));
    final needleLen = radius - 25;
    final needleEnd = Offset(
      center.dx + needleLen * math.cos(needleAngle),
      center.dy + needleLen * math.sin(needleAngle),
    );

    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF222222));
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = Colors.grey.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, 3, Paint()..color = Colors.redAccent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FuturisticGaugePainter extends CustomPainter {
  final double value; // 0 to 100
  final Color color;
  _FuturisticGaugePainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const startAngle = 135 * math.pi / 180;
    const sweepAngle = 270 * math.pi / 180;

    // 1. Background Track (Darker, thinner)
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.05);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. Ticks (Futuristic scale)
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final activeTickPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    int totalTicks = 40;
    for (int i = 0; i <= totalTicks; i++) {
      final percent = i / totalTicks;
      final angle = startAngle + (sweepAngle * percent);
      final isMajor = i % 5 == 0;
      final tickLen = isMajor ? 15.0 : 8.0;
      final tickOffset = 30.0;

      final p1 = Offset(
        center.dx + (radius - tickOffset) * math.cos(angle),
        center.dy + (radius - tickOffset) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - tickOffset - tickLen) * math.cos(angle),
        center.dy + (radius - tickOffset - tickLen) * math.sin(angle),
      );

      bool isActive = percent <= (value / 100);
      canvas.drawLine(p1, p2, isActive ? activeTickPaint : tickPaint);
    }

    // 3. Gradient Arc
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [color, color.withValues(alpha: 0.6)],
      stops: const [0.0, 1.0],
      transform: GradientRotation(math.pi / 2),
    );

    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    double displayValue = value == 0 ? 0.01 : value;
    final progress = (displayValue / 100).clamp(0.0, 1.0);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = color.withValues(alpha: 0.4);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        glowPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        valuePaint,
      );

      // 4. Indicator Dot
      final endAngle = startAngle + (sweepAngle * progress);
      final dotCenter = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );
      canvas.drawCircle(dotCenter, 8, Paint()..color = Colors.white);
      canvas.drawCircle(
        dotCenter,
        12,
        Paint()..color = color.withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'title': 'Gas Detector',
      'home': 'Home',
      'dark_mode': 'Dark Mode',
      'sensors': 'Sensors',
      'stats': 'Stats',
      'settings': 'Settings',
      'current_gas': 'Current Gas Level',
      'status_safe': 'Status: Safe',
      'status_warning': 'Status: Warning',
      'test': 'Test',
      'reset': 'Reset',
      'logs': 'Logs',
      'emergency': 'Emergency',
      'recent_alerts': 'Recent Alerts',
      'system_check': 'System Check',
      'normal': 'Normal',
      'kitchen_sensor': 'Kitchen Sensor',
      'warning': 'Warning',
      'add_sensor': 'Add New Sensor',
      'kitchen': 'Kitchen',
      'garage': 'Garage',
      'safe': 'Safe',
      'status_label': 'Status',
      'gas_levels': 'Gas Levels (PPM)',
      'avg_level': 'Average Level',
      'peak_level': 'Peak Level',
      'min_level': 'Minimum Level',
      'profile': 'Profile',
      'notifications': 'Notifications',
      'security': 'Security',
      'help': 'Help & Support',
      'logout': 'Logout',
      'change_language': 'Change Language (العربية)',
      'alert_threshold': 'Alert Threshold',
      'history_title': 'Alert History',
      'notification_details': 'Notification Details',
      'notification_type': 'Type',
      'no_details': 'No additional details',
      'open_history': 'Open History',
      'go_to_emergency': 'Go To Emergency',
      'no_alerts_yet': 'No alerts recorded yet.',
      'alert_message': 'Gas level high:',
      'test_running': 'Running System Test...',
      'coming_soon': 'Coming Soon',
      'are_you_sure': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'logout_success': 'Logged out successfully',
      'save': 'Save',
      'enter_name': 'Name',
      'name_saved': 'Name saved successfully',
      'add': 'Add',
      'sensor_added': 'Sensor Added',
      'reading_from': 'Reading from',
      'selected': 'Selected',
      'delete_sensor': 'Delete Sensor',
      'confirm_delete_sensor': 'Are you sure you want to delete this sensor?',
      'delete': 'Delete',
      'no_sensors': 'No Sensors',
      'edit_sensor': 'Edit Sensor',
      'manual_test_value': 'Manual Test Value',
      'manual': 'Manual',
      'automatic': 'Automatic',
      'test_mode': 'Test Mode',
      'gas_leak_detected': 'GAS LEAK DETECTED!',
      'call_emergency': 'Call Emergency',
      'open_windows': 'Open Windows',
      'dismiss': 'Dismiss',
      'status_safe_hero': '??? Status: Safe',
      'status_warning_hero': '?? Warning: Potential Leak',
      'status_danger_hero': '?? DANGER: GAS LEAK!',
      'action_safe_btn': 'View Details',
      'action_warning_btn': 'What to do?',
      'action_danger_btn': 'Immediate Instructions',
      'emergency_call': 'Emergency',
      'tips_warning': 'Ensure ventilation. Check gas valves.',
      'tips_safe': 'All systems are normal.',
      'gas_level_gauge': 'GAS LEVEL',
      'confirm_delete_history': 'Are you sure you want to clear all history?',
      'ventilating': 'Ventilating...',
      'status_safe_now': 'Safe Status',
      'mqtt_settings': 'Connection Settings',
      'broker_address': 'Broker Address',
      'topic': 'Topic',
      'port': 'Port',
      'mqtt_connected_success': 'Connected to MQTT server successfully ?',
      'mqtt_connection_failed':
          'Connection failed. Check broker address, port, and network.',
      'username': 'Username',
      'password': 'Password',
      'mqtt_bad_credentials': 'Connection failed: Bad username or password.',
      'real_sensor': 'Real Sensor',
      'gauge_style': 'Gauge Style',
      'gauge_modern': 'Modern',
      'gauge_car': 'Car Dashboard',
      'background_color': 'Background Color',
      'about_app': 'About App',
      'about_app_desc':
          'Smart Gas Saver is a smart system for monitoring gas leaks using an ESP32 unit and a gas sensor. It measures gas levels in the environment and sends data instantly to Firebase via WiFi. The app displays real-time gas levels and system status (Safe - Warning - Danger) with clear alert colors, sending immediate notifications when gas levels reach dangerous limits.\n\nThe project aims to enhance home safety and reduce gas leak risks through a real-time smart monitoring system, helping users take quick action.\n\nProject Implementation\n\nImplemented by students:\n\nSally Mashhour Al-Hourani\nBisan Anis Fakhr El-Din\nRama Mowaffaq',
      'security_settings': 'Security Settings',
      'enable_pin': 'Enable PIN',
      'change_pin': 'Change PIN',
      'biometric': 'Biometric Login',
      'faq': 'FAQ',
      'contact_support': 'Contact Support',
      'q1': 'How to connect device?',
      'a1': 'Power on the ESP32 and ensure it is connected to WiFi.',
      'q2': 'What do colors mean?',
      'a2': 'Green: Safe, Orange: Warning, Red: Danger.',
      'emergency_contact': 'Emergency Contact',
      'enter_emergency_number': 'Enter Emergency Number',
      'number_saved': 'Number saved successfully',
      'mark_all_read': 'Mark all as read',
      'search_notifications': 'Search notifications...',
      'filter_all': 'All',
      'filter_unread': 'Unread',
      'filter_danger': 'Danger',
      'filter_warning': 'Warning',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'this_week': 'This Week',
      'date_unknown': 'Unknown Date',
      'distribution_analysis': 'Distribution Analysis',
      'stats_range_1h': '1H',
      'stats_range_24h': '24H',
      'stats_range_7d': '7D',
      'stats_range_30d': '30D',
      'threshold_warning': 'Warning',
      'threshold_danger': 'Danger',
      'no_stats_data': 'No data in selected range',
      'alarm_sound': 'Alarm Sound',
      'notification_sound_settings': 'Notification Sound',
      'sound_default': 'Default (Alarm)',
      'sound_siren': 'Siren',
      'sound_beep': 'Beep',
      'sound_notify': 'Notify',
      'sound_notify_1': 'Notify 1',
      'sound_alert': 'Alert',
      'sound_alert_1': 'Alert 1',
      'sound_alert_2': 'Alert 2',
      'sound_silent': 'Silent',
      'test_sound': 'Test Sound',
      'theme': 'Theme',
      'splash_tagline': 'Your Safety Companion',
      'splash_loading_boot': 'Starting secure system...',
      'splash_loading_prefs': 'Loading preferences...',
      'splash_loading_assets': 'Preparing interface...',
      'splash_loading_failed': 'Startup failed. Please try again.',
      'smart_home_system': 'Smart Home System',
      'status_danger': 'Status: Danger',
      'gas_concentration': 'Gas Concentration',
      'live_monitoring': 'Live Monitoring',
      'live_monitor': 'Live Monitor',
      'home_msg_danger': 'Gas leak detected! Please evacuate the area.',
      'home_msg_warning': 'Slight gas rise detected, please check the area.',
      'home_msg_safe': 'System stable. No gas leak detected.',
      'latest_reading': 'Latest Reading',
      'temperature': 'Temperature',
      'connection': 'Connection',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'fab_danger_tooltip': 'Tap here',
      'fab_warning_tooltip': 'Guidance',
      'fab_safe_tooltip': 'View Stats',
      'error_prefix': 'Error',
      'tap_to_enable_alarm_sound': 'Tap to enable alarm sound',
      'activate': 'Activate',
      'retry': 'Retry',
      'restore_default_theme': 'Restore Default Theme',
      'default_theme_restored': 'Default theme restored',
      'loading': 'Loading...',
      'skip': 'Skip',
      'next': 'Next',
      'get_started': 'Get Started',
      'onboarding_title_1': 'Smart Gas Safety',
      'onboarding_body_1':
          'Monitor gas levels in real time and stay protected.',
      'onboarding_title_2': 'Instant Alerts',
      'onboarding_body_2': 'Receive emergency alerts and act quickly.',
      'onboarding_title_3': 'Easy Device Setup',
      'onboarding_body_3':
          'Configure your device and network in under a minute.',
      'setup_title': 'Initial Device Setup',
      'setup_subtitle': 'Configure device and network before continuing.',
      'setup_device_name': 'Device Name',
      'setup_network_name': 'Network Name',
      'select_network_name': 'Select Network Name',
      'network_manual_entry': 'Enter network name manually',
      'refresh_networks': 'Refresh',
      'no_networks_found': 'No networks found. You can enter name manually.',
      'setup_password_hint':
          'Wi-Fi password is entered from ESP32 WiFiManager page.',
      'advanced_setup_optional': 'Advanced Settings (Optional)',
      'test_connection': 'Test Connection',
      'setup_test_success': 'Connection test completed successfully',
      'setup_test_first': 'Please test connection first',
      'setup_test_passed': 'Connection verified',
      'setup_checking_device': 'Checking device...',
      'setup_device_connected': 'ESP32 is connected to Wi-Fi',
      'setup_device_disconnected': 'ESP32 is not connected',
      'setup_last_seen': 'Last Seen',
      'setup_latest_level': 'Latest Level',
      'setup_wifi_ssid': 'Wi-Fi SSID',
      'setup_now': 'Now',
      'setup_fill_required': 'Fill all required fields correctly',
      'setup_device_name_required': 'Please enter device name',
      'finish_setup': 'Finish Setup',
      'device_setup': 'Device Setup',
      'device_setup_desc': 'Open device setup screen',
      'rerun_setup_flow': 'Run Setup Again',
      'rerun_setup_desc': 'Reopen onboarding and initial setup flow',
      'restart_setup_title': 'Restart Initial Setup',
      'restart_setup_body':
          'This will reopen onboarding and setup screens. Continue?',
      'start_setup': 'Start Setup',
      'emergency_elapsed': 'Emergency Time',
      'emergency_checklist': 'Emergency Checklist',
      'step_open_windows': 'Open windows and improve ventilation',
      'step_stop_gas_source': 'Close gas source/valve',
      'step_exit_area': 'Exit area and avoid sparks',
      'incident_resolved': 'Incident Resolved',
      'confirm_resolved': 'Confirm ending emergency mode?',
      'yes_end': 'End',
      'no_continue': 'Continue',
      'confirm_exit_emergency': 'Exit emergency screen now?',
      'call_now': 'Call Now',
      'call_failed': 'Call failed. Please try manually.',
    },
    'ar': {
      'title': 'المنقذ الذكي',
      'home': 'الرئيسية',
      'dark_mode': 'الوضع الداكن',
      'sensors': 'الحساسات',
      'stats': 'الإحصائيات',
      'settings': 'الإعدادات',
      'current_gas': 'مستوى الغاز الحالي',
      'status_safe': 'الحالة: آمن',
      'status_warning': 'الحالة: تحذير',
      'test': 'فحص',
      'reset': 'إعادة ضبط',
      'logs': 'السجلات',
      'emergency': 'طوارئ',
      'recent_alerts': 'تنبيهات حديثة',
      'system_check': 'فحص النظام',
      'normal': 'طبيعي',
      'kitchen_sensor': 'حساس المطبخ',
      'warning': 'تحذير',
      'add_sensor': 'إضافة حساس جديد',
      'kitchen': 'المطبخ',
      'garage': 'الكراج',
      'safe': 'آمن',
      'status_label': 'الحالة',
      'gas_levels': 'مستويات الغاز (PPM)',
      'avg_level': 'المستوى المتوسط',
      'peak_level': 'أعلى مستوى',
      'min_level': 'أدنى مستوى',
      'profile': 'الملف الشخصي',
      'notifications': 'الإشعارات',
      'security': 'الأمان',
      'help': 'المساعدة والدعم',
      'logout': 'تسجيل خروج',
      'change_language': 'تغيير اللغة (English)',
      'alert_threshold': 'حد التنبيه',
      'history_title': 'سجل التنبيهات',
      'notification_details': 'تفاصيل الإشعار',
      'notification_type': 'النوع',
      'no_details': 'لا توجد تفاصيل إضافية',
      'open_history': 'فتح سجل التنبيهات',
      'go_to_emergency': 'الانتقال للطوارئ',
      'no_alerts_yet': 'لم يتم تسجيل تنبيهات بعد.',
      'alert_message': 'مستوى الغاز مرتفع:',
      'test_running': 'جاري فحص النظام...',
      'coming_soon': 'قريباً',
      'are_you_sure': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      'cancel': 'إلغاء',
      'logout_success': 'تم تسجيل الخروج بنجاح',
      'save': 'حفظ',
      'enter_name': 'الاسم',
      'name_saved': 'تم حفظ الاسم بنجاح',
      'add': 'إضافة',
      'sensor_added': 'تم إضافة الحساس',
      'reading_from': 'قراءة من',
      'selected': 'تم الاختيار',
      'delete_sensor': 'حذف الحساس',
      'confirm_delete_sensor': 'هل أنت متأكد من حذف هذا الحساس؟',
      'delete': 'حذف',
      'no_sensors': 'لا توجد حساسات',
      'edit_sensor': 'تعديل الحساس',
      'manual_test_value': 'قيمة فحص يدوية',
      'manual': 'يدوي',
      'automatic': 'تلقائي',
      'test_mode': 'وضع الاختبار',
      'gas_leak_detected': 'تم اكتشاف تسرب غاز!',
      'call_emergency': 'اتصل بالطوارئ',
      'open_windows': 'افتح النوافذ',
      'dismiss': 'تجاهل',
      'status_safe_hero': '✅ الحالة: آمن',
      'status_warning_hero': '⚠️ تحذير: تسرب محتمل',
      'status_danger_hero': '🚨 خطر: تسرب غاز!',
      'emergency_call': 'مكالمة طوارئ',
      'tips_warning': 'تأكد من التهوية. افحص صمامات الغاز.',
      'tips_safe': 'جميع الأنظمة تعمل بشكل طبيعي.',
      'gas_level_gauge': 'مستوى الغاز',
      'confirm_delete_history': 'هل أنت متأكد من مسح كل سجل التنبيهات؟',
      'ventilating': 'جاري التهوية...',
      'status_safe_now': 'الحالة آمنة',
      'mqtt_settings': 'إعدادات الاتصال',
      'broker_address': 'عنوان الخادم (Broker)',
      'topic': 'الموضوع (Topic)',
      'port': 'المنفذ (Port)',
      'mqtt_connected_success': 'تم الاتصال بالخادم بنجاح 🚀',
      'mqtt_connection_failed':
          'فشل الاتصال. تحقق من عنوان الخادم والمنفذ والشبكة.',
      'username': 'اسم المستخدم',
      'password': 'كلمة المرور',
      'mqtt_bad_credentials':
          'فشل الاتصال: اسم المستخدم أو كلمة المرور غير صحيحة.',
      'real_sensor': 'حساس حقيقي',
      'gauge_style': 'نمط العداد',
      'gauge_modern': 'حديث',
      'gauge_car': 'عداد سيارة',
      'background_color': 'لون الخلفية',
      'about_app': 'حول التطبيق',
      'about_app_desc':
          'المنقذ الذكي (Smart Gas Saver) هو نظام ذكي لمراقبة تسرب الغاز باستخدام وحدة ESP32 وحساس غاز. يقوم بقياس مستويات الغاز في البيئة وإرسال البيانات فورياً إلى Firebase عبر WiFi. يعرض التطبيق مستويات الغاز في الوقت الفعلي وحالة النظام (آمن - تحذير - خطر) بألوان تنبيه واضحة، مع إرسال إشعارات فورية عند وصول الغاز لمستويات خطرة.\n\nيهدف المشروع لتعزيز الأمان المنزلي وتقليل مخاطر تسرب الغاز عبر نظام مراقبة ذكي ولحظي يساعد المستخدمين على اتخاذ إجراءات سريعة.\n\nتنفيذ المشروع\n\nتم التنفيذ بواسطة الطلاب:\n\nسالي مشهور الحوراني\nبيسان أنيس فخر الدين\nراما موفق',
      'security_settings': 'إعدادات الأمان',
      'enable_pin': 'تفعيل رمز المرور',
      'change_pin': 'تغيير الرمز',
      'biometric': 'الدخول بالبصمة',
      'faq': 'الأسئلة الشائعة',
      'contact_support': 'تواصل مع الدعم',
      'q1': 'كيفية توصيل الجهاز؟',
      'a1': 'قم بتشغيل ESP32 وتأكد من اتصاله بالواي فاي.',
      'q2': 'ماذا تعني الألوان؟',
      'a2': 'أخضر: آمن، برتقالي: تحذير، أحمر: خطر.',
      'emergency_contact': 'رقم الطوارئ',
      'enter_emergency_number': 'أدخل رقم الطوارئ',
      'number_saved': 'تم حفظ الرقم بنجاح',
      'mark_all_read': 'تحديد الكل كمقروء',
      'search_notifications': 'بحث في الإشعارات...',
      'filter_all': 'الكل',
      'filter_unread': 'غير مقروء',
      'filter_danger': 'خطر',
      'filter_warning': 'تحذير',
      'today': 'اليوم',
      'yesterday': 'أمس',
      'this_week': 'هذا الأسبوع',
      'date_unknown': 'تاريخ غير معروف',
      'distribution_analysis': 'تحليل التوزيع',
      'stats_range_1h': 'ساعة واحدة',
      'stats_range_24h': '24 ساعة',
      'stats_range_7d': '7 أيام',
      'stats_range_30d': '30 يوم',
      'threshold_warning': 'حد التحذير',
      'threshold_danger': 'حد الخطر',
      'no_stats_data': 'لا توجد بيانات في النطاق المحدد',
      'alarm_sound': 'نغمة التنبيه',
      'notification_sound_settings': 'نغمة الإشعارات',
      'sound_default': 'الافتراضي (منبه)',
      'sound_siren': 'سارينة',
      'sound_beep': 'صفارة',
      'sound_notify': 'إشعار',
      'sound_notify_1': 'إشعار 1',
      'sound_alert': 'تنبيه قصير',
      'sound_alert_1': 'تنبيه 1',
      'sound_alert_2': 'تنبيه 2',
      'sound_silent': 'صامت',
      'test_sound': 'تجربة الصوت',
      'theme': 'السمة',
      'splash_tagline': 'رفيقك للأمان',
      'splash_loading_boot': 'بدء تشغيل النظام الآمن...',
      'splash_loading_prefs': 'تحميل التفضيلات...',
      'splash_loading_assets': 'تجهيز الواجهة...',
      'splash_loading_failed': 'فشل بدء التشغيل. يرجى المحاولة مرة أخرى.',
      'smart_home_system': 'نظام المنزل الذكي',
      'status_danger': 'الحالة: خطر',
      'gas_concentration': 'تركيز الغاز',
      'live_monitoring': 'المراقبة الحية',
      'live_monitor': 'مراقب حي',
      'home_msg_danger': 'تم اكتشاف تسرب غاز! يرجى إخلاء المكان.',
      'home_msg_warning': 'ارتفاع طفيف في نسبة الغاز، يرجى التحقق.',
      'home_msg_safe': 'النظام مستقر. لا يوجد تسرب غاز.',
      'latest_reading': 'آخر قراءة',
      'temperature': 'درجة الحرارة',
      'connection': 'الاتصال',
      'connected': 'متصل',
      'disconnected': 'غير متصل',
      'fab_danger_tooltip': 'اضغط هنا',
      'fab_warning_tooltip': 'توجيهات',
      'fab_safe_tooltip': 'عرض الإحصائيات',
      'error_prefix': 'خطأ',
      'tap_to_enable_alarm_sound': 'اضغط لتفعيل صوت التنبيه',
      'activate': 'تفعيل',
      'retry': 'إعادة المحاولة',
      'restore_default_theme': 'استعادة السمة الافتراضية',
      'default_theme_restored': 'تم استعادة السمة الافتراضية',
      'loading': 'جاري التحميل...',
      'skip': 'تخطي',
      'next': 'التالي',
      'get_started': 'ابدأ الآن',
      'onboarding_title_1': 'أمان الغاز الذكي',
      'onboarding_body_1': 'راقب مستويات الغاز في الوقت الفعلي وابق آمناً.',
      'onboarding_title_2': 'تنبيهات فورية',
      'onboarding_body_2': 'استقبل تنبيهات الطوارئ وتصرف بسرعة.',
      'onboarding_title_3': 'إعداد سهل للجهاز',
      'onboarding_body_3': 'قم بتهيئة جهازك والشبكة في أقل من دقيقة.',
      'setup_title': 'إعداد الجهاز الأولي',
      'setup_subtitle': 'قم بتهيئة الجهاز والشبكة قبل المتابعة.',
      'setup_device_name': 'اسم الجهاز',
      'setup_network_name': 'اسم الشبكة',
      'select_network_name': 'اختر اسم الشبكة',
      'network_manual_entry': 'إدخال اسم الشبكة يدوياً',
      'refresh_networks': 'تحديث',
      'no_networks_found': 'لم يتم العثور على شبكات. يمكنك إدخال الاسم يدوياً.',
      'setup_password_hint':
          'يتم إدخال كلمة مرور الواي فاي من صفحة WiFiManager الخاصة بـ ESP32.',
      'advanced_setup_optional': 'إعدادات متقدمة (اختياري)',
      'test_connection': 'اختبار الاتصال',
      'setup_test_success': 'تم اختبار الاتصال بنجاح',
      'setup_test_first': 'يرجى اختبار الاتصال أولاً',
      'setup_test_passed': 'تم التحقق من الاتصال',
      'setup_checking_device': 'جاري فحص الجهاز...',
      'setup_device_connected': 'ESP32 متصل بالواي فاي',
      'setup_device_disconnected': 'ESP32 غير متصل',
      'setup_last_seen': 'آخر ظهور',
      'setup_latest_level': 'آخر مستوى',
      'setup_wifi_ssid': 'شبكة الواي فاي',
      'setup_now': 'الآن',
      'setup_fill_required': 'يرجى ملء جميع الحقول المطلوبة بشكل صحيح',
      'setup_device_name_required': 'يرجى إدخال اسم الجهاز',
      'finish_setup': 'إنهاء الإعداد',
      'device_setup': 'إعداد الجهاز',
      'device_setup_desc': 'فتح شاشة إعداد الجهاز',
      'rerun_setup_flow': 'تشغيل الإعداد مرة أخرى',
      'rerun_setup_desc': 'إعادة فتح شاشات الترحيب والإعداد الأولي',
      'restart_setup_title': 'إعادة بدء الإعداد الأولي',
      'restart_setup_body':
          'سيتم إعادة فتح شاشات الترحيب والإعداد. هل تريد المتابعة؟',
      'start_setup': 'بدء الإعداد',
      'emergency_elapsed': 'وقت الطوارئ',
      'emergency_checklist': 'قائمة الطوارئ',
      'step_open_windows': 'فتح النوافذ وتحسين التهوية',
      'step_stop_gas_source': 'إغلاق مصدر الغاز/الصمام',
      'step_exit_area': 'الخروج من المنطقة وتجنب الشرر',
      'incident_resolved': 'تم حل الحادث',
      'confirm_resolved': 'هل تؤكد انتهاء حالة الطوارئ؟',
      'yes_end': 'نعم، إنهاء',
      'no_continue': 'لا، متابعة',
      'confirm_exit_emergency': 'هل تريد الخروج من شاشة الطوارئ الآن؟',
      'call_now': 'اتصل الآن',
      'call_failed': 'فشل الاتصال. يرجى المحاولة يدوياً.',
    },
  };

  String get(String key) => _localizedValues[locale.languageCode]![key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static const String _serviceChannelId = 'gas_alert_channel';
  static const String _serviceChannelName = 'Gas Detector Service';
  static const String _alertsChannelVersion = 'v4';

  static Future<void> init({bool requestPermissions = false, bool isBackground = false}) async {
    if (_isInitialized) {
      return;
    }
    // Initialize for Android (using default app icon)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    // 2. تحديث تهيئة الإشعارات للتعامل مع النقر
    await _notificationsPlugin.initialize(
      initializationSettings,
      // في الخلفية، لا نسجل دالة الاستجابة لأنها تتطلب navigatorKey وقد تسبب انهياراً
      onDidReceiveNotificationResponse: isBackground ? null : (NotificationResponse response) {
        if (navigatorKey.currentState == null) {
          return;
        }
        Map<String, dynamic> payload = {};
        try {
          payload = response.payload == null
              ? {}
              : (jsonDecode(response.payload!) as Map<String, dynamic>);
        } catch (_) {}
        final type = _notificationTypeFromPayload(
          data: payload,
          title: payload['title']?.toString(),
          body: payload['body']?.toString(),
        );
        final gasLevel = _gasLevelFromPayload(
          data: payload,
          body: payload['body']?.toString(),
        );
        if (type == 'danger') {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => EmergencyScreen(
                initialGasLevel: gasLevel > 0 ? gasLevel : 60.0,
                threshold: 50.0,
                onGasLevelChanged: (v) {},
              ),
            ),
          );
        } else {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => NotificationDetailsScreen(
                title: payload['title']?.toString() ?? 'تنبيه',
                body: payload['body']?.toString() ?? '',
                type: type,
                gasLevel: gasLevel,
              ),
            ),
          );
        }
      },
    );

    // Ensure the foreground-service notification channel exists before
    // flutter_background_service starts on Android 8+.
    const AndroidNotificationChannel serviceChannel =
        AndroidNotificationChannel(
          _serviceChannelId,
          _serviceChannelName,
          description: 'Background monitoring service status',
          importance: Importance.low,
        );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(serviceChannel);

    const AndroidNotificationChannel defaultChannel =
        AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
        );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(defaultChannel);

    if (requestPermissions) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _isInitialized = true;
  }

  static Future<void> showNotification(
    String title,
    String body, {
    String? sound,
    Map<String, dynamic>? payload,
    bool forceInClosedOnlyMode = false,
  }) async {
    if (kFirebaseClosedOnlyNotifications && !forceInClosedOnlyMode) {
      return;
    }
    if (!_isInitialized) {
      try {
        await init();
      } catch (e) {
        debugPrint('NotificationService lazy init failed: $e');
      }
    }
    // تنظيف اسم الملف من الامتداد لأن أندرويد يتطلب الاسم فقط في المجلد raw
    String soundName = sound ?? 'alarm';
    bool playSound = true;
    if (soundName == 'silent' || soundName == 'none') {
      playSound = false;
    }
    if (playSound && soundName.contains('.')) {
      soundName = soundName.split('.').first.toLowerCase();
    }

    // قناة الإصدار v2 تجبر أندرويد على استخدام إعدادات الصوت الجديدة حتى لو
    // كانت قناة قديمة مكتومة/بدون صوت محفوظة من إصدار سابق.
    String channelId = 'gas_alert_channel_${soundName}_$_alertsChannelVersion';
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final alertsChannel = AndroidNotificationChannel(
        channelId,
        'Gas Alerts ($soundName)',
        description: 'High gas level alerts with custom sound',
        importance: Importance.max,
        playSound: playSound,
        sound: playSound ? RawResourceAndroidNotificationSound(soundName) : null,
      );
      await androidPlugin.createNotificationChannel(alertsChannel);
    }

    final mergedPayload = <String, dynamic>{
      'title': title,
      'body': body,
      if (payload != null) ...payload,
    };
    final type = _notificationTypeFromPayload(
      data: mergedPayload,
      title: title,
      body: body,
    );
    // تحديد اسم الأيقونة بناءً على النوع (يجب إضافة الصور في مجلد android/app/src/main/res/drawable)
    final String resourceName = switch (type) {
      'danger' => 'ic_notification_danger',
      'warning' => 'ic_notification_warning',
      _ => '@mipmap/ic_launcher', // الأيقونة الافتراضية للحالات العادية
    };
    final Color accentColor = switch (type) {
      'danger' => Colors.red,
      'warning' => Colors.orange,
      _ => Colors.blue,
    };

    // تحويل اللون إلى Hex لاستخدامه في تنسيق HTML
    final String colorHex = '#${accentColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

    // إعداد نمط النص الكبير لدعم HTML وتلوين العنوان
    final BigTextStyleInformation bigTextStyleInformation =
        BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: '<font color="$colorHex"><b>$title</b></font>',
      htmlFormatContentTitle: true,
      // إضافة ملخص ملون يظهر بجانب العنوان (طريقة بديلة لتمييز الحالة باستخدام SpannableString)
      summaryText: '<font color="$colorHex"><b>${type.toUpperCase()}</b></font>',
      htmlFormatSummaryText: true,
    );

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      'Gas Alerts ($soundName)',
      channelDescription: 'High gas level alerts with custom sound',
      importance: Importance.max,
      priority: Priority.high,
      color: accentColor,
      styleInformation: bigTextStyleInformation, // تطبيق التنسيق الملون
      // إعدادات التمييز اللوني والبصري
      ledColor: accentColor,
      ledOnMs: 1000,
      ledOffMs: 500,
      enableLights: true,
      icon: resourceName, // الأيقونة الصغيرة (تظهر في شريط الحالة)
      largeIcon: DrawableResourceAndroidBitmap(resourceName), // أيقونة كبيرة ملونة تظهر بجانب النص
      sound: playSound ? RawResourceAndroidNotificationSound(soundName) : null,
      playSound: playSound,
    );
    NotificationDetails details = NotificationDetails(android: androidDetails);
    try {
      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: jsonEncode(mergedPayload),
      );
    } catch (e) {
      debugPrint('Error showing notification with custom sound: $e');
      // Fallback to default sound if custom sound resource is missing (e.g. raw/alarm.mp3)
      if (e.toString().contains('invalid_sound')) {
        debugPrint('Falling back to default notification sound');
        AndroidNotificationDetails fallbackAndroidDetails =
            AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          color: accentColor,
          styleInformation: bigTextStyleInformation,
          ledColor: accentColor,
          ledOnMs: 1000,
          ledOffMs: 500,
          enableLights: true,
          icon: resourceName,
          largeIcon: DrawableResourceAndroidBitmap(resourceName),
        );
        await _notificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title,
          body,
          NotificationDetails(android: fallbackAndroidDetails),
          payload: jsonEncode(mergedPayload),
        );
      }
    }
  }

  static Future<void> clearAll() async {
    await _notificationsPlugin.cancelAll();
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();
  if (isRunning) {
    return;
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'gas_alert_channel',
      initialNotificationTitle: 'Gas Detector Service',
      initialNotificationContent: 'Monitoring gas levels...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    ui.DartPluginRegistrant.ensureInitialized();

    // هام جداً: تهيئة الإشعارات أولاً لإنشاء القناة (Channel) قبل محاولة استخدامها
    try {
      // نمرر isBackground: true لمنع تسجيل دوال الواجهة
      await NotificationService.init(isBackground: true);
    } catch (e) {
      debugPrint("Notification init failed in background: $e");
    }

    // الآن يمكننا عرض الإشعار بأمان لأن القناة موجودة
    if (service is AndroidServiceInstance) {
      try {
        await service.setForegroundNotificationInfo(
          title: 'Gas Detector',
          content: 'Starting service...',
        );
      } catch (e) {
        debugPrint("Failed to set foreground info: $e");
      }
    }

    final prefs = await SharedPreferences.getInstance();

    // تهيئة Firebase في الخلفية
    final firebaseReady = await _ensureFirebaseInitialized();
    if (!firebaseReady) {
      debugPrint("Background service stopped: Firebase is not initialized.");
      return;
    }

    service.on('sync_prefs').listen((event) async {
      await prefs.reload();
    });

    // الاستماع لقيمة الغاز الحقيقية من قاعدة البيانات بدلاً من المحاكاة
    DatabaseReference ref = FirebaseDatabase.instance.ref(
      'home/gas_sensor/level',
    );

    ref.onValue.listen(
      (event) async {
        final val = event.snapshot.value;
        if (val == null) return;

        try {
          final double currentGasLevel = double.tryParse(val.toString()) ?? 0.0;

          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: 'المنقذ الذكي',
                content: 'مستوى الغاز الحالي: ${currentGasLevel.toInt()} PPM',
              );
            }
          }

          await prefs.reload();
          String sound =
              prefs.getString('notification_sound') ??
              'alarm.mp3'; // جلب النغمة المحفوظة في الخلفية

          final decision = await _evaluateGasAlertDecision(
            prefs,
            currentGasLevel,
          );
          if (!decision.shouldNotify) {
            service.invoke('update', {'gas_level': currentGasLevel});
            return;
          }

          // منطق الإشعارات (أحمر وبرتقالي)
          if (decision.status == 'danger') {
            // حالة الخطر (أحمر)
            await NotificationService.showNotification(
              'خطر غاز - Danger',
              'تسرب غاز! المستوى: ${currentGasLevel.toInt()} PPM',
              sound: sound,
              payload: {'type': 'danger', 'gas_level': currentGasLevel},
            );

            List<String> history = prefs.getStringList('alert_history') ?? [];
            final timestamp = DateFormat(
              'yyyy-MM-dd HH:mm:ss',
            ).format(DateTime.now());

            // إضافة للسجل (نتجنب التكرار المفرط بنفس الثانية)
            bool isDuplicate = false;
            if (history.isNotEmpty && history.first.contains(timestamp)) {
              isDuplicate = true;
            }

            if (!isDuplicate) {
              Map<String, dynamic> notificationData = {
                'title': 'خطر غاز - Danger',
                'body': 'تسرب غاز! المستوى: ${currentGasLevel.toInt()} PPM',
                'type': 'danger',
                'gasLevel': currentGasLevel,
                'time': timestamp,
                'isRead': false,
              };
              history.insert(0, jsonEncode(notificationData));
              if (history.length > 300) {
                history.removeRange(300, history.length);
              }

              await prefs.setStringList('alert_history', history);
              service.invoke('history_updated');
            }
          } else if (decision.status == 'warning') {
            // حالة التحذير (برتقالي)
            await NotificationService.showNotification(
              'تنبيه تحذير - Warning',
              'مستوى الغاز مرتفع: ${currentGasLevel.toInt()} PPM',
              sound: sound,
              payload: {'type': 'warning', 'gas_level': currentGasLevel},
            );

            List<String> history = prefs.getStringList('alert_history') ?? [];
            final timestamp = DateFormat(
              'yyyy-MM-dd HH:mm:ss',
            ).format(DateTime.now());

            bool isDuplicate = false;
            if (history.isNotEmpty && history.first.contains(timestamp)) {
              isDuplicate = true;
            }

            if (!isDuplicate) {
              Map<String, dynamic> notificationData = {
                'title': 'تنبيه تحذير - Warning',
                'body': 'مستوى الغاز مرتفع: ${currentGasLevel.toInt()} PPM',
                'type': 'warning',
                'gasLevel': currentGasLevel,
                'time': timestamp,
                'isRead': false,
              };
              history.insert(0, jsonEncode(notificationData));
              if (history.length > 300) {
                history.removeRange(300, history.length);
              }
              await prefs.setStringList('alert_history', history);
              service.invoke('history_updated');
            }
          }

          service.invoke('update', {'gas_level': currentGasLevel});
        } catch (e) {
          debugPrint("Error inside background listener: $e");
        }
      },
      onError: (error) {
        debugPrint("Error in background DB listener: $error");
      },
    );
  } catch (e) {
    debugPrint("Error in background service onStart: $e");
  }
}

class NotificationDetailsScreen extends StatelessWidget {
  const NotificationDetailsScreen({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    required this.gasLevel,
  });

  final String title;
  final String body;
  final String type;
  final double gasLevel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final isDanger = type == 'danger';
    final isWarning = type == 'warning';
    final canOpenEmergency = isDanger || gasLevel >= 50;
    final accent = isDanger
        ? Colors.red
        : (isWarning ? Colors.orange : Theme.of(context).colorScheme.primary);
    final icon = isDanger
        ? Icons.dangerous
        : (isWarning
              ? Icons.warning_amber_rounded
              : Icons.notifications_active_outlined);

    return Scaffold(
      appBar: AppBar(title: Text(strings.get('notification_details'))),
      body: Stack(
        children: [
          const Positioned.fill(child: AppFuturisticBackground()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).cardTheme.color?.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.15),
                        child: Icon(icon, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).cardTheme.color?.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    body.isEmpty ? strings.get('no_details') : body,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).cardTheme.color?.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${strings.get('notification_type')}: ${type.toUpperCase()}',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${strings.get('current_gas')}: ${gasLevel.toInt()} PPM',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final logs =
                            (prefs.getStringList('alert_history') ?? [])
                                .take(150)
                                .toList(growable: false);
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoryScreen(
                              logs: logs,
                              onClear: () async {
                                final p = await SharedPreferences.getInstance();
                                await p.remove('alert_history');
                                await NotificationService.clearAll();
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: Text(strings.get('open_history')),
                    ),
                    if (canOpenEmergency)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EmergencyScreen(
                                initialGasLevel: gasLevel > 0 ? gasLevel : 60.0,
                                threshold: 50.0,
                                onGasLevelChanged: (v) {},
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.emergency_share_rounded),
                        label: Text(strings.get('go_to_emergency')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmergencyScreen extends StatefulWidget {
  final double initialGasLevel;
  final double threshold;
  final ValueChanged<double> onGasLevelChanged;

  const EmergencyScreen({
    super.key,
    required this.initialGasLevel,
    required this.threshold,
    required this.onGasLevelChanged,
  });

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _currentLevel;
  bool _isVentilating = false;
  int _totalVentilationTime = 60;
  int _remainingTime = 60;
  Timer? _ventilationTimer;
  Timer? _emergencyTimer;
  bool _isSafe = false;
  int _elapsedSeconds = 0;
  String _emergencyNumber = '911';
  bool _stepOpenWindows = false;
  bool _stepStopGas = false;
  bool _stepExitArea = false;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.initialGasLevel;
    _isSafe = _currentLevel < 6.0;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _emergencyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
    _loadEmergencyNumber();
  }

  @override
  void dispose() {
    _controller.dispose();
    _ventilationTimer?.cancel();
    _emergencyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEmergencyNumber() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _emergencyNumber = prefs.getString('emergency_number') ?? '911';
    });
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _allStepsDone => _stepOpenWindows && _stepStopGas && _stepExitArea;

  void _startVentilation() {
    if (_isVentilating || _isSafe) {
      return;
    }
    setState(() {
      _isVentilating = true;
      _stepOpenWindows = true;
      _remainingTime = _currentLevel.toInt();
      _totalVentilationTime = _remainingTime;
    });

    _ventilationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;

          // Decrease gas level logic
          _currentLevel -= 1.0;

          // Force safe status logic removed as 5 is now naturally safe
          if (_remainingTime == 5) {
            // _currentLevel is already 5 here, which is now Safe (Green)
          }

          if (_currentLevel < 0) {
            _currentLevel = 0;
          }

          widget.onGasLevelChanged(_currentLevel);

          if (_currentLevel < 6.0) {
            _isSafe = true;
          }
        } else {
          timer.cancel();
          _isVentilating = false;
        }
      });
    });
  }

  Future<void> _callEmergency() async {
    final success = await FlutterPhoneDirectCaller.callNumber(_emergencyNumber);
    if (!mounted || success == true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).get('call_failed'))),
    );
  }

  Future<void> _confirmResolveAndExit() async {
    if (!mounted) return;
    final strings = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.get('incident_resolved')),
        content: Text(strings.get('confirm_resolved')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.get('no_continue')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.get('yes_end')),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      widget.onGasLevelChanged(0);
      gasLevelResetNotifier.value = 0;
      Navigator.pop(context);
    }
  }

  Future<void> _confirmBackNavigation() async {
    if (!mounted) return;
    final strings = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.get('emergency')),
        content: Text(strings.get('confirm_exit_emergency')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.get('no_continue')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.get('yes_end')),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.pop(context);
    }
  }

  Color _getBackgroundColor() {
    if (_isSafe) {
      return Colors.green;
    }
    if (_isVentilating && _remainingTime <= 30 && _remainingTime > 5) {
      return Colors.orange;
    }
    if (_currentLevel > 50.0) {
      return const Color(0xFFB71C1C);
    } // Deep Red
    if (_currentLevel >= 6.0) {
      return Colors.orange;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final bgColor = _getBackgroundColor();
    final levelPercent = (_currentLevel / 100).clamp(0.0, 1.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmBackNavigation();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: 0.15 - (_controller.value * 0.1),
                    ),
                  ),
                  width: 300 + (_controller.value * 100),
                  height: 300 + (_controller.value * 100),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${strings.get('emergency_elapsed')}: ${_formatDuration(_elapsedSeconds)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_currentLevel.toInt()} PPM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: levelPercent,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Icon(
                              _isSafe
                                  ? Icons.check_circle_outline
                                  : Icons.warning_amber_rounded,
                              size: 110,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _isSafe
                                  ? strings.get('status_safe_now')
                                  : strings.get('gas_leak_detected'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.phone_in_talk,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${strings.get('emergency_contact')}: $_emergencyNumber',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _callEmergency,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFFB71C1C),
                                    ),
                                    child: Text(strings.get('call_now')),
                                  ),
                                ],
                              ),
                            ),
                            if (_isVentilating && !_isSafe) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      strings.get('ventilating'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    LinearProgressIndicator(
                                      value: _totalVentilationTime <= 0
                                          ? 0
                                          : 1.0 -
                                                (_remainingTime /
                                                    _totalVentilationTime),
                                      backgroundColor: Colors.white24,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_remainingTime}s',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            if (!_isSafe)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildEmergencyAction(
                                    context,
                                    Icons.phone_in_talk,
                                    strings.get('call_emergency'),
                                    () {
                                      _callEmergency();
                                    },
                                  ),
                                  _buildEmergencyAction(
                                    context,
                                    Icons.sensor_window,
                                    strings.get('open_windows'),
                                    _startVentilation,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.get('emergency_checklist'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  CheckboxListTile(
                                    value: _stepOpenWindows,
                                    onChanged: (v) => setState(
                                      () => _stepOpenWindows = v ?? false,
                                    ),
                                    title: Text(
                                      strings.get('step_open_windows'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    checkColor: const Color(0xFFB71C1C),
                                    activeColor: Colors.white,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  CheckboxListTile(
                                    value: _stepStopGas,
                                    onChanged: (v) => setState(
                                      () => _stepStopGas = v ?? false,
                                    ),
                                    title: Text(
                                      strings.get('step_stop_gas_source'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    checkColor: const Color(0xFFB71C1C),
                                    activeColor: Colors.white,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  CheckboxListTile(
                                    value: _stepExitArea,
                                    onChanged: (v) => setState(
                                      () => _stepExitArea = v ?? false,
                                    ),
                                    title: Text(
                                      strings.get('step_exit_area'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    checkColor: const Color(0xFFB71C1C),
                                    activeColor: Colors.white,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: (_isSafe || _allStepsDone)
                                  ? _confirmResolveAndExit
                                  : null,
                              icon: const Icon(Icons.verified_rounded),
                              label: Text(strings.get('incident_resolved')),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFB71C1C),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _confirmBackNavigation,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: Text(
                                strings.get('dismiss'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 48, color: const Color(0xFFB71C1C)),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
