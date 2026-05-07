import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thermal Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'Log'),
              Tab(icon: Icon(Icons.thermostat), text: 'Thermal'),
              Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLogTab(),
            _buildThermalTab(),
            _buildNotificationsTab(),
          ],
        ),
      ),
    );
  }



  Widget _buildLogTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('detections') // The folder the Pi will write to
          .orderBy('timestamp', descending: true)
         .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text("Status: ${data['status']}"),
                subtitle: Text("Confidence: ${(data['confidence'] * 100).toStringAsFixed(1)}%"),
                trailing: Text(data['time'] ?? ""),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildThermalTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.thermostat_auto, size: 80),
          const SizedBox(height: 16),
          const Text('Thermal image feed will appear here'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Feed'),
          )
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
}
