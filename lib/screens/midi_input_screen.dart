import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';

import 'song_list_screen.dart';
import '../controllers/color_theme_controller.dart';
import '../services/midi_service.dart';

final midiCommand = MidiService.command;

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
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();

    // Connect to Raw BLE device automatically once it is promoted
    MethodChannel('plugins.invisiblewrench.com/flutter_midi_command')
    .setMethodCallHandler((call) async {
      if (call.method == "coreMidiDeviceReady") {
        final name = call.arguments["name"];

        final devices = await midiCommand.devices;
        MidiDevice? match;
        if (devices != null) {
          try {
            match = devices.firstWhere((d) => d.name == name);
          } catch (_) {
            match = null;
          }
        }

        if (match != null) {
          setState(() {
            isConnecting = false;
          });
          connectToDevice(match);
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
                        // Use mic button - TODO: Make use mic
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.music_note),
                            label: Text("Go to Songs"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SongListScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            midiCommand.stopScanningForBluetoothDevices();
                            midiCommand.startBluetoothCentral();
                            midiCommand.startScanningForBluetoothDevices();

                            await Future.delayed(Duration(seconds: 2));

                            final foundDevices = await midiCommand.devices;
                            if (foundDevices != null && foundDevices.isNotEmpty) {
                              setState(() {
                                devices = foundDevices;
                              });
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
                                  try {
                                    await MethodChannel('plugins.invisiblewrench.com/flutter_midi_command')
                                        .invokeMethod('connectToBlePeripheral', device['identifier']);
                                  } catch (e) {
                                    setState(() => isConnecting = false);
                                  }
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, // Align everything to the right
              children: [
                Text(
                  'Theme:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(width: 12), // spacing between label and switch
                Switch(
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (isDark) {
                    ThemeController.themeModeNotifier.value =
                        isDark ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}