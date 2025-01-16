import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool isLoading = true;
  String fcmToken = "";

  void getFcmToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    final fcm_token = await messaging.getToken();
    fcmToken = fcm_token ?? "";
    final result = await _controller.runJavaScriptReturningResult(
      'JSON.stringify(localStorage);',
    );
    if (result != null) {
      final localStorageMap = jsonDecode(result
          .toString()
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '')
          .replaceAll('"{', '{')
          .replaceAll('}"', '}')) as Map<String, dynamic>;
      accessToken = localStorageMap['persist:root']['settings']['credentials']
          ['accessToken'];
      if (accessToken != null) {
        sentTokenApi(fcm_token ?? "", accessToken);
      }
    }
  }

  void sentTokenApi(String token, accessToken) async {
    print("ACCEss token $accessToken");
    print(" token $token");
    final result = await http.put(
      Uri.parse('https://backend.optochka.com/users/device-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': accessToken,
      },
      body: json.encode(
        {"token": token, "system": Platform.operatingSystem},
      ),
    );
    print(result.body);
  }

  @override
  void initState() {
    Future.delayed(const Duration(seconds: 2), () {
      getFcmToken();
    });
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              debugPrint('blocking navigation to ${request.url}');
              return NavigationDecision.prevent;
            }
            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          },
          onHttpError: (HttpResponseError error) {
            debugPrint('Error occurred on page: ${error.response?.statusCode}');
          },
          onUrlChange: (UrlChange change) {
            if (change.url == "https://mobile.optochka.com/") {
              getFcmToken();
            }
            debugPrint('url change to ${change.url}');
          },
          onHttpAuthRequest: (HttpAuthRequest request) {},
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse('https://mobile.optochka.com/'));
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    _controller = controller;
    _controllerVideo = VideoPlayerController.asset('assets/videos/1025.mp4')
      ..initialize().then((_) {
        setState(() {});
      });
    _controllerVideo.setLooping(true);
    _controllerVideo.play();
    Future.delayed(
      const Duration(milliseconds: 5100),
    ).then((val) {
      setState(() {
        _controllerVideo.pause();
        isLoading = false;
        requestPermissions();
      });
    });
    super.initState();
  }

  void requestPermissions() async {
    if (await Permission.camera.request().isGranted &&
        await Permission.photos.request().isGranted &&
        await Permission.manageExternalStorage.request().isGranted) {
    } else {}
  }

  @override
  void dispose() {
    _controllerVideo.dispose();
    super.dispose();
  }

  late VideoPlayerController _controllerVideo;
  String? localStorageData;
  String? accessToken;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(
              child: AspectRatio(
              aspectRatio: _controllerVideo.value.aspectRatio,
              child: VideoPlayer(_controllerVideo),
            ))
          : SafeArea(
              child: WebViewWidget(
                controller: _controller,
              ),
            ),
    );
  }
}
