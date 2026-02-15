import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class FirebaseService {
  // Singleton pattern: لضمان وجود نسخة واحدة فقط من الخدمة في كامل التطبيق
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // رابط قاعدة البيانات

  // متغيرات قاعدة البيانات (قابلة لتكون null في حال فشل الاتصال)
  FirebaseDatabase? _database;
  DatabaseReference? _dbRef;
  Timer? _offlineTimer;
  
  final ValueNotifier<double> gasLevel = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String> deviceStatus = ValueNotifier<String>('offline');
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  bool _isInitialized = false;

  // تهيئة الاتصال
  Future<void> init() async {
    if (_isInitialized) {
      return;
    } // منع إعادة التهيئة إذا كانت تعمل بالفعل
    try {
      // التأكد من أن Firebase مهيأ قبل محاولة الوصول إليه
      if (Firebase.apps.isEmpty) {
        lastError.value = "Firebase لم يتم تهيئته في main.dart";
        debugPrint("❌ خطأ: لم يتم تهيئة Firebase في main.dart");
        return;
      }

      _database = FirebaseDatabase.instance;
      if (_database == null) {
        lastError.value = "فشل الحصول على نسخة قاعدة البيانات";
        return;
      }
      _dbRef = _database!.ref();

      // 1. مراقبة حالة الاتصال بالسيرفر
      _database!.ref('.info/connected').onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        isConnected.value = connected;
        // إذا انقطع اتصال التطبيق بالإنترنت، نعتبر الجهاز غير متصل
        if (!connected) {
          deviceStatus.value = 'offline';
        }
        if (connected) {
          lastError.value = null;
        }
        debugPrint(connected ? "✅ متصل بقاعدة البيانات Realtime Database" : "⚠️ انقطع الاتصال بقاعدة البيانات");
      }, onError: (error) {
        lastError.value = "خطأ في الاتصال: $error";
      });

      // مراقبة عامة للمسار للتأكد من وصول أي بيانات
      _dbRef!.child('home/gas_sensor').onValue.listen((event) {
        debugPrint("🔍 بيانات الحساس الخام: ${event.snapshot.value}");
      });

      // 3. مراقبة حالة الجهاز الفعلي (ESP32)
      // يجب أن يقوم الكود في ESP32 بكتابة "online" في هذا المسار عند الاتصال
      _dbRef!.child('home/gas_sensor/status').onValue.listen((event) {
        final status = event.snapshot.value;
        if (status != null) {
          // نعتمد على وصول البيانات لتحديد الحالة بدلاً من القيمة النصية فقط
          _resetOfflineTimer();
        }
      });

      // الاستماع لعداد الوقت (Heartbeat) للتأكد من أن الجهاز يعمل
      _dbRef!.child('home/gas_sensor/last_update').onValue.listen((event) {
        if (event.snapshot.value != null) {
          _resetOfflineTimer();
        }
      });

      // 2. الاستماع لقيمة الغاز
      _dbRef!.child('home/gas_sensor/level').onValue.listen((event) {
        final val = event.snapshot.value;
        debugPrint("🔥 القيمة المستلمة (level): $val");
        _resetOfflineTimer(); // تجديد حالة الاتصال عند استلام بيانات الغاز
        if (val != null) {
          gasLevel.value = double.tryParse(val.toString()) ?? 0.0;
          lastError.value = null;
        } else {
          // إذا كانت القيمة null، فهذا يعني أن المسار غير موجود في قاعدة البيانات
          debugPrint("⚠️ المسار home/gas_sensor/level فارغ (null)");
        }
      }, onError: (error) {
        lastError.value = "فشل القراءة: $error";
      });
      _isInitialized = true;
    } catch (e) {
      lastError.value = "فشل تهيئة الخدمة: $e";
      debugPrint("⚠️ فشل في تهيئة خدمة Firebase: $e");
    }
  }

  // دالة لمراقبة نبض الجهاز (Heartbeat)
  void _resetOfflineTimer() {
    if (deviceStatus.value != 'online') {
      deviceStatus.value = 'online';
    }
    _offlineTimer?.cancel();
    // زيادة المهلة إلى 20 ثانية ليكون أكثر استقراراً مع تقطعات الشبكة البسيطة
    // إذا لم تصل بيانات خلال 20 ثانية، نعتبر الجهاز Offline
    _offlineTimer = Timer(const Duration(seconds: 20), () {
      deviceStatus.value = 'offline';
    });
  }

  // إرسال أمر (مثل فتح النوافذ)
  void publishAction(String action) {
    _dbRef?.child('home/gas_sensor/action').set(action).catchError((e) {
      lastError.value = "فشل الإرسال: $e";
    });
  }

  // دالة فحص: تقوم بكتابة قيمة 50 في قاعدة البيانات للتأكد من أن التطبيق متصل ويعمل
  void writeTestData() {
    if (_dbRef == null) {
      lastError.value = "قاعدة البيانات غير مهيأة";
      debugPrint("❌ خطأ: قاعدة البيانات غير مهيأة أو غير متصلة.");
      return;
    }
    _dbRef?.child('home/gas_sensor/level').set(55.0).then((_) {
      lastError.value = null;
      debugPrint("✅ نجاح: تم كتابة القيمة 55.0 في قاعدة البيانات، يجب أن تظهر في التطبيق الآن");
    }).catchError((error) {
      lastError.value = "فشل الكتابة: $error";
      debugPrint("❌ فشل: لم نتمكن من الكتابة في قاعدة البيانات. السبب: $error");
    });
  }
}
