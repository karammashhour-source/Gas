import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class GasBluetoothService {
  static final GasBluetoothService _instance = GasBluetoothService._internal();
  factory GasBluetoothService() => _instance;
  GasBluetoothService._internal();

  final ValueNotifier<double> gasLevel = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<BluetoothDevice?> connectedDevice = ValueNotifier<BluetoothDevice?>(null);
  final ValueNotifier<List<ScanResult>> scanResults = ValueNotifier<List<ScanResult>>([]);
  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;

  // ملاحظة: يجب أن تتطابق هذه القيم مع UUIDs الموجودة في كود ESP32
  final String targetServiceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"; 
  
  Future<void> init() async {
    if (await FlutterBluePlus.isSupported == false) {
      debugPrint("Bluetooth not supported");
      return;
    }
  }

  Future<void> startScan() async {
    if (isScanning.value) return;
    
    scanResults.value = [];
    isScanning.value = true;

    try {
      // طلب الأذونات الضرورية (الموقع والبلوتوث) قبل البدء
      if (defaultTargetPlatform == TargetPlatform.android) {
        await [
          Permission.location,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
      }

      // محاولة تشغيل البلوتوث إذا كان مغلقاً (للأندرويد فقط)
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          debugPrint("Could not turn on Bluetooth: $e");
        }
      }

      // البحث عن الأجهزة لمدة 15 ثانية
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        // إظهار جميع الأجهزة حتى التي ليس لها اسم (قد يظهر الاسم لاحقاً أو كـ Unknown)
        scanResults.value = results;
      });
      
      await Future.delayed(const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Scan Error: $e");
    } finally {
      isScanning.value = false; 
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    isScanning.value = false;
  }

  Future<void> connect(BluetoothDevice device) async {
    await stopScan();
    
    try {
      await device.connect(autoConnect: false);
      connectedDevice.value = device;
      
      _connectionSubscription = device.connectionState.listen((BluetoothConnectionState state) {
        isConnected.value = state == BluetoothConnectionState.connected;
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice.value = null;
          _characteristicSubscription?.cancel();
        }
      });

      // استكشاف الخدمات
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
           // البحث عن الخاصية التي تدعم الإشعارات (Notify)
           if (characteristic.properties.notify) {
             await characteristic.setNotifyValue(true);
             _characteristicSubscription = characteristic.lastValueStream.listen((value) {
               _parseData(value);
             });
           }
        }
      }
    } catch (e) {
      debugPrint("Connection Error: $e");
      disconnect();
    }
  }

  void disconnect() async {
    await connectedDevice.value?.disconnect();
    connectedDevice.value = null;
    isConnected.value = false;
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
  }

  void _parseData(List<int> data) {
    try {
      String dataString = String.fromCharCodes(data);
      // استخراج الرقم من النص (مثلاً "Gas: 50.5")
      final RegExp regExp = RegExp(r'[0-9]+(\.[0-9]+)?');
      final match = regExp.firstMatch(dataString);
      if (match != null) {
        final val = double.tryParse(match.group(0)!);
        if (val != null) {
          gasLevel.value = val;
        }
      }
    } catch (e) {
      debugPrint("Error parsing BLE data: $e");
    }
  }
}