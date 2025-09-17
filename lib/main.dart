import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

final midiCommand = MidiCommand();

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lowkey',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MidiInputScreen(), // Main widget
    );
  } 
}

class MidiInputScreen extends StatefulWidget {
  @override
  _MidiInputScreenState createState() => _MidiInputScreenState();
}

class _MidiInputScreenState extends State<MidiInputScreen> with WidgetsBindingObserver {
  // Instance Variables
  List<MidiDevice> devices = [];
  MidiDevice? connectedDevice;
  List<String> midiMessages = [];
  List<Map<String, dynamic>> bleDevices = [];
  List<String> debugLog = [];
  bool isConnecting = false;

  void log(String message) {
    final now = DateTime.now().toIso8601String();
    setState(() {
      debugLog.insert(0, "[$now] $message");
    });
  }

  @override
  void initState() {
    super.initState();
    log("Starting 0.0.30");
    MethodChannel('plugins.invisiblewrench.com/flutter_midi_command')
    .setMethodCallHandler((call) async {
      if (call.method == 'logFromNative') {
        final message = call.arguments as String;
        log("[Native] $message");
      } else if (call.method == "coreMidiDeviceReady") {
        final name = call.arguments["name"];

        final devices = await midiCommand.devices;
        MidiDevice? match;
        if (devices != null) {
          try {
            match = devices.firstWhere((d) => d.name == name);
          } catch (_) {
            match = null;
          }
        } else {
          log("Device list is null.");
        }

        if (match != null) {
          log("Auto-connecting to CoreMIDI device: ${match.name}");
          setState(() {
            isConnecting = false;
          });
          connectToDevice(match);
        } else {
          log("CoreMIDI device '$name' not found in device list.");
        }
      }
    });
    WidgetsBinding.instance.addObserver(this);
    midiCommand.startBluetoothCentral();
        midiCommand.onBleDeviceDiscovered.listen((device) {
      setState(() {
        // Avoid duplicates
        if (!bleDevices.any((d) => d['identifier'] == device['identifier'])) {
          bleDevices.add(device);
        }
      });
    });
    startScanning();
    listenForMidi();
  }

  void connectToDevice(MidiDevice device) {
    midiCommand.connectToDevice(device);
    setState(() {
      connectedDevice = device;
      midiMessages.clear(); // Clear old messages when switching devices
    });
  }

  void disconnectDevice() {
    if (connectedDevice != null) {
      midiCommand.disconnectDevice(connectedDevice!);
      setState(() {
        connectedDevice = null;
        midiMessages.clear();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startScanning();
    } else if (state == AppLifecycleState.paused) {
      midiCommand.stopScanningForBluetoothDevices();
    }
  }

  void startScanning() {
    bleDevices.clear();
    midiCommand.startScanningForBluetoothDevices();

    midiCommand.devices.then((foundDevices) {
      if (foundDevices != null) {
        setState(() {
          devices = foundDevices;
        });
      }
    });
  }

  void listenForMidi() {
    midiCommand.onMidiDataReceived?.listen((MidiPacket packet) {
      final data = packet.data;
      final timestamp = packet.timestamp;

      final message = "[$timestamp] ${data.toList()}";
      setState(() {
        midiMessages.insert(0, message); // Add to top of list
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MIDI Input Viewer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              connectedDevice != null
                  ? 'Connected to: ${connectedDevice!.name}'
                  : 'Select a MIDI device:',
              style: TextStyle(fontSize: 16),
            ),
          ),
          // Body of screen
          Expanded(
            child: connectedDevice == null
              ? Stack(
                  children: [
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            midiCommand.stopScanningForBluetoothDevices();
                            midiCommand.startBluetoothCentral();
                            midiCommand.startScanningForBluetoothDevices();

                            await Future.delayed(Duration(seconds: 2));

                            final foundDevices = await midiCommand.devices;
                            if (foundDevices != null && foundDevices.isNotEmpty) {
                              log("Found devices: ${foundDevices.map((d) => d.name).toList()}");
                              setState(() {
                                devices = foundDevices;
                              });
                            } else {
                              log("No devices found.");
                            }
                          },
                          child: Text("Scan for MIDI Devices"),
                        ),
                        Expanded(
                          child: ListView(
                            children: [
                              Text("CoreMIDI Devices:", style: TextStyle(fontWeight: FontWeight.bold)),
                              ...devices.map((device) => ListTile(
                                    title: Text(device.name),
                                    subtitle: Text(device.type),
                                    onTap: () => connectToDevice(device),
                                  )),
                              Divider(),
                              Text("Raw BLE MIDI Devices:", style: TextStyle(fontWeight: FontWeight.bold)),
                              ...bleDevices.map((device) => ListTile(
                                    title: Text(device['name']),
                                    subtitle: Text("BLE Peripheral (RSSI: ${device['rssi']})"),
                                    onTap: () async {
                                      setState(() {
                                        isConnecting = true;
                                      });
                                      await MethodChannel('plugins.invisiblewrench.com/flutter_midi_command')
                                          .invokeMethod('connectToBlePeripheral', device['identifier']);
                                    },
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isConnecting)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text("Connecting to BLE device...", style: TextStyle(fontSize: 14, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
            : Column(
              children: [
                // Back to device list button
                ElevatedButton(
                  onPressed: disconnectDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Back to Device List"),
                ),
                // Midi input list
                Expanded(
                  child: ListView.builder(
                    itemCount: midiMessages.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(midiMessages[index]),
                      );
                    },
                  ),
                ),
                // Next button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SongListScreen()),
                    );
                  },
                  child: Text("Next"),
                ),
              ],
            ),
          ),
          // Output log
          Container(
            height: 150,
            color: Colors.black,
            child: ListView.builder(
              reverse: true,
              itemCount: debugLog.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Text(
                    debugLog[index],
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SongListScreen extends StatelessWidget {
  Future<List<Map<String, String>>> loadSongManifest() async {
    final raw = await rootBundle.loadString('assets/songs/manifest.json');
    final List<dynamic> parsed = jsonDecode(raw);
    return parsed.cast<Map<String, String>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select a Song")),
      body: FutureBuilder<List<Map<String, String>>>(
        future: loadSongManifest(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final songs = snapshot.data!;
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song['title'] ?? 'Untitled'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SongTrainerScreen(filename: song['filename']!),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class SongTrainerScreen extends StatefulWidget {
  final String filename;

  SongTrainerScreen({required this.filename});

  @override
  _SongTrainerScreenState createState() => _SongTrainerScreenState();
}


class _SongTrainerScreenState extends State<SongTrainerScreen> {
  Future<void> playSong() async {
    final bytes = await rootBundle.load('assets/songs/${widget.filename}');
    final midiData = bytes.buffer.asUint8List();

    await MethodChannel('your_channel').invokeMethod('playMidiFile', {
      'bytes': midiData,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Playing: ${widget.filename}")),
      body: Center(
        child: ElevatedButton(
          onPressed: playSong,
          child: Text("Play"),
        ),
      ),
    );
  }
}