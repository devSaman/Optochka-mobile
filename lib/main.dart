import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:optochka_mobile/notification_service.dart';
import 'package:rxdart/rxdart.dart';

import 'firebase_options.dart';
import 'web_view_screen.dart';

// FirebaseMessaging messaging = FirebaseMessaging.instance;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final _messageStreamController = BehaviorSubject<RemoteMessage>();
  NotificationService().showNotification(
      title: "${message.notification?.title}",
      body: "${message.notification?.body}");
  _messageStreamController.sink.add(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().initNotification();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final _messageStreamController = BehaviorSubject<RemoteMessage>();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().showNotification(
        title: "${message.notification?.title}",
        body: "${message.notification?.body}");
    _messageStreamController.sink.add(message);
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Optochka',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}
