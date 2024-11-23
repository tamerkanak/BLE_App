import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(BLEApp());
}

class BLEApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BLEHomePage(),
    );
  }
}

class BLEHomePage extends StatefulWidget {
  @override
  _BLEHomePageState createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  final FlutterBlue _flutterBlue = FlutterBlue.instance;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _detectedCommand = "";

  // BLE cihazını tara ve bağlan
  void _scanAndConnect() async {
    _flutterBlue.startScan(timeout: Duration(seconds: 5));
    _flutterBlue.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name == "ESP32") {
          // BLE cihaz adını buraya yazın
          await _flutterBlue.stopScan();
          try {
            await r.device.connect();
            setState(() {
              _connectedDevice = r.device;
            });
            _discoverServices();
          } catch (e) {
            print("Bağlantı hatası: $e");
          }
          break;
        }
      }
    });
  }

  // Servis ve özellikleri bul
  void _discoverServices() async {
    if (_connectedDevice == null) return;
    List<BluetoothService> services =
        await _connectedDevice!.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          setState(() {
            _writeCharacteristic = characteristic;
          });
        }
      }
    }
  }

  // Komut gönder
  void _sendCommand(String command) async {
    if (_writeCharacteristic != null) {
      await _writeCharacteristic!.write(command.codeUnits);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Komut gönderildi: $command")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("BLE cihazı bağlı değil!")));
    }
  }

  // Sesli komut algılama
  void _startListening() async {
    bool available = await _speechToText.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _detectedCommand = "";
      });
      _speechToText.listen(onResult: (result) {
        setState(() {
          _detectedCommand = result.recognizedWords;
        });
      });
    }
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() {
      _isListening = false;
    });
    if (_detectedCommand.isNotEmpty) {
      _sendCommand(_detectedCommand);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("BLE Komut Gönderici"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _scanAndConnect,
              child: Text("BLE Cihazına Bağlan"),
            ),
            SizedBox(height: 20),
            if (_connectedDevice != null)
              Text("Bağlı: ${_connectedDevice!.name}"),
            SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(labelText: "Komut Yazın"),
              onSubmitted: (command) {
                _sendCommand(command);
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isListening ? _stopListening : _startListening,
              child: Text(_isListening ? "Dinlemeyi Durdur" : "Sesli Komut"),
            ),
            if (_detectedCommand.isNotEmpty)
              Text("Algılanan Komut: $_detectedCommand"),
          ],
        ),
      ),
    );
  }
}
