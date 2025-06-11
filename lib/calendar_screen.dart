import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'google_calender_service.dart';
import 'database.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _events = {};
  bool _loading = true;
  String? _error;
  bool _isGoogle = false;

  @override
  void initState() {
    super.initState();
    _checkGoogleAccountAndFetch();
  }

  Future<void> _checkGoogleAccountAndFetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleUser = await GoogleSignIn().signInSilently();
      if (googleUser != null) {
        _isGoogle = true;
        final service = GoogleCalendarService();
        final todayEvents = await service.getTodayEvents(googleUser);
        setState(() {
          _events = {
            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day): todayEvents
          };
          _loading = false;
        });
      } else {
        // Ambil semua to-do dari database lokal
        final localEventsStream = DatabaseService().getTodos();
        final localEvents = await localEventsStream.first;
        Map<DateTime, List<String>> localMap = {};
        for (var event in localEvents) {
          if (event['date'] != null && event['title'] != null) {
            final date = (event['date'] is Timestamp)
                ? (event['date'] as Timestamp).toDate()
                : event['date'];
            final key = DateTime(date.year, date.month, date.day);
            localMap.putIfAbsent(key, () => []).add(event['title']);
          }
        }
        setState(() {
          _isGoogle = false;
          _events = localMap.isNotEmpty ? localMap : {
            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day): ["Tidak ada tugas hari ini"]
          };
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<String> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isGoogle ? 'Kalender' : 'Kalender',
            style: const TextStyle(
              color: Color.fromARGB(255, 255, 255, 255),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            )),
        backgroundColor: const Color(0xFF3B3DBF),
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 255, 255, 255)),
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime.utc(2000, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: _getEventsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Color(0xFF3B3DBF),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: _getEventsForDay(_selectedDay ?? _focusedDay)
                            .map((event) => ListTile(
                                  leading: const Icon(Icons.event, color: Color(0xFF3B3DBF)),
                                  title: Text(
                                    event,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class LocalCalendarScreen extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  const LocalCalendarScreen({Key? key, required this.events}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Calendar'),
        backgroundColor: const Color(0xFF3B3DBF),
      ),
      body: events.isEmpty
          ? const Center(child: Text('No local events for today.'))
          : ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final date = event['date'];
                return ListTile(
                  leading: const Icon(Icons.event, color: Color(0xFF3B3DBF)),
                  title: Text(event['title'] ?? '-'),
                  subtitle: date is DateTime
                      ? Text('Tanggal: ${date.day}-${date.month}-${date.year}')
                      : null,
                );
              },
            ),
    );
  }
}
