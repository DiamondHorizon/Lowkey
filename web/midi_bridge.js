window.initWebMidi = function () {
  if (!navigator.requestMIDIAccess) {
    console.log("Web MIDI API not supported.");
    return;
  }

  navigator.requestMIDIAccess().then(function (access) {
    for (let input of access.inputs.values()) {
      console.log("Found MIDI device:", input.name);

      input.onmidimessage = function (msg) {
        const data = Array.from(msg.data);
        const message = `MIDI Message: ${data.join(", ")}`;
        console.log(message);

        // Send to Dart via a global callback
        if (window.onMidiMessageFromJS) {
          window.onMidiMessageFromJS(message);
        }
      };
    }
  }, function (err) {
    console.log("MIDI access failed:", err);
  });
};