import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:math';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:local_auth/local_auth.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PARTS — cada archivo vive en lib/modules/ y declara "part of '../main.dart'"
// El orden importa: ai → version → core → services → auth → sounds → account
//                   → admin → clinica
// ═══════════════════════════════════════════════════════════════════════════
part 'modules/ai.dart';
part 'modules/version.dart';
part 'modules/core.dart';
part 'modules/services.dart';
part 'modules/auth.dart';
part 'modules/sounds.dart';
part 'modules/account.dart';
part 'modules/admin.dart';
part 'modules/clinica.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SISTEMA DE COLORES ACCESIBLE - WCAG 2.1 AA
// ═══════════════════════════════════════════════════════════════════════════

class AccesibleColors {
  static const Color primaryDark = Color(0xFF006064);
  static const Color primary = Color(0xFF00838F);
  static const Color primaryLight = Color(0xFF0097A7);
  static const Color primaryAccent = Color(0xFF18FFFF);
  static const Color secondary = Color(0xFF4A148C);
  static const Color secondaryLight = Color(0xFF7C43BD);
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFF81C784);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFE57373);
  static const Color info = Color(0xFF01579B);
  static const Color infoLight = Color(0xFF4FC3F7);
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textDisabled = Color(0xFF757575);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2C2C2C);
}

class AccesibleTheme {
  static ThemeData darkTheme(Color seedColor) {
    final validatedSeed = _validateColorContrast(seedColor);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: validatedSeed,
        brightness: Brightness.dark,
        primary: AccesibleColors.primary,
        secondary: AccesibleColors.secondary,
        tertiary: AccesibleColors.info,
        error: AccesibleColors.error,
        surface: AccesibleColors.surfaceDark,
        background: AccesibleColors.backgroundDark,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.bold, color: AccesibleColors.textPrimary),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: AccesibleColors.textPrimary),
        displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AccesibleColors.textPrimary),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AccesibleColors.textPrimary),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AccesibleColors.textPrimary),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AccesibleColors.textPrimary),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: AccesibleColors.textPrimary),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AccesibleColors.textPrimary),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AccesibleColors.textSecondary),
        bodyLarge: TextStyle(fontSize: 16, color: AccesibleColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AccesibleColors.textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: AccesibleColors.textSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AccesibleColors.textPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AccesibleColors.textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AccesibleColors.textDisabled),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AccesibleColors.primaryLight, width: 1.5),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AccesibleColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AccesibleColors.textDisabled),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AccesibleColors.textDisabled),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AccesibleColors.primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AccesibleColors.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AccesibleColors.textSecondary),
        hintStyle: const TextStyle(color: AccesibleColors.textDisabled),
      ),
      cardTheme: CardThemeData(
        color: AccesibleColors.cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AccesibleColors.backgroundDark,
        foregroundColor: AccesibleColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AccesibleColors.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AccesibleColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AccesibleColors.textPrimary),
        contentTextStyle: const TextStyle(fontSize: 16, color: AccesibleColors.textSecondary),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AccesibleColors.surfaceDark,
        contentTextStyle: TextStyle(color: AccesibleColors.textPrimary),
        actionTextColor: AccesibleColors.primaryAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Color _validateColorContrast(Color color) {
    final double luminance = _relativeLuminance(color);
    if (luminance < 0.05) return AccesibleColors.primary;
    return color;
  }

  static double _relativeLuminance(Color color) {
    final r = _linearize(color.red / 255);
    final g = _linearize(color.green / 255);
    final b = _linearize(color.blue / 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _linearize(double channel) {
    if (channel <= 0.03928) return channel / 12.92;
    return pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OTROS OVERRIDES Y CONFIGURACIONES
// ═══════════════════════════════════════════════════════════════════════════

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        debugPrint('[HttpOverrides] Aceptando cert de $host:$port');
        return true;
      };
  }
}

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage msg) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] ${msg.notification?.title} — ${msg.data}');
}

const _kNotifChannel = AndroidNotificationChannel(
  'biofreq_canal_principal',
  'BioFreq',
  description: 'Notificaciones de sonidos, compras y comunicaciones BioFreq',
  importance: Importance.high,
  playSound: true,
);

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotifications() async {
  await _localNotif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_kNotifChannel);
  await _localNotif.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
}

Future<void> _mostrarNotifLocal(RemoteMessage msg) async {
  final notif = msg.notification;
  if (notif == null) return;
  await _localNotif.show(
    msg.hashCode,
    notif.title,
    notif.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _kNotifChannel.id,
        _kNotifChannel.name,
        channelDescription: _kNotifChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

void main() async {
  // 1. SIEMPRE primero — requerido antes de cualquier plugin
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cargar versión real ANTES del init de Sentry
  try {
    final info = await PackageInfo.fromPlatform();
    BioConfig.version = '${info.version}+${info.buildNumber}';
  } catch (_) {}

  // 3. Sentry ya puede leer BioConfig.versionDisplay con el valor real
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://ca8158fb73674e716cf8980e21404de8@o4511096920735744.ingest.us.sentry.io/4511096933384192';
      options.environment = kDebugMode ? 'debug' : 'production';
      options.release = 'biofreq@${BioConfig.versionDisplay}';
      options.tracesSampleRate = kDebugMode ? 0.0 : 0.1;
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
    },
    appRunner: () async {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      await _initLocalNotifications();
      HttpOverrides.global = MyHttpOverrides();
      await AlembiqueDio.warmUp();
      runApp(const BioFreqApp());
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// APLICACIÓN PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

class BioFreqApp extends StatefulWidget {
  const BioFreqApp({super.key});
  @override
  State<BioFreqApp> createState() => _BioFreqAppState();
}

class _BioFreqAppState extends State<BioFreqApp> {
  bool _versionChecked = false;
  VersionDelta _versionDelta = VersionDelta.upToDate;
  VersionInfo? _remoteVersion;
  bool _minorDismissed = false;
  bool _showMajorOverlay = false;
  Timer? _tokenRefreshTimer;

  @override
  void initState() {
    super.initState();
    AppTheme().cargar();
    ReproduccionConfig().cargar();
    SalidaSQCConfig().cargar();
    _checkVersion();
    _startTokenRefresh();
    _initFCM();
  }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Permiso denegado por el usuario');
      return;
    }

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      final token = await messaging.getToken();
      if (token != null) await _guardarFcmToken(token);
    });
    messaging.onTokenRefresh.listen(_guardarFcmToken);

    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[FCM Foreground] ${msg.notification?.title}');
      _mostrarNotifLocal(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('[FCM Tap] ${msg.data}');
      _manejarTapNotificacion(msg);
    });

    final inicial = await messaging.getInitialMessage();
    if (inicial != null) _manejarTapNotificacion(inicial);
  }

  Future<void> _guardarFcmToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // set+merge evita FirebaseException [not-found] si el doc aún no existe
      await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .set({'fcm_token': token}, SetOptions(merge: true));
      debugPrint('[FCM] Token guardado en Firestore');
    } catch (e) {
      debugPrint('[FCM] Error guardando token: $e');
    }
  }

  void _manejarTapNotificacion(RemoteMessage msg) {
    final tipo = msg.data['tipo'] ?? '';
    debugPrint('[FCM Tap] tipo=$tipo data=${msg.data}');
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  void _startTokenRefresh() {
    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 45),
      (_) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await user.getIdToken(true);
            debugPrint('[Auth] Token refrescado OK');
          } catch (e) {
            debugPrint('[Auth] Error refrescando token: \$e');
          }
        }
      },
    );
  }

  Future<void> _checkVersion() async {
    final (:delta, :remote) = await VersionManager.check(BioConfig.version);
    if (!mounted) return;
    setState(() {
      _versionDelta = delta;
      _remoteVersion = remote;
      _versionChecked = true;
      _showMajorOverlay = delta == VersionDelta.major;
    });
    if (delta == VersionDelta.patch && remote != null) {
      debugPrint('[Version] PATCH ${remote.raw} — hot update silencioso.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppTheme(),
      builder: (context, _) => MaterialApp(
        title: 'BioFreq v${BioConfig.versionDisplay}',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [SentryNavigatorObserver()],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es'), Locale('en'), Locale('pt'), Locale('fr'),
          Locale('de'), Locale('it'), Locale('zh'), Locale('ja'),
          Locale('ko'), Locale('ar'), Locale('ru'),
        ],
        theme: AccesibleTheme.darkTheme(AppTheme().colorPrimario),
        home: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    return Stack(
      children: [
        StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            return Column(children: [
              if (_versionChecked &&
                  _versionDelta == VersionDelta.minor &&
                  !_minorDismissed)
                _MinorUpdateBanner(
                  changelog: _remoteVersion?.changelogEs ??
                      'Hay una versión más reciente disponible. Puedes actualizar cuando quieras.',
                  onDismiss: () => setState(() => _minorDismissed = true),
                ),
              Expanded(
                child: snapshot.hasData
                    ? CheckReferralWrapper(remoteVersion: _remoteVersion)
                    : const LoginScreen(),
              ),
            ]);
          },
        ),
        if (_showMajorOverlay)
          _MajorUpdateOverlay(
            apkUrl: (_remoteVersion?.apkUrl != null &&
                    _remoteVersion!.apkUrl!.isNotEmpty &&
                    !_remoteVersion!.apkUrl!.contains('onrender.com'))
                ? _remoteVersion!.apkUrl!
                : 'https://drive.google.com/uc?export=download&id=1D11vGNw4fFdcdee9Sy6cPjdhtnx5y22u',
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BANNER MINOR
// ═══════════════════════════════════════════════════════════════════════════

class _MinorUpdateBanner extends StatelessWidget {
  final String changelog;
  final VoidCallback onDismiss;
  const _MinorUpdateBanner({required this.changelog, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF006064), Color(0xFF00838F)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  changelog,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final uri = Uri.parse(
                        'https://play.google.com/store/apps/details?id=com.biofreq.app');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'ACTUALIZAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OVERLAY MAJOR
// ═══════════════════════════════════════════════════════════════════════════

class _MajorUpdateOverlay extends StatefulWidget {
  final String apkUrl;
  const _MajorUpdateOverlay({required this.apkUrl});
  @override
  State<_MajorUpdateOverlay> createState() => _MajorUpdateOverlayState();
}

class _MajorUpdateOverlayState extends State<_MajorUpdateOverlay> {
  bool _isDownloading = false;

  Future<void> _descargarEInstalar() async {
    if (widget.apkUrl.isEmpty) {
      _showSnackBar('URL de actualización no disponible.');
      return;
    }
    setState(() => _isDownloading = true);
    try {
      final Uri url = Uri.parse(widget.apkUrl);
      if (!await launchUrl(url, mode: LaunchMode.platformDefault)) {
        throw Exception('No se pudo abrir el enlace de descarga');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error al abrir descarga: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccesibleColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000).withValues(alpha: 0.98),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (value * 0.2),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AccesibleColors.warning, AccesibleColors.error],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AccesibleColors.warning.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 56),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'ACTUALIZACIÓN MAESTRA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Versión requerida',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AccesibleColors.warningLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AccesibleColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AccesibleColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Esta versión ya no es compatible con nuestros servicios. '
                    'Actualiza ahora para continuar disfrutando de BioFreq '
                    'con las últimas mejoras y funciones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AccesibleColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccesibleColors.warning,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AccesibleColors.textDisabled,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    onPressed: _isDownloading ? null : _descargarEInstalar,
                    child: _isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 22),
                              SizedBox(width: 8),
                              Text('DESCARGAR ACTUALIZACIÓN'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'La descarga comenzará automáticamente',
                  style: TextStyle(color: AccesibleColors.textDisabled, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENTES ADICIONALES ACCESIBLES (OPCIONALES)
// ═══════════════════════════════════════════════════════════════════════════

class AccesibleButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isLoading;
  final bool isFullWidth;
  const AccesibleButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = isPrimary
        ? ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(isFullWidth ? double.infinity : 120, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _buildChild(),
          )
        : TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(
              minimumSize: Size(isFullWidth ? double.infinity : 120, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _buildChild(),
          );
    return Semantics(button: true, label: text, child: button);
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (icon != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(text),
      ]);
    }
    return Text(text);
  }
}

class AccesibleCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  const AccesibleCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AccesibleColors.cardDark,
      elevation: onTap != null ? 2 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
            )
          : Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
    );
  }
}
