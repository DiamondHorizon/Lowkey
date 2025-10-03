class NoteEvent {
  final int note;
  final int time;
  final String hand;
  final bool isNoteOn;

  NoteEvent({
    required this.note,
    required this.time,
    required this.hand,
    required this.isNoteOn,
  });

  factory NoteEvent.fromJson(Map<String, dynamic> json) {
    return NoteEvent(
      note: json['note'],
      time: json['time'],
      hand: json['hand'],
      isNoteOn: json['isNoteOn'],
    );
  }
}
