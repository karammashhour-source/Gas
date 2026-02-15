import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient getMqttClient(String server, String clientId) {
  // Use port 8883 for secure MQTT (SSL/TLS) which is standard for EMQX Cloud
  // Note: The server string should be the hostname only (e.g., 'broker.emqx.io')
  final client = MqttServerClient.withPort(server, clientId, 8883);
  client.secure = true;
  client.securityContext = SecurityContext.defaultContext;
  client.keepAlivePeriod = 20;
  client.setProtocolV311();
  return client;
}