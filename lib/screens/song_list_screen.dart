import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'song_trainer_screen.dart';

class SongListScreen extends StatelessWidget {
  Future<List<Map<String, String>>> loadSongManifest() async {
    try {
      final raw = await rootBundle.loadString('assets/songs/manifest.json');
      final List<dynamic> parsed = jsonDecode(raw);
      return parsed.map<Map<String, String>>((item) {
        return {
          'title': item['title'].toString(),
          'filename': item['filename'].toString(),
        };
      }).toList();
    } catch (e) {
      return [];
    }
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
                      builder: (_) => SongTrainerScreen(filename: song['filename']!, songName: song['title']!,),
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