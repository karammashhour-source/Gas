import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient getMqttClient(String server, String clientId) {
  // Port 8084 is the standard WSS (WebSocket Secure) port for EMQX
  // The path '/mqtt' is required for EMQX WebSockets
  final client = MqttBrowserClient('wss://$server/mqtt', clientId);
  client.port = 8084;
  return client;
}