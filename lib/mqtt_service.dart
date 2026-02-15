import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_server.dart' if (dart.library.html) 'mqtt_browser.dart';
import 'dart:math';
import 'dart:async';

class MqttService {
  MqttClient? client;
  
  final ValueNotifier<double> gasLevel = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<String> deviceStatus = ValueNotifier<String>('offline');

  // Broker details
  final String _server = 'd620f217.ala.us-east-1.emqxsl.com';
  
  // Topics
  final String _topicGas = 'home/gas_sensor/level';
  final String _topicStatus = 'home/gas_sensor/status';
  final String _topicAction = 'home/gas_sensor/action';

  Future<void> connect(String username, String password) async {
    deviceStatus.value = 'جاري الاتصال...'; // تحديث الحالة ليعلم المستخدم أن المحاولة جارية
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    final String clientId = 'flutter_client_${Random().nextInt(10000)}';
    
    // getMqttClient is imported from mqtt_server.dart or mqtt_browser.dart
    client = getMqttClient(_server, clientId);
    
    // تحديد المنفذ تلقائياً: 8083 للويب (WebSockets)، و 1883 للموبايل (TCP)
    client!.port = kIsWeb ? 8083 : 1883;

    client!.logging(on: true); // تفعيل السجلات لرؤية سبب المشكلة في الـ Console
    client!.keepAlivePeriod = 60;
    client!.onDisconnected = _onDisconnected;
    client!.onConnected = _onConnected;
    client!.onSubscribed = _onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    if (username.isNotEmpty && password.isNotEmpty) {
      connMess.authenticateAs(username, password);
    }
    
    client!.connectionMessage = connMess;

    try {
      // إضافة مهلة زمنية 10 ثوانٍ فقط، إذا لم يتصل بعدها سيظهر خطأ
      await client!.connect().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      deviceStatus.value = 'انتهت المهلة (تأكد من الإنترنت)';
      disconnect();
    } on Exception catch (e) {
      debugPrint('MQTT Client exception - $e');
      deviceStatus.value = 'خطأ: $e'; // عرض رسالة الخطأ الحقيقية
      disconnect();
    }

    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      isConnected.value = true;
      // سنقوم بالاشتراك داخل دالة _onConnected لضمان الجاهزية
    } else {
      // إذا فشل الاتصال بدون استثناء، نعرض كود الخطأ
      if (client?.connectionStatus?.returnCode != MqttConnectReturnCode.connectionAccepted) {
        deviceStatus.value = 'رفض: ${client?.connectionStatus?.returnCode}';
      }
      disconnect();
    }
  }

  void _subscribeToTopics() {
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint('Listening from: $_topicGas');
      client!.subscribe(_topicGas, MqttQos.atMostOnce);
      client!.subscribe(_topicStatus, MqttQos.atMostOnce);

      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c == null || c.isEmpty) return;
        final recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final topic = c[0].topic;

        debugPrint('DEBUG MQTT Received -> Topic: $topic, Payload: $pt');

        if (topic == _topicGas) {
          // Improved parsing: Find the first number (integer or decimal) in the string
          // تحسين استخراج الرقم: البحث عن أول رقم (صحيح أو عشري) في النص
          final RegExp regExp = RegExp(r'[0-9]+(\.[0-9]+)?');
          final match = regExp.firstMatch(pt);

          if (match != null) {
            final val = double.tryParse(match.group(0)!);
            if (val != null) {
              gasLevel.value = val;
              // If we receive gas data, the device is definitely online
              deviceStatus.value = 'online';
            }
          } else {
            debugPrint('WARNING: Could not parse gas level: "$pt"');
          }
        } else if (topic == _topicStatus) {
          deviceStatus.value = pt;
        }
      });
    }
  }

  void publishAction(String action) {
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(action);
      client!.publishMessage(_topicAction, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  void disconnect() {
    client?.disconnect();
    _onDisconnected();
  }

  void _onConnected() {
    isConnected.value = true;
    // Set status to waiting initially so user knows we are connected to broker
    deviceStatus.value = 'تم الاتصال بالخادم';
    debugPrint('MQTT Connected');
    _subscribeToTopics();
  }

  void _onDisconnected() {
    isConnected.value = false;
    deviceStatus.value = 'offline';
    debugPrint('MQTT Disconnected');
  }

  void _onSubscribed(String topic) {
    debugPrint('MQTT Subscribed to $topic');
  }
}