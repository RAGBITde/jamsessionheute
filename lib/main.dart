import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

void main() {
  HttpOverrides.global = MyHttpOverrides(); // Zertifikats-Bypass
  runApp(const MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class Appointment {
  final int id;
  final String title;
  final String startDate;
  final String startTime;
  final String locationName;
  final String city;
  final double distance;
  final double latitude;
  final double longitude;

  Appointment({
    required this.id,
    required this.title,
    required this.startDate,
    required this.startTime,
    required this.locationName,
    required this.city,
    required this.distance,
    required this.latitude,
    required this.longitude,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      title: json['title'],
      startDate: json['start_date'],
      startTime: json['start_time_only'] ?? '',
      locationName: json['location_name'],
      city: json['city'],
      distance: double.parse(json['distance'].toString()),
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jam Session Heute',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF7F0F5),
        primarySwatch: Colors.purple,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Appointment> appointments = [];
  String currentPosition = '';

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    print('🟢 fetchAppointments gestartet');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Standortdienste nicht aktiviert');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Standortberechtigung verweigert');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print('❌ Standort dauerhaft verweigert');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    print('📍 Position ermittelt: ${position.latitude}, ${position.longitude}');

    setState(() {
      currentPosition =
          '📍 ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    });

    final url =
        'https://jam-session-heute.de/api/appointments_nearby.php?lat=${position.latitude}&lng=${position.longitude}&radius=100';
    final response = await http.get(Uri.parse(url));

    print('🌐 API-Antwortcode: ${response.statusCode}');
    print('📦 API-Daten: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      final result = jsonList.map((e) => Appointment.fromJson(e)).toList();
      print('✅ Anzahl empfangener Termine: ${result.length}');

      setState(() {
        appointments = result;
      });
    } else {
      print('❌ Fehler beim Laden der Termine');
    }
  }

void openMaps(double lat, double lng) async {
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  print('🌍 Versuche zu öffnen: $uri');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    print('✅ geöffnet');
  } else {
    print('❌ URL konnte nicht geöffnet werden');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jam Sessions in deiner Nähe'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentPosition.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                currentPosition,
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final app = appointments[index];
                return GestureDetector(
                  onTap: () {
                    print('🟡 Termin angetippt');
                              openMaps(app.latitude, app.longitude);
                            },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📅 ${formatDateTime(app.startDate, app.startTime)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('🎵 ${app.title}', style: const TextStyle(fontSize: 15)),
                          Text('🏠 ${app.locationName}', style: const TextStyle(fontSize: 14)),
                          Text('📍 ${app.city} – ${app.distance.toStringAsFixed(1)} km entfernt',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String formatDateTime(String date, String time) {
    try {
      final dateTime = DateTime.parse('$date $time');
      final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      final months = [
        'Jan', 'Feb', 'März', 'Apr', 'Mai', 'Juni',
        'Juli', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
      ];
      final weekday = weekdays[dateTime.weekday - 1];
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = months[dateTime.month - 1];
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$weekday, $day. $month $year – $hour:$minute Uhr';
    } catch (_) {
      return '$date $time';
    }
  }
}
