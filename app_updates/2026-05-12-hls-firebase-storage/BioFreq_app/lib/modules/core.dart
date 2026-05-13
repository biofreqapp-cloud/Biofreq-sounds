// ======================================================================
// BioFreq — Módulo: core
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

enum ModoSalidaSQC {
  sonido,
  color,
  ambos,
}

enum ModoReproduccion {
  sonido,
  dual,
  vibracion,
}

class SalidaSQCConfig extends ChangeNotifier {
  static final SalidaSQCConfig _i = SalidaSQCConfig._();
  factory SalidaSQCConfig() => _i;
  SalidaSQCConfig._();

  ModoSalidaSQC _modo = ModoSalidaSQC.ambos;
  ModoSalidaSQC get modo => _modo;

  Future<void> cargar() async {
    final p = await SharedPreferences.getInstance();
    final idx = p.getInt('sqc_salida_modo') ?? 2;
    _modo = ModoSalidaSQC.values[idx.clamp(0, 2)];
    notifyListeners();
  }

  Future<void> setModo(ModoSalidaSQC m) async {
    _modo = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('sqc_salida_modo', m.index);
  }
}

class ReproduccionConfig extends ChangeNotifier {
  static final ReproduccionConfig _i = ReproduccionConfig._();
  factory ReproduccionConfig() => _i;
  ReproduccionConfig._();

  ModoReproduccion _modo = ModoReproduccion.sonido;
  ModoReproduccion get modo => _modo;

  Future<void> cargar() async {
    final p = await SharedPreferences.getInstance();
    final idx = p.getInt('modo_reproduccion') ?? 0;
    _modo = ModoReproduccion.values[idx.clamp(0, 2)];
    notifyListeners();
  }

  Future<void> setModo(ModoReproduccion m) async {
    _modo = m;
    final p = await SharedPreferences.getInstance();
    await p.setInt('modo_reproduccion', m.index);
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HAPTIC HELPER — Convierte hexColor → patrón háptico via HSL
//
//  Hue 0-60   (Rojos/Naranjas)  → ondas lentas   500ms ON/OFF  [frecuencia baja]
//  Hue 60-180 (Amarillos/Verdes) → ondas medias   200ms ON/OFF
//  Hue 180-360(Azules/Violetas) → pulsos rápidos   50ms ON/OFF  [frecuencia alta]
//
//  Lightness → número de ciclos (más luz = más repeticiones)
//
//  v51: el Alembique enviará haptic_pattern directo en Firestore.
// ─────────────────────────────────────────────────────────────────────────────
class HapticHelper {
  static List<int> patronDesdeHex(String hexColor) {
    Color color;
    try {
      final hex = hexColor.replaceAll('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return [200, 200, 200, 200];
    }
    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;
    final light = hsl.lightness;
    final ciclos = (2 + (light * 6)).round().clamp(2, 8);

    int pulso;
    if (hue < 60) {
      pulso = 500; // Rojos
    } else if (hue < 180)
      pulso = 200; // Verdes
    else
      pulso = 50; // Azules/Violetas

    final patron = <int>[];
    for (int i = 0; i < ciclos; i++) {
      patron.add(pulso); // OFF
      patron.add(pulso); // ON
    }
    return patron;
  }

  static Future<void> vibrarConHex(String hexColor) async {
    final bool tiene = await Vibration.hasVibrator();
    if (tiene != true) return;
    // MEJORA 2: repeat: 0 = loop desde el inicio indefinidamente.
    // repeat: -1 era el bug anterior (Android interpreta -1 como "no repetir").
    // Vibration.cancel() se llama explícitamente al pausar/parar el audio.
    await Vibration.vibrate(pattern: patronDesdeHex(hexColor), repeat: 0);
  }

  static Future<void> detener() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('[Haptic] cancel() fallo: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTheme — Singleton con ChangeNotifier para personalización visual
// Persiste en SharedPreferences. Toda la app escucha sus cambios.
// ─────────────────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
// ViewAsManager — Simulación de rol para Admin y Tester
//
// PRINCIPIO DE SEGURIDAD: este singleton SOLO afecta la renderización de UI.
// Ninguna escritura a Firestore usa el rol simulado — el UID y rol real del
// usuario autenticado siempre son la fuente de verdad para todas las ops.
//
// Ciclo de vida: en memoria (RAM). Se resetea al matar la app.
// No persiste en SharedPreferences intencionalmente — si el admin cierra la
// app mientras está en "Ver como User", al abrir vuelve a su rol real.
// ═══════════════════════════════════════════════════════════════════════════
class ViewAsManager extends ChangeNotifier {
  static final ViewAsManager _instance = ViewAsManager._();
  factory ViewAsManager() => _instance;
  ViewAsManager._();

  String? _rolSimulado; // null = usando rol real

  String? get rolSimulado => _rolSimulado;

  bool get estaActivo => _rolSimulado != null;

  // Roles que puede simular cada rol real
  // Admin  → puede ver como: tester, PS, user
  // Tester → puede ver como: PS, user
  static List<String> rolesDisponibles(String rolReal) {
    if (rolReal == BioConfig.rolAdmin) {
      return [
        BioConfig.rolTester,
        BioConfig.rolPS,
        BioConfig.rolMarketing,
        BioConfig.rolUser,
      ];
    }
    if (rolReal == BioConfig.rolTester) {
      return [BioConfig.rolPS, BioConfig.rolUser];
    }
    return []; // User y PS no pueden simular
  }

  // Devuelve el rol efectivo: simulado si está activo, real si no
  String rolEfectivo(String rolReal) => _rolSimulado ?? rolReal;

  void activar(String rolASimular) {
    _rolSimulado = rolASimular;
    notifyListeners();
    debugPrint('[ViewAs] Activado: viendo como ${rolASimular.toUpperCase()}');
  }

  void desactivar() {
    _rolSimulado = null;
    notifyListeners();
    debugPrint('[ViewAs] Desactivado — rol real restaurado');
  }
}

class AppTheme extends ChangeNotifier {
  static final AppTheme _instance = AppTheme._();
  factory AppTheme() => _instance;
  AppTheme._();

  // ── Valores por defecto ───────────────────────────────────────────────────
  Color _colorPrimario = Colors.cyan;
  Color _colorFondo = Colors.black;
  Color _colorTexto = Colors.white;
  Color _colorNavBar = const Color(0xFF111111);
  String _imagenFondo = ''; // ruta local o URL
  Color _qrForeground = Colors.black; // color de los módulos del QR
  Color _qrBackground = Colors.white; // color del fondo del QR

  Color get colorPrimario => _colorPrimario;
  Color get colorFondo => _colorFondo;
  Color get colorTexto => _colorTexto;
  Color get colorNavBar => _colorNavBar;
  String get imagenFondo => _imagenFondo;
  Color get qrForeground => _qrForeground;
  Color get qrBackground => _qrBackground;

  // ── Cargar desde SharedPreferences ───────────────────────────────────────
  Future<void> cargar() async {
    final p = await SharedPreferences.getInstance();
    _colorPrimario =
        Color(p.getInt('theme_colorPrimario') ?? Colors.cyan.toARGB32());
    _colorFondo =
        Color(p.getInt('theme_colorFondo') ?? Colors.black.toARGB32());
    _colorTexto =
        Color(p.getInt('theme_colorTexto') ?? Colors.white.toARGB32());
    _colorNavBar = Color(
        p.getInt('theme_colorNavBar') ?? const Color(0xFF111111).toARGB32());
    _imagenFondo = p.getString('theme_imagenFondo') ?? '';
    _qrForeground =
        Color(p.getInt('theme_qrForeground') ?? Colors.black.toARGB32());
    _qrBackground =
        Color(p.getInt('theme_qrBackground') ?? Colors.white.toARGB32());
    notifyListeners();
  }

  // ── Guardar un color ──────────────────────────────────────────────────────
  Future<void> setColorPrimario(Color c) async {
    _colorPrimario = c;
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_colorPrimario', c.toARGB32());
    notifyListeners();
  }

  Future<void> setColorFondo(Color c) async {
    _colorFondo = c;
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_colorFondo', c.toARGB32());
    notifyListeners();
  }

  Future<void> setColorTexto(Color c) async {
    _colorTexto = c;
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_colorTexto', c.toARGB32());
    notifyListeners();
  }

  Future<void> setColorNavBar(Color c) async {
    _colorNavBar = c;
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_colorNavBar', c.toARGB32());
    notifyListeners();
  }

  // ── Guardar imagen de fondo (ruta local o URL) ────────────────────────────
  Future<void> setQrForeground(Color c) async {
    _qrForeground = c;
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_qrForeground', c.toARGB32());
    notifyListeners();
  }

  Future<void> setQrBackground(Color c) async {
    _qrBackground = c;
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_qrBackground', c.toARGB32());
    notifyListeners();
  }

  Future<void> setImagenFondo(String valor) async {
    _imagenFondo = valor;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_imagenFondo', valor);
    notifyListeners();
  }

  Future<void> resetearTodo() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('theme_colorPrimario');
    await p.remove('theme_colorFondo');
    await p.remove('theme_colorTexto');
    await p.remove('theme_colorNavBar');
    await p.remove('theme_imagenFondo');
    _colorPrimario = Colors.cyan;
    _colorFondo = Colors.black;
    _colorTexto = Colors.white;
    _colorNavBar = const Color(0xFF111111);
    _imagenFondo = '';
    _qrForeground = Colors.black;
    _qrBackground = Colors.white;
    notifyListeners();
  }
}

class BioPageBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BioPageBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme();
    final imagePath = theme.imagenFondo;
    ImageProvider? imageProvider;
    if (imagePath.isNotEmpty) {
      if (imagePath.startsWith('http')) {
        imageProvider = NetworkImage(imagePath);
      } else {
        imageProvider = FileImage(File(imagePath));
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorFondo.withValues(alpha: 0.98),
            const Color(0xFF06080D),
          ],
        ),
      ),
      child: Stack(
        children: [
          if (imageProvider != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.16,
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.1,
                  colors: [
                    theme.colorPrimario.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class BioGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const BioGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BIONOTIF — Sistema centralizado de notificaciones push
// ═══════════════════════════════════════════════════════════════════════════
// ⚠️  NUNCA llamar FCM directo — siempre usar BioNotif.xxxxx()
//     Así cuando migremos a Cloud Functions solo cambiamos esta clase.
class BioNotif {
  // ── URL del servidor Alembique ───────────────────────────────────────────
  // DEBUG:      IP local de tu PC (cambiar según red)
  // PRODUCCIÓN: URL de Render (ya configurada)
  static String get _srv {
    const isProd = bool.fromEnvironment('dart.vm.product');
    if (!isProd) return 'http://192.168.1.5:5000'; // ← cambia IP local aquí
    return 'https://biofreq-servidor.onrender.com';
  }

  // ── Envío base ─────────────────────────────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (idToken != null && idToken.isNotEmpty)
        'Authorization': 'Bearer $idToken',
    };
  }

  static Future<void> _post(String uid, String titulo, String cuerpo,
      Map<String, String> datos) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(uid)
          .get();
      final token = doc.data()?['fcm_token'] as String?;
      if (token == null || token.isEmpty) return;
      await http
          .post(
            Uri.parse('$_srv/notificar'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'token': token,
              'titulo': titulo,
              'cuerpo': cuerpo,
              'datos': datos
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[BioNotif] $e');
    }
  }

  static Future<void> _postAdmin(
      String titulo, String cuerpo, Map<String, String> datos) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .where('rol', isEqualTo: 'admin')
          .get();
      final tokens = snap.docs
          .map((d) => d.data()['fcm_token'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      if (tokens.isEmpty) return;
      await http
          .post(
            Uri.parse('$_srv/notificarGrupo'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'tokens': tokens,
              'titulo': titulo,
              'cuerpo': cuerpo,
              'datos': datos
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[BioNotif] admin $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // USUARIO
  // ────────────────────────────────────────────────────────────────────────────

  static Future<void> compraAprobada(String uid, int tokens) => _post(
      uid,
      '✅ Compra aprobada',
      'Se acreditaron $tokens tokens a tu cuenta. ¡Disfrútalos!',
      {'tipo': 'compra_ok', 'tokens': '$tokens'});

  static Future<void> compraRechazada(String uid, String motivo) => _post(
      uid,
      '❌ Compra no procesada',
      'Tu compra fue rechazada: $motivo',
      {'tipo': 'compra_rechazada'});

  static Future<void> usoExcesivo(String uid, String sonido) => _post(
      uid,
      '⚠️ Descansa un momento',
      'Llevas más de 100 reproducciones seguidas de "$sonido". '
          'Tómate un descanso.',
      {'tipo': 'uso_excesivo', 'sonido': sonido});

  static Future<void> tokensRegalados(String uid, int tokens, String ps) =>
      _post(uid, '🎁 Tokens recibidos', '$ps te obsequió $tokens tokens.',
          {'tipo': 'tokens_regalo', 'tokens': '$tokens'});

  static Future<void> sonidoHabilitado(String uid, String sonido) => _post(
      uid,
      '🔊 Sonido habilitado',
      'Tu PS habilitó "$sonido" para que puedas usarlo.',
      {'tipo': 'ps_habilito', 'sonido': sonido});

  static Future<void> sonidoRechazado(String uid, String sonido) => _post(
      uid,
      '🚫 Solicitud rechazada',
      'Tu PS no aprobó el uso de "$sonido" por el momento.',
      {'tipo': 'ps_rechazo', 'sonido': sonido});

  static Future<void> sonidoRecomendado(String uid, String sonido) => _post(
      uid,
      '💡 Recomendación de tu PS',
      'Tu PS recomienda "$sonido" para tu terapia.',
      {'tipo': 'sonido_recomendado', 'sonido': sonido});

  static Future<void> mensajeChat(String uid, String remitente) => _post(
      uid,
      '💬 Nuevo mensaje',
      '$remitente te envió un mensaje.',
      {'tipo': 'mensaje_chat'});

  static Future<void> expulsado(String uid) => _post(
      uid,
      '🚫 Cuenta suspendida',
      'Has sido expulsado de la comunidad BioFreq por infringir las normas.',
      {'tipo': 'expulsado'});

  // ────────────────────────────────────────────────────────────────────────────
  // PS
  // ────────────────────────────────────────────────────────────────────────────

  static Future<void> investigacionActualizada(String psUid, String titulo) =>
      _post(psUid, '🔬 Investigación actualizada',
          'Hay nuevos datos en: $titulo', {'tipo': 'investigacion'});

  static Future<void> nuevoSonidoPS(String psUid, String sonido) => _post(
      psUid,
      '🎵 Nuevo sonido para ensayar',
      '"$sonido" está disponible para que lo ensayes y aportes datos.',
      {'tipo': 'nuevo_sonido_ps', 'sonido': sonido});

  static Future<void> nuevoColorPS(String psUid, String patologia) => _post(
      psUid,
      '🎨 Nuevo color de diagnóstico',
      'El color de "$patologia" ya está en el Bio-Scanner.',
      {'tipo': 'nuevo_color'});

  static Future<void> comisionAcreditada(
          String psUid, int tokens, String paciente) =>
      _post(
          psUid,
          '💰 Comisión acreditada',
          '$paciente compró tokens. Se acreditaron $tokens tokens a tu cuenta.',
          {'tipo': 'comision', 'tokens': '$tokens'});

  static Future<void> pagoAcreditadoPS(
          String psUid, int tokens, String cuenta, double valorCOP) =>
      _post(
          psUid,
          '✅ Pago procesado',
          'Se transfirieron \$${valorCOP.toStringAsFixed(0)} COP '
              '($tokens tokens) a "$cuenta".',
          {'tipo': 'pago_ps'});

  static Future<void> cambioEstadoResuelto(String psUid, bool aprobado) => _post(
      psUid,
      aprobado ? '✅ Solicitud aprobada' : '❌ Solicitud rechazada',
      aprobado
          ? 'Tu solicitud de cambio de estado fue aprobada. ¡Bienvenido como PS!'
          : 'Tu solicitud de cambio de estado no fue aprobada. Contacta al Admin.',
      {'tipo': 'cambio_estado', 'aprobado': '$aprobado'});

  static Future<void> psExpulsado(String psUid) => _post(
      psUid,
      '🚫 Cuenta suspendida',
      'Tu cuenta de PS ha sido suspendida por infringir las normas.',
      {'tipo': 'expulsado_ps'});

  // ── Recetas ───────────────────────────────────────────────────────────────

  /// User recibe: receta aprobada → debe pagar antes de iniciar
  static Future<void> recetaAprobada(
          String uid, String sonido, int sesiones, int dias, int costoTotal) =>
      _post(
          uid,
          '✅ Tratamiento aprobado',
          'Tu PS aprobó "$sonido": $sesiones sesión(es)/ciclo × $dias día(s). '
              'Costo total: $costoTotal tokens.',
          {
            'tipo': 'receta_aprobada',
            'sonido': sonido,
            'costo': '$costoTotal'
          });

  /// User recibe: receta modificada (PS cambió el sonido o la dosis)
  static Future<void> recetaModificada(String uid, String sonidoNuevo,
          int sesiones, int dias, int costoTotal) =>
      _post(
          uid,
          '🔄 Tratamiento modificado',
          'Tu PS ajustó el tratamiento a "$sonidoNuevo": '
              '$sesiones sesión(es)/ciclo × $dias día(s). '
              'Costo total: $costoTotal tokens.',
          {
            'tipo': 'receta_modificada',
            'sonido': sonidoNuevo,
            'costo': '$costoTotal'
          });

  /// User recibe: receta denegada
  static Future<void> recetaDenegada(
          String uid, String sonido, String motivo) =>
      _post(
          uid,
          '🚫 Tratamiento no aprobado',
          'Tu PS no aprobó el uso de "$sonido". Motivo: $motivo',
          {'tipo': 'receta_denegada', 'sonido': sonido});

  /// PS recibe: solicitud de prescripción de un paciente
  static Future<void> recetaRevocada(
          String uid, String sonido, String motivo) =>
      _post(
          uid,
          'Tratamiento revocado',
          'Se revoco el acceso a \"$sonido\". Motivo: $motivo',
          {'tipo': 'receta_revocada', 'sonido': sonido});

  static Future<void> solicitudRecibidaPS(
          String psUid, String paciente, String sonido, String origen) =>
      _post(
          psUid,
          '📋 Nueva solicitud de tratamiento',
          '$paciente solicita "$sonido"'
              '${origen == 'bio_scanner' ? ' (positivo Bio-Scanner)' : ''}.',
          {'tipo': 'solicitud_receta', 'paciente': paciente, 'sonido': sonido});

  static Future<void> adminSolicitudReceta({
    required String paciente,
    required String sonido,
    required String psNombre,
  }) =>
      _postAdmin(
        '📋 Nueva solicitud de sonido',
        '$paciente solicita "$sonido". PS a cargo: $psNombre.',
        {
          'tipo': 'admin_solicitud_receta',
          'paciente': paciente,
          'sonido': sonido,
          'ps': psNombre,
        },
      );

  /// User recibe: ciclo de tratamiento desbloqueado
  static Future<void> cicloTratamientoListo(String uid, String sonido) => _post(
      uid,
      '⏰ Es hora de tu tratamiento',
      'Tu próxima sesión de "$sonido" está lista. ¡Tómatelo!',
      {'tipo': 'ciclo_listo', 'sonido': sonido});

  /// PS recibe: paciente saltó una sesión
  static Future<void> sesionSaltadaPS(
          String psUid, String paciente, String sonido) =>
      _post(
          psUid,
          '⚠️ Sesión saltada',
          '$paciente no completó la sesión programada de "$sonido".',
          {'tipo': 'sesion_saltada', 'paciente': paciente, 'sonido': sonido});

  // ────────────────────────────────────────────────────────────────────────────
  // ADMIN
  // ────────────────────────────────────────────────────────────────────────────

  static Future<void> adminNuevoUsuario(String psNombre, String nuevoNombre) =>
      _postAdmin('👤 Nuevo usuario registrado',
          '$psNombre invitó a $nuevoNombre.', {'tipo': 'admin_nuevo_user'});

  static Future<void> adminSolicitudPS(String nombreUsuario) => _postAdmin(
      '📋 Solicitud de cambio a PS',
      '$nombreUsuario solicita convertirse en Profesional de Salud.',
      {'tipo': 'admin_solicitud_ps'});

  static Future<void> adminCompra(String nombreUsuario, int tokens) =>
      _postAdmin('💳 Nueva compra', '$nombreUsuario adquirió $tokens tokens.',
          {'tipo': 'admin_compra', 'tokens': '$tokens'});

  static Future<void> adminSolicitudRetiro({
    required String psNombre,
    required int tokensSolicitados,
    required int tokensTotal,
    required double valorCOP,
    required String llave,
  }) {
    final restante = tokensTotal - tokensSolicitados;
    return _postAdmin(
      '💸 Solicitud de retiro',
      '$psNombre solicita \$${valorCOP.toStringAsFixed(0)} COP '
          '($tokensSolicitados/$tokensTotal tokens) a la llave "$llave". '
          'Saldo restante: $restante tokens.',
      {'tipo': 'admin_retiro'},
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TODOS: nueva versión
  // ────────────────────────────────────────────────────────────────────────────
  static Future<void> nuevaVersion(String version) async {
    try {
      // Obtener todos los tokens (menos admin/tester) — el servidor los filtra
      await http
          .post(
            Uri.parse(
                '$_srv/notificarNuevoSonido'), // reutiliza el broadcast del servidor
            headers: await _authHeaders(),
            body: jsonEncode({
              'titulo': '🆕 Nueva versión disponible',
              'cuerpo':
                  'BioFreq $version ya está disponible. Actualiza desde Mi Cuenta.',
              'sonido_nombre': '',
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[BioNotif] nuevaVersion: $e');
    }
  }
}

class BioConfig {
  static const String colUsuarios = "Usuarios";
  static const String colSonidos = "Sonidos";
  static const String colAccesosSonidos = "accesos_sonidos";
  static const String colDonaciones = "donaciones";
  // @deprecated — reemplazado por contadores en Sonidos.total_usos y Usuarios.historico_sonidos
  static const String colUsosSonidos = "usos_sonidos";
  static const String colTestimonios = "testimonios";
  static const String colRetiros = "retiros";
  static const String colTransacciones = "transacciones";
  static const double recargoPorMovimiento = 0.20; // 20% o mín 1 token
  static const String colEnsayos = "ensayos";
  static const String colFavoritos = "favoritos";
  static const String colSolicitudesPS = "solicitudes_ps";
  static const String colSolicitudesPrescripcion = "solicitudes_prescripcion";
  static const String colCampanasMarketing = "campanas_marketing";
  // ── Consultorio Virtual ──────────────────────────────────────────────────
  static const String colConfiguracion = "configuracion";
  static const String docApp = "app"; // configuracion/app
  static const String docPlanesSuscripcion =
      "planes_suscripcion"; // configuracion/planes_suscripcion
  static const String docSegmentosMacro =
      "segmentos_macro"; // configuracion/segmentos_macro
  // TTL para datos de testers (24 h en milisegundos — evaluado en UI)
  static const Duration testerDataTTL = Duration(hours: 24);

  // Roles
  static const String rolUser = "user";
  static const String rolPS = "PS";
  static const String rolAdmin = "admin";
  static const String rolTester = "tester";
  static const String rolMarketing = "marketing";

  // Estados de sonidos
  static const String estadoInvestigacion = "en_investigacion";
  static const String estadoEnProceso = "en_proceso";
  static const String estadoDisponible = "disponible";

  static const String campoTokens = "tokens_disponibles";
  static const String campoCodigoPropio = "codigo_afiliado_propio";
  static const String campoReferidoPor = "referido_por";
  static const String campoMedicoId = "medico_id";
  static const String campoSuspendido = "suspendido";
  static const String campoEstadoCuenta = "estado_cuenta";
  static const String campoSuscripcionActiva =
      "suscripcion_activa"; // bool, calculado al leer
  static const String campoSuscripcionFin = "suscripcion_fin"; // Timestamp
  static const String campoSuscripcionPlan =
      "suscripcion_plan"; // '15d','1m','6m','1a'
  static const String campoHistorico = "total_acumulado_historico";
  static const String campoNivel = "nivel";
  static const String campoUrlActualizadorApk = "url_actualizador_apk";
  static const String campoUrlEdmark = "url_edmark";
  static const String campoValorTokenCop = "valor_token_cop";
  static const String campoMaxInvitados = "max_usuarios_invitados";

  static const String estadoCampanaBorrador = "borrador";
  static const String estadoCampanaPendiente = "pendiente";
  static const String estadoCampanaAprobada = "aprobada";
  static const String estadoCampanaRechazada = "rechazada";

  static const String tipoCampanaSonido = "sonido";
  static const String tipoCampanaPlan = "plan";

  static const double comisionL1 = 0.10;
  static const double comisionL2 = 0.01;
  // Código maestro reconstruido en runtime — dificulta extracción por decompilación
  // No es seguridad perfecta pero evita búsquedas triviales en strings del APK
  static String get codigoMaestro {
    const p1 = 'BIO';
    const p2 = '-';
    const p3 = 'MASTER';
    return '$p1$p2$p3';
  }

  static const int diasPorCiclo = 13;

  static const int umbralPro = 1000;
  static const int umbralVip = 5000;
  static const int bonusCompraPro = 200;
  static const int bonusCompraVip = 1000;
  static const int bonusHitoPro = 200;
  static const int bonusHitoVip = 1000;
  static const double bonusPorcentajeVip = 0.25;

  // ── Planes de suscripción (valores por defecto — editables desde Admin en Firestore)
  // Firestore: configuracion/planes_suscripcion → {plan_15d, plan_1m, plan_6m, plan_1a}
  static const Map<String, int> planesDefecto = {
    '15d': 300,
    '1m': 500,
    '6m': 2500,
    '1a': 4500,
  };
  static const Map<String, String> planesNombre = {
    '15d': '15 días',
    '1m': '1 mes',
    '6m': '6 meses',
    '1a': '1 año',
  };
  // ── Caché de Sonidos en memoria ─────────────────────────────────────────
  // Evita relanzar StreamBuilder de Sonidos cada vez que se reconstruye el árbol.
  // Se invalida automáticamente tras 5 minutos o al llamar invalidarCacheSonidos().
  static Color colorEstadoSonido(String estado) {
    switch (estado) {
      case estadoInvestigacion:
        return Colors.lightBlueAccent;
      case estadoEnProceso:
        return Colors.orangeAccent;
      case estadoDisponible:
      default:
        return Colors.greenAccent;
    }
  }

  static String etiquetaEstadoSonido(String estado) {
    switch (estado) {
      case estadoInvestigacion:
        return 'En investigacion';
      case estadoEnProceso:
        return 'En proceso';
      case estadoDisponible:
      default:
        return 'Disponible';
    }
  }

  static String mensajeEstadoSonido(
    String estado, {
    String descripcion = '',
    String fase = '',
    int donaciones = 0,
    int metaDonacion = 0,
  }) {
    final desc = descripcion.trim();
    final faseTexto = fase.trim();
    switch (estado) {
      case estadoInvestigacion:
        if (metaDonacion > 0) {
          return 'Requiere capital para su desarrollo. Donado: '
              '$donaciones / $metaDonacion tokens.';
        }
        return 'Requiere capital para dedicar tiempo a su desarrollo.';
      case estadoEnProceso:
        if (faseTexto.isNotEmpty && faseTexto != 'desarrollo') {
          return 'Desarrollo activo en etapa: $faseTexto.';
        }
        return 'Requisitos completos. Estamos trabajando en la onda.';
      case estadoDisponible:
      default:
        if (desc.isNotEmpty) {
          return 'Disponible para uso si cumples tokens y desbloqueo por PS.';
        }
        return 'Listo para usarse si cumples tokens y desbloqueo por PS.';
    }
  }

  static String etiquetaRol(String rol) {
    switch (rol) {
      case rolAdmin:
        return 'Admin';
      case rolPS:
        return 'PS';
      case rolTester:
        return 'Tester';
      case rolMarketing:
        return 'Marketing';
      case rolUser:
      default:
        return 'User';
    }
  }

  static bool esRolVistaUsuario(String rol) =>
      rol == rolUser || rol == rolMarketing;

  static bool puedeGestionarMarketing(String rol) =>
      rol == rolAdmin || rol == rolMarketing;

  static bool puedeVerMenuMarketing(String rol) =>
      rol == rolAdmin || rol == rolMarketing || rol == rolTester;

  static bool puedeVerMenuClinica(String rol) =>
      rol == rolAdmin || rol == rolPS || rol == rolTester;

  static bool cuentaBaneada(Map<String, dynamic> data) {
    final suspendido = data[campoSuspendido] == true;
    final estado =
        (data[campoEstadoCuenta] ?? '').toString().trim().toLowerCase();
    return suspendido || estado == 'baneado' || estado == 'suspendido';
  }

  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<Map<String, dynamic>>? _cacheSonidos;
  static DateTime? _cacheSonidosFecha;
  static const Duration _cacheSonidosTTL = Duration(minutes: 5);

  static bool get cacheSonidosValida =>
      _cacheSonidos != null &&
      _cacheSonidosFecha != null &&
      DateTime.now().difference(_cacheSonidosFecha!) < _cacheSonidosTTL;

  static List<Map<String, dynamic>>? get cacheSonidos => _cacheSonidos;

  static void guardarCacheSonidos(List<Map<String, dynamic>> datos) {
    _cacheSonidos = datos;
    _cacheSonidosFecha = DateTime.now();
  }

  static void invalidarCacheSonidos() {
    _cacheSonidos = null;
    _cacheSonidosFecha = null;
  }

  static const Map<String, int> planesDias = {
    '15d': 15,
    '1m': 30,
    '6m': 180,
    '1a': 365,
  };

  static const String nivelBasico = "BÁSICO";
  static const String nivelPro = "PRO";
  static const String nivelVip = "VIP";

  static Color get colorPrimario => AppTheme().colorPrimario;
  static Color get colorFondo => AppTheme().colorFondo;
  static Color get colorTexto => AppTheme().colorTexto;
  static Color get colorNavBar => AppTheme().colorNavBar;
  static const Color colorPro = Color(0xFF7C3AED);
  static const Color colorVip = Color(0xFFD97706);

  // Versión de la app — se setea automáticamente en main() leyendo el APK.
  // NO editar a mano: pubspec.yaml es la única fuente de verdad.
  // El valor aquí es solo un fallback para unit tests sin runtime Flutter.
  static String version = "4.0.1+77"; // fallback — main() lo sobreescribe
  // Solo la parte semántica para mostrar en UI ("2.12.0")
  static String get versionDisplay =>
      version.contains('+') ? version.split('+').first : version;

  // ── version.json esperado en GitHub ──────────────────────────────────────
  // {
  //   "version":      "3.0.0",
  //   "apk_url":      "https://github.com/TU_USUARIO/TU_REPO/releases/download/v3.0.0/biofreq.apk",
  //   "changelog_es": "Nueva función disponible: Alembique V2 con síntesis CRISPR mejorada.",
  //   "config_url":   "https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/remote_config.json"
  // }
  // remote_config.json puede contener claves de strings a sobrescribir (PATCH).
  static const String taglineApp = "Gestor de Frecuencias Bioacústicas";

  // URL de la Cloud Function SQC
  // ⚠️ REEMPLAZA "TU_PROYECTO_ID" con el ID real de tu proyecto Firebase
  // ⚠️ En producción estas URLs apuntan al servidor Render (mismo que BioNotif._srv)
  // El servidor local las redirige a las Cloud Functions reales si están configuradas
  static String get sqcFunctionUrl {
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) return 'http://192.168.1.5:5000/generarSQC';
    return 'https://biofreq-servidor.onrender.com/generarSQC';
  }

  static String get alkamFunctionUrl {
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) return 'http://192.168.1.5:5000/mezclarAlkam';
    return 'https://biofreq-servidor.onrender.com/mezclarAlkam';
  }

  // EULA — texto legal completo
  static String get mpPreferenceUrl {
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) return 'http://192.168.1.5:5000/crearPreferenciaMp';
    return 'https://biofreq-servidor.onrender.com/crearPreferenciaMp';
  }

  static String get validarUsoSonidoSensibleUrl {
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) return 'http://192.168.1.5:5000/validarUsoSonidoSensible';
    return 'https://biofreq-servidor.onrender.com/validarUsoSonidoSensible';
  }

  static String get registrarEventoSeguridadUrl {
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) return 'http://192.168.1.5:5000/registrarEventoSeguridad';
    return 'https://biofreq-servidor.onrender.com/registrarEventoSeguridad';
  }

  static String get healthTecnicoAdminUrl {
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (isDebug) return 'http://192.168.1.5:5000/healthTecnicoAdmin';
    return 'https://biofreq-servidor.onrender.com/healthTecnicoAdmin';
  }

  static const String eulaTexto =
      'ACUERDO DE LICENCIA DE USUARIO FINAL (EULA) — BioFreq\n\n'
      '1. RIGOR CIENTÍFICO Y PROTOCOLO DE VALIDACIÓN\n'
      'BioFreq manifiesta que sus frecuencias han superado protocolos de '
      'investigación basados en estándares clínicos (Fases I, II y III), '
      'incluyendo estudios de doble ciego y pruebas con grupos de control.\n\n'
      'Estatus Regulatorio: Debido a su naturaleza bioacústica (no molecular), '
      'la plataforma se categoriza como Tecnología de Bienestar y Terapia '
      'Alternativa Coadyuvante. No sustituye el juicio médico profesional '
      'ni tratamientos alopáticos vigentes.\n\n'
      '2. PROPIEDAD INTELECTUAL Y PROTECCIÓN\n'
      'Todas las frecuencias y algoritmos son propiedad exclusiva de BioFreq. '
      'Queda prohibida la extracción, ingeniería inversa o redistribución de '
      'los sonidos. La piratería resultará en cierre de cuenta y acciones '
      'legales.\n\n'
      '3. SISTEMA DE TOKENS Y DONACIONES\n'
      'Los tokens son unidades de gestión interna. Las donaciones para la '
      'liberación de frecuencias son voluntarias y no reembolsables.\n\n'
      '4. LIMITACIÓN DE RESPONSABILIDAD\n'
      'BioFreq no se hace responsable por el mal uso (volumen excesivo) o uso '
      'en situaciones que requieran atención total (conducir, operar maquinaria).';

  // Helper: Firestore puede retornar números como int O double
  static int toInt(dynamic val, [int def = 0]) {
    if (val == null) return def;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString().split('.').first) ?? def;
  }

  static int costoUsoEstimadoSonido(Map<String, dynamic>? data) {
    if (data == null) return 0;

    final costoUso = toInt(data['costo_uso']);
    if (costoUso > 0) return costoUso;

    final legacyPrecio = toInt(data['duracion_seg']);
    if (legacyPrecio > 0) return legacyPrecio;

    final legacyDuracion = toInt(data['duracion_segundos']);
    if (legacyDuracion > 0) return legacyDuracion;

    return 0;
  }
}

class MacroSegmentoConfig {
  static List<Map<String, dynamic>>? _cache;
  static bool _loaded = false;

  static String _txt(dynamic value) => (value ?? '').toString().trim();

  static String normalizarPrefijo(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static Map<String, dynamic> normalizarSegmento(
    Map<String, dynamic> raw, {
    String? fallbackId,
  }) {
    final id = _txt(raw['id']).isNotEmpty
        ? _txt(raw['id'])
        : (fallbackId ??
            'macro_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}');
    final prefijo = normalizarPrefijo(_txt(raw['prefijo_codigo']));
    return {
      'id': id,
      'nombre': _txt(raw['nombre']),
      'descripcion': _txt(raw['descripcion']),
      'prefijo_codigo': prefijo,
      'activo': raw['activo'] != false,
      BioConfig.campoValorTokenCop:
          BioConfig.toInt(raw[BioConfig.campoValorTokenCop]),
      'can_invite': raw['can_invite'] is bool ? raw['can_invite'] : null,
      BioConfig.campoMaxInvitados:
          BioConfig.toInt(raw[BioConfig.campoMaxInvitados]),
      'editable_valor_token': raw['editable_valor_token'] == true,
      'editable_can_invite': raw['editable_can_invite'] == true,
      'editable_max_invitados': raw['editable_max_invitados'] == true,
    };
  }

  static Future<List<Map<String, dynamic>>> load({bool force = false}) async {
    if (!force && _loaded && _cache != null) return _cache!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(BioConfig.colConfiguracion)
          .doc(BioConfig.docSegmentosMacro)
          .get();
      final rawItems = (doc.data()?['segmentos'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      final items = rawItems
          .asMap()
          .entries
          .map(
            (entry) => normalizarSegmento(
              entry.value,
              fallbackId: 'macro_${entry.key}',
            ),
          )
          .where((item) => _txt(item['prefijo_codigo']).isNotEmpty)
          .toList()
        ..sort((a, b) {
          final pa = _txt(a['prefijo_codigo']);
          final pb = _txt(b['prefijo_codigo']);
          return pb.length.compareTo(pa.length);
        });
      _cache = items;
      _loaded = true;
      return items;
    } catch (e) {
      debugPrint('[Macro] Error cargando segmentos: $e');
      _cache = <Map<String, dynamic>>[];
      _loaded = true;
      return _cache!;
    }
  }

  static Future<void> saveAll(List<Map<String, dynamic>> items) async {
    final normalized = items
        .map((item) => normalizarSegmento(item))
        .where((item) => _txt(item['prefijo_codigo']).isNotEmpty)
        .toList()
      ..sort((a, b) {
        final pa = _txt(a['prefijo_codigo']);
        final pb = _txt(b['prefijo_codigo']);
        return pb.length.compareTo(pa.length);
      });
    await FirebaseFirestore.instance
        .collection(BioConfig.colConfiguracion)
        .doc(BioConfig.docSegmentosMacro)
        .set({
      'segmentos': normalized,
      'actualizada_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _cache = normalized;
    _loaded = true;
  }

  static Map<String, dynamic>? _matchByCode(
    List<Map<String, dynamic>> items,
    String code,
  ) {
    final normalizedCode = normalizarPrefijo(code);
    if (normalizedCode.isEmpty) return null;
    for (final item in items) {
      if (item['activo'] == false) continue;
      final prefijo = _txt(item['prefijo_codigo']);
      if (prefijo.isEmpty) continue;
      if (normalizedCode.startsWith(prefijo)) return item;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> resolveForCode(String code) async {
    final items = await load();
    return _matchByCode(items, code);
  }

  static Future<Map<String, dynamic>?> resolveForUserData(
    Map<String, dynamic> userData,
  ) async {
    final items = await load();
    final referido = _txt(userData[BioConfig.campoReferidoPor]);
    final codigoPropio = _txt(userData[BioConfig.campoCodigoPropio]);
    final matchReferido = _matchByCode(items, referido);
    final matchPropio = _matchByCode(items, codigoPropio);
    if (matchReferido == null) return matchPropio;
    if (matchPropio == null) return matchReferido;
    final lenReferido = _txt(matchReferido['prefijo_codigo']).length;
    final lenPropio = _txt(matchPropio['prefijo_codigo']).length;
    return lenPropio > lenReferido ? matchPropio : matchReferido;
  }

  static Map<String, dynamic> aplicarOverrides(
    Map<String, dynamic> userData,
    Map<String, dynamic>? segmento,
  ) {
    final merged = Map<String, dynamic>.from(userData);
    if (segmento == null) return merged;
    if (segmento['can_invite'] is bool) {
      merged['can_invite'] = segmento['can_invite'];
    }
    final maxInv = BioConfig.toInt(segmento[BioConfig.campoMaxInvitados]);
    if (maxInv > 0) {
      merged[BioConfig.campoMaxInvitados] = maxInv;
    }
    merged['segmento_macro_id'] = segmento['id'];
    merged['segmento_macro_nombre'] = segmento['nombre'];
    merged['segmento_macro_prefijo'] = segmento['prefijo_codigo'];
    return merged;
  }

  static bool _canInviteBase(Map<String, dynamic> userData) {
    final rol = _txt(userData['rol']);
    return userData['can_invite'] == true ||
        rol == BioConfig.rolAdmin ||
        rol == BioConfig.rolPS ||
        rol == BioConfig.rolTester ||
        rol == BioConfig.rolMarketing;
  }

  static Future<bool> resolveCanInviteForUserData(
    Map<String, dynamic> userData,
  ) async {
    final segmento = await resolveForUserData(userData);
    if (segmento != null && segmento['can_invite'] is bool) {
      return segmento['can_invite'] == true;
    }
    return _canInviteBase(userData);
  }

  static Future<int?> resolveMaxInvitadosForUserData(
    Map<String, dynamic> userData,
  ) async {
    final segmento = await resolveForUserData(userData);
    if (segmento != null) {
      final maxInv = BioConfig.toInt(segmento[BioConfig.campoMaxInvitados]);
      if (maxInv > 0) return maxInv;
    }
    final maxInv = BioConfig.toInt(userData[BioConfig.campoMaxInvitados]);
    return maxInv > 0 ? maxInv : null;
  }

  static Future<double> resolveValorTokenCopForUserData(
    Map<String, dynamic> userData, {
    double fallback = 100,
  }) async {
    final segmento = await resolveForUserData(userData);
    final override = BioConfig.toInt(segmento?[BioConfig.campoValorTokenCop]);
    if (override > 0) return override.toDouble();
    return fallback;
  }

  static Future<double> resolveValorTokenCopForUid(
    String uid, {
    double fallback = 100,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(uid)
          .get();
      if (!userDoc.exists || userDoc.data() == null) return fallback;
      return resolveValorTokenCopForUserData(
        Map<String, dynamic>.from(userDoc.data()!),
        fallback: fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  static Future<int> contarReferidosDirectos(String codigoPropio) async {
    final codigo = _txt(codigoPropio);
    if (codigo.isEmpty) return 0;
    final snap = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .where(BioConfig.campoReferidoPor, isEqualTo: codigo)
        .get();
    return snap.docs.length;
  }

  static Future<String?> validarUsoCodigoReferido(
    String codigoIngresado,
    Map<String, dynamic> invitadorData,
  ) async {
    final codigo = _txt(codigoIngresado).toUpperCase();
    if (codigo.isEmpty) return null;
    final segmento = await resolveForCode(codigo);
    bool canInvite = _canInviteBase(invitadorData);
    if (segmento != null && segmento['can_invite'] is bool) {
      canInvite = segmento['can_invite'] == true;
    }
    if (!canInvite) {
      return 'Este codigo no tiene invitaciones habilitadas.';
    }

    int? maxInv;
    if (segmento != null) {
      final segMax = BioConfig.toInt(segmento[BioConfig.campoMaxInvitados]);
      if (segMax > 0) maxInv = segMax;
    }
    maxInv ??= (() {
      final raw = BioConfig.toInt(invitadorData[BioConfig.campoMaxInvitados]);
      return raw > 0 ? raw : 0;
    })();

    if (maxInv > 0) {
      final directos = await contarReferidosDirectos(codigo);
      if (directos >= maxInv) {
        return 'Este codigo alcanzo su maximo de usuarios invitados.';
      }
    }
    return null;
  }

  static bool campoEditable(Map<String, dynamic>? segmento, String key) {
    if (segmento == null) return false;
    return segmento[key] == true;
  }
}

// ─────────────────────────────────────────────
// WRAPPER
// ─────────────────────────────────────────────
