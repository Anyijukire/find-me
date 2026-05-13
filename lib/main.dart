import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📦 Background message received: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ThermalAlertApp());
}

class ThermalAlertApp extends StatelessWidget {
  const ThermalAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermal Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.adf_scanner, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                const Text(
                  'Thermal Alert System',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Open Dashboard'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _token;
  List<String> notifications = [];

  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  bool isScanning = false; // Add this line
  
  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  void _initializeFCM() async {
  //  final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    setState(() => _token = token);

    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? "Alert";
      final body = message.notification?.body ?? "Unknown event";
      final alert = "$title\n$body";
      setState(() => notifications.insert(0, alert));
    });
  }

  void togglePi(bool value) async {
  // We use .set with SetOptions(merge: true) so it doesn't delete other settings
    await FirebaseFirestore.instance
        .collection('commands')
        .doc('pi_control') 
        .set({'power': value ? 'on' : 'off'}, SetOptions(merge: true));
      
    setState(() => isScanning = value);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thermal Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'Log'),
              Tab(icon: Icon(Icons.thermostat), text: 'Thermal'),
              Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
              Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLogTab(),
            _buildThermalTab(),
            _buildNotificationsTab(),
            _buildMapTab(), // We will build this next
          ],
        ),
      ),
    );
  }



  Widget _buildLogTab() {
    return Column(
      children: [
        // 1. THE SYSTEM TOGGLE (Mission Control)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isScanning ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isScanning ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isScanning ? "SYSTEM ACTIVE" : "SYSTEM PAUSED",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isScanning ? Colors.green : Colors.red,
                      ),
                    ),
                    const Text("Remote Drone Scanner", style: TextStyle(fontSize: 12)),
                  ],
                ),
                Switch.adaptive(
                  value: isScanning,
                  onChanged: (value) => togglePi(value),
                  activeColor: Colors.green,
                  trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.selected)) return Colors.green;
                    return Colors.red;
                  }),
                ),
              ],
            ),
          ),
        ),
      
        const Divider(), // Visual separator
      
        // 2. THE DATA LOG (Your existing StreamBuilder logic)
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('detections')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
              final docs = snapshot.data!.docs;
            
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(
                      Icons.warning, 
                      color: data['status'] == "STABLE / ACTIVE" ? Colors.orange : Colors.red
                    ),
                    title: Text(data['status'] ?? 'Unknown'),
                    subtitle: Text("Conf: ${data['confidence']} | Temp: ${data['temperature']}°C"),
                    trailing: Text(
                      data['timestamp'] != null 
                      ? (data['timestamp'] as Timestamp).toDate().toString().substring(11, 16) 
                      : "--:--"
                    ),
                  );
                },
              ); 
            },
          ),
        ),
      ],
    );
  }


  //Widget _buildThermalTab() {
  //  return Center(
  //    child: Column(
  //      mainAxisAlignment: MainAxisAlignment.center,
  //      children: [
  //        const Icon(Icons.thermostat_auto, size: 80),
  //        const SizedBox(height: 16),
  //        const Text('Thermal image feed will appear here'),
  //        const SizedBox(height: 12),
  //        ElevatedButton.icon(
  //          onPressed: () {},
  //          icon: const Icon(Icons.refresh),
  //          label: const Text('Refresh Feed'),
  //        )
  //      ],
  //    ),
  //  );
  //}

  Widget _buildThermalTab() {
    return StreamBuilder<QuerySnapshot>(
      // Pull the latest detection from Firestore
      stream: FirebaseFirestore.instance
          .collection('detections')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No thermal data available.'));
        }

        // Grab the list of 768 temperatures from the document
        var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        List<dynamic> thermalData = data['thermal_data'] ?? [];

        if (thermalData.isEmpty) {
          return const Center(child: Text('Waiting for next thermal scan...'));
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "LATEST THERMAL SNAPSHOT",
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
              // The Heatmap Grid
              AspectRatio(
                aspectRatio: 32 / 24, // Matches the sensor's physical layout
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(), // Scroll the whole page instead
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 32, // 32 pixels wide
                    ),
                    itemCount: thermalData.length, // 768 pixels total
                    itemBuilder: (context, index) {
                      double temp = thermalData[index].toDouble();
                      return Container(
                        decoration: BoxDecoration(
                          color: _getHeatmapColor(temp),
                          // Slight border creates a "technical" grid look
                          border: Border.all(color: Colors.black.withOpacity(0.05), width: 0.1),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildLegend(), // Helpful for your presentation audience
            ],
          ),
        );
      },
    );
  }

  // Color logic for your heatmap
  Color _getHeatmapColor(double temp) {
    if (temp > 34) return Colors.red;
    if (temp > 30) return Colors.orange;
    if (temp > 26) return Colors.yellow;
    if (temp > 22) return Colors.green;
    return Colors.blue.shade900;
  }

  // A simple UI legend to show what colors mean
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem("Hot", Colors.red),
        _legendItem("Warm", Colors.orange),
        _legendItem("Ambient", Colors.green),
        _legendItem("Cold", Colors.blue.shade900),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }


  Widget _buildNotificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Device Token:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(_token ?? "Fetching token..."),
        ],
      ),
    );
  }


  Widget _buildMapTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('detections')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Waiting for GPS data..."));
        }

        var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        // Access the location map we created in Python
        var loc = data['location'] ?? {};
        double lat = loc['latitude'] ?? 0.3476;
        double lng = loc['longitude'] ?? 32.5825;

        return GoogleMap(
          mapType: MapType.satellite, // <--- This replaces the need for a dark style
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('victim'),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                title: data['status'],
                snippet: "Confidence: ${(data['confidence'] * 100).toStringAsFixed(1)}%",
              ),
            ),
          },
          // Modern UX: Dark mode map if the app is in dark mode
          //style: Theme.of(context).brightness == Brightness.dark ? _darkMapStyle : null,
        );
      },
    );
  }
}



