// import 'package:flutter/material.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // TRY THIS: Try running your application with "flutter run". You'll see
//         // the application has a purple toolbar. Then, without quitting the app,
//         // try changing the seedColor in the colorScheme below to Colors.green
//         // and then invoke "hot reload" (save your changes or press the "hot
//         // reload" button in a Flutter-supported IDE, or press "r" if you used
//         // the command line to start the app).
//         //
//         // Notice that the counter didn't reset back to zero; the application
//         // state is not lost during the reload. To reset the state, use hot
//         // restart instead.
//         //
//         // This works for code too, not just values: Most code changes can be
//         // tested with just a hot reload.
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.

//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // TRY THIS: Try changing the color here to a specific color (to
//         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//         // change color while the other colors stay the same.
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           //
//           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//           // action in the IDE, or press "p" in the console), to see the
//           // wireframe for each widget.
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }

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

class _MyAppState extends State<MyApp> {
  List<MidiDevice> devices = [];
  List<String> midiMessages = [];

  @override
  void initState() {
    super.initState();
    startScanning();
    listenForMidi();
  }

  void startScanning() {
    midiCommand.startScanningForBluetoothDevices();

    midiCommand.devices.then((foundDevices) {
      if (foundDevices != null) {
        setState(() {
          devices = foundDevices;
        });
        for (var device in foundDevices) {
          print("Found device: ${device.name}");
          connectToDevice(device);
          break;
        }
      } else {
        print("No MIDI devices found.");
      }
    });
  }

  void connectToDevice(MidiDevice device) {
    midiCommand.connectToDevice(device);
  }

  void listenForMidi() {
    midiCommand.onMidiDataReceived?.listen((MidiPacket packet) {
      final data = packet.data;
      print("MIDI Packet Received: ${data.toList()}");

      // Optional: parse the message
      if (data.length >= 3) {
        final status = data[0];
        final messageType = status & 0xF0;
        final channel = status & 0x0F;
        final note = data[1];
        final velocity = data[2];

        if (messageType == 0x90 && velocity > 0) {
          print("Note On: note=$note velocity=$velocity channel=${channel + 1}");
        } else if (messageType == 0x80 || (messageType == 0x90 && velocity == 0)) {
          print("Note Off: note=$note channel=${channel + 1}");
        }
      }
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
                devices.isNotEmpty
                    ? 'Connected to: ${devices.first.name}'
                    : 'Scanning for MIDI devices...',
                style: TextStyle(fontSize: 16),
              ),
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
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:flutter_midi_command/flutter_midi_command.dart';

// void main() => runApp(MidiApp());

// class MidiApp extends StatefulWidget {
//   @override
//   _MidiAppState createState() => _MidiAppState();
// }

// class _MidiAppState extends State<MidiApp> {
//   final MidiCommand _midiCommand = MidiCommand();
//   List<MidiDevice> _devices = [];
//   MidiDevice? _selectedDevice;

//   @override
//   void initState() {
//     super.initState();
//     _midiCommand.devices.then((devices) {
//       setState(() {
//         _devices = devices ?? [];
//       });
//     });

//     _midiCommand.onMidiDataReceived?.listen((event) {
//       print("MIDI Data: ${event.data}");
//     });
//   }

//   void _connectToDevice(MidiDevice device) {
//     _midiCommand.connectToDevice(device);
//     setState(() {
//       _selectedDevice = device;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: Text('MIDI Input Tester')),
//         body: Column(
//           children: [
//             Text('Available Devices:'),
//             ..._devices.map((device) => ListTile(
//               title: Text(device.name ?? 'Unknown'),
//               onTap: () => _connectToDevice(device),
//             )),
//             if (_selectedDevice != null)
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text('Connected to: ${_selectedDevice!.name}'),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }





// import 'dart:js' as js;
// import 'dart:html';
// import 'package:flutter/material.dart';

// void main() {
//   runApp(const MidiWebApp());
// }

// class MidiWebApp extends StatelessWidget {
//   const MidiWebApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'MIDI Web Tester',
//       home: Scaffold(
//         appBar: AppBar(title: const Text('MIDI Web Tester')),
//         body: const Center(
//           child: MidiInterface(),
//         ),
//       ),
//     );
//   }
// }

// class MidiInterface extends StatefulWidget {
//   const MidiInterface({super.key});

//   @override
//   State<MidiInterface> createState() => _MidiInterfaceState();
// }

// class _MidiInterfaceState extends State<MidiInterface> {
//   List<String> midiMessages = [];

//   void _addMessage(String msg) {
//     setState(() {
//       midiMessages.add(msg);
//     });
//   }

//   void _initializeMidi() {
//     // Define a global callback for JS to call
//     js.context['onMidiMessageFromJS'] = (String msg) {
//       _addMessage(msg);
//     };

//     // Call the JS function to start MIDI
//     js.context.callMethod('initWebMidi');
//   }

//   @override
//   void initState() {
//     super.initState();
//     _initializeMidi();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         const Text('Incoming MIDI Messages:'),
//         Expanded(
//           child: ListView.builder(
//             itemCount: midiMessages.length,
//             itemBuilder: (context, index) {
//               return ListTile(title: Text(midiMessages[index]));
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }