import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'dart:typed_data';

final midiCommand = MidiCommand();

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Instance Variables
  List<MidiDevice> devices = [];
  MidiDevice? connectedDevice;
  List<String> midiMessages = [];
  List<Map<String, dynamic>> bleDevices = [];
  List<String> debugLog = [];

  void log(String message) {
    final now = DateTime.now().toIso8601String();
    setState(() {
      debugLog.insert(0, "[$now] $message");
    });
  }

  @override
  void initState() {
    super.initState();
    log("Starting");
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
    return MaterialApp(
      home: Scaffold(
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
            Expanded(
              child: connectedDevice == null
              ? Column(
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
                              log("Tapped raw BLE device: ${device['name']} (${device['identifier']})");

                              await Future.delayed(Duration(seconds: 3));

                              final updatedDevices = await midiCommand.devices;

                              if (updatedDevices != null && updatedDevices.isNotEmpty) {
                                log("Updated CoreMIDI devices: ${updatedDevices.map((d) => d.name).toList()}");

                                MidiDevice? match;
                                try {
                                  match = updatedDevices.firstWhere((d) => d.name == device['name']);
                                } catch (_) {
                                  match = null;
                                }

                                if (match != null) {
                                  log("Promoted to CoreMIDI: ${match.name}");
                                  connectToDevice(match);
                                } else {
                                  log("Device not promoted to CoreMIDI yet.");
                                }
                              } else {
                                log("No CoreMIDI devices found.");
                              }
                            },
                          )),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                children: [
                  ElevatedButton(
                    onPressed: disconnectDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Back to Device List"),
                  ),
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
                ],
              ),
            ),
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
      ),
    );
  }
}