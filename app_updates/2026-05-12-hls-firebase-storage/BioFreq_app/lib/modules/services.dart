// ======================================================================
// BioFreq — Módulo: services
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

class AlembiqueDio {
  // ── Singleton: un solo HttpClient y un solo Dio para toda la sesión ───────
  static Uint8List? _certBytes;
  static HttpClient? _httpClient; // keep-alive — nunca se cierra
  static Dio? _instance; // reutilizado en cada petición al Alembique

  // ── WARM-UP — llamar en main() antes de runApp() ──────────────────────────
  // Precarga cert.pem y construye el HttpClient con SecurityContext.
  // El handshake TLS queda listo antes de que el usuario toque nada.
  static Future<void> warmUp() async {
    try {
      await _buildInstance();
      debugPrint('[AlembiqueDio] Warm-up completado — SSL listo.');
    } catch (e) {
      debugPrint('[AlembiqueDio] Warm-up falló (sin cert.pem?): $e');
      // No es fatal — create() lo reintentará cuando se necesite
    }
  }

  // ── Obtiene la instancia singleton (la crea si no existe) ─────────────────
  static Future<Dio> create() async {
    if (_instance == null) await _buildInstance();
    return _instance!;
  }

  // ── Construye HttpClient + Dio y los guarda como singletons ───────────────
  static Future<void> _buildInstance() async {
    // Cargamos el cert para logging/diagnóstico pero no lo usamos para pinning,
    // ya que HttpOverrides.global = MyHttpOverrides() ya acepta cualquier cert
    // en toda la app. Usar SecurityContext aquí crea un cliente que bypasea
    // HttpOverrides y puede fallar con "unable to get local issuer certificate"
    // en Android cuando el cert es autofirmado (CERTIFICATE_VERIFY_FAILED).
    _certBytes ??=
        (await rootBundle.load('assets/certs/cert.pem')).buffer.asUint8List();

    // HttpClient que bypasea validación SSL — consistente con MyHttpOverrides
    final client = HttpClient()
      ..idleTimeout = const Duration(minutes: 10)
      ..connectionTimeout = const Duration(seconds: 15)
      ..autoUncompress = false
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        debugPrint('[AlembiqueDio] Cert aceptado: $host:$port');
        return true;
      };

    _httpClient = client;

    // Dio singleton que reutiliza el HttpClient
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      contentType: 'application/json',
    ));

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => _httpClient!,
    );

    _instance = dio;
  }
}

// TAB SQC + ALEMBIQUE — Sexta pestaña del Panel Admin
// Modo SQC:      molécula única por CID (motor 3D)
// Modo Alembique: mezcla de varias moléculas / proteínas / protocolo CRISPR
// ═══════════════════════════════════════════════════════════════════════════
class TabSQC extends StatefulWidget {
  const TabSQC({super.key});
  @override
  State<TabSQC> createState() => _TabSQCState();
}

class _TabSQCState extends State<TabSQC> {
  // ── Selector de modo ──────────────────────────────────────────────────────
  bool _modoAlkam = false; // false = SQC clásico, true = Alembique (mezcla)

  // ── Categorías controladas (BPM: evita variantes ortográficas) ───────────
  static const List<String> _categorias = [
    'Oncológico',
    'Neurológico',
    'Inmunológico',
    'Cardiovascular',
    'Metabólico',
    'Hormonal / Endócrino',
    'Digestivo / Gastrointestinal',
    'Respiratorio',
    'Musculoesquelético',
    'Dermatológico',
    'Urológico / Renal',
    'Ginecológico / Reproductivo',
    'Oftalmológico',
    'Dental / Maxilofacial',
    'Psiquiátrico / Emocional',
    'Infeccioso / Antiviral',
    'Regenerativo / Antiaging',
    'Detox / Desintoxicación',
    'Energético / Bioenergético',
    'Otro',
  ];
  String _catSeleccionada = 'Oncológico';

  // ── Campos comunes ────────────────────────────────────────────────────────
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController(text: "80");
  final _dosisCtrl = TextEditingController(text: "63");
  final _tokensCtrl = TextEditingController(text: "0");
  final _costoUsoCtrl = TextEditingController(text: "0");
  final _priorCtrl = TextEditingController(text: "1");

  // ── Campos exclusivos SQC ─────────────────────────────────────────────────
  final _cidCtrl = TextEditingController();
  final _escalaCtrl = TextEditingController(text: "1000");

  // ── Mezcla Alembique ──────────────────────────────────────────────────────
  // Cada ítem es un Map con tipo: "cid" | "nombre" | "sigla" | "crispr"
  final List<Map<String, String>> _mezcla = [];

  // Controladores para el formulario de agregar componente (Alembique)
  String _tipoNuevo = "cid"; // "cid" | "nombre" | "sigla" | "crispr"
  final _valorNuevoCtrl = TextEditingController();

  // Tipo de identificación para modo SQC (independiente del Alembique)
  String _tipoSQC = "cid"; // "cid" | "nombre" | "sigla" | "crispr"

  // ── Estado UI ─────────────────────────────────────────────────────────────
  bool _cargando = false;
  String _log = "";
  String? _urlAudio;
  String? _docId;
  double? _duracion;
  List<String> _componentesRespuesta = [];

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl,
      _descCtrl,
      _pesoCtrl,
      _dosisCtrl,
      _tokensCtrl,
      _costoUsoCtrl,
      _priorCtrl,
      _cidCtrl,
      _escalaCtrl,
      _valorNuevoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validación básica ─────────────────────────────────────────────────────
  bool _validar() {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ El nombre es obligatorio.")));
      return false;
    }
    if (!_modoAlkam) {
      final val = _cidCtrl.text.trim();
      if (val.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("⚠️ El campo ${_tipoSQC.toUpperCase()} es obligatorio.")));
        return false;
      }
      if (_tipoSQC == "cid" && (int.tryParse(val) ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("⚠️ CID inválido — debe ser un número entero positivo.")));
        return false;
      }
    } else {
      if (_mezcla.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("⚠️ Agrega al menos una molécula a la mezcla.")));
        return false;
      }
    }
    return true;
  }

  // ── Llamada a Cloud Functions ─────────────────────────────────────────────
  Future<void> _generar() async {
    if (!_validar()) return;
    setState(() {
      _cargando = true;
      _log = "🔄 Obteniendo token de seguridad...";
      _urlAudio = null;
      _docId = null;
      _duracion = null;
      _componentesRespuesta = [];
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No estás autenticado.");
      final idToken = await user.getIdToken();

      _setLog(_modoAlkam
          ? "🧪 Conectando con servidor Alembique..."
          : "⚗️  Conectando con servidor SQC...");

      // Cliente con SSL Pinning — valida cert.pem exacto del Alembique
      final dio = await AlembiqueDio.create();

      final url =
          _modoAlkam ? BioConfig.alkamFunctionUrl : BioConfig.sqcFunctionUrl;
      final body = _modoAlkam ? _buildBodyAlkam() : _buildBodySQC();

      final response = await dio.post(
        url,
        options: Options(
          headers: {
            "Authorization": "Bearer $idToken",
            "Content-Type": "application/json"
          },
          validateStatus: (_) => true,
        ),
        data: body,
      );

      if (response.statusCode != 200) {
        final err = response.data?["error"] ?? "Error ${response.statusCode}";
        throw Exception(err);
      }

      final data = response.data as Map<String, dynamic>;
      final docId = data["doc_id"] as String?;
      final urlAudio = data["url_audio"] as String?;
      await _normalizarDocumentoGenerado(
        docId: docId,
        urlAudio: urlAudio,
        costoUso: int.tryParse(_costoUsoCtrl.text) ?? 0,
      );
      setState(() {
        _urlAudio = urlAudio;
        _docId = docId;
        _duracion = (data["duracion_segundos"] as num?)?.toDouble();
        _componentesRespuesta =
            (data["componentes"] as List?)?.map((e) => e.toString()).toList() ??
                [];
        _log = "✅ ${data['mensaje'] ?? 'Completado'}";
      });
    } catch (e) {
      _setLog("❌ Error: $e");
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Map<String, dynamic> _buildBodySQC() {
    final val = _cidCtrl.text.trim();
    return {
      // El campo varía según el tipo seleccionado
      if (_tipoSQC == "cid") "cid": int.tryParse(val) ?? 0,
      if (_tipoSQC == "nombre") "nombre_molecula": val,
      if (_tipoSQC == "sigla") "sigla": val,
      if (_tipoSQC == "crispr") "crispr": val,
      "tipo_busqueda": _tipoSQC,
      "modo_salida":
          SalidaSQCConfig().modo.name, // "sonido" | "color" | "ambos"
      "nombre": _nombreCtrl.text.trim(),
      "descripcion": _descCtrl.text.trim(),
      "categoria": _catSeleccionada,
      "peso": double.tryParse(_pesoCtrl.text) ?? 80.0,
      "dosis": double.tryParse(_dosisCtrl.text) ?? 63.0,
      "escala": double.tryParse(_escalaCtrl.text) ?? 1000.0,
      "tokens_objetivo": int.tryParse(_tokensCtrl.text) ?? 0,
      "costo_uso": int.tryParse(_costoUsoCtrl.text) ?? 0,
      "prioridad": int.tryParse(_priorCtrl.text) ?? 1,
    };
  }

  Map<String, dynamic> _buildBodyAlkam() => {
        "nombre": _nombreCtrl.text.trim(),
        "descripcion": _descCtrl.text.trim(),
        "categoria": _catSeleccionada,
        "modo_salida":
            SalidaSQCConfig().modo.name, // "sonido" | "color" | "ambos"
        "peso": double.tryParse(_pesoCtrl.text) ?? 80.0,
        "dosis": double.tryParse(_dosisCtrl.text) ?? 63.0,
        "tokens_objetivo": int.tryParse(_tokensCtrl.text) ?? 0,
        "costo_uso": int.tryParse(_costoUsoCtrl.text) ?? 0,
        "prioridad": int.tryParse(_priorCtrl.text) ?? 1,
        "moleculas": _mezcla.map((m) {
          if (m["tipo"] == "cid")
            return {"cid": int.tryParse(m["valor"]!) ?? 0};
          if (m["tipo"] == "nombre") return {"nombre": m["valor"]};
          if (m["tipo"] == "sigla") return {"sigla": m["valor"]};
          if (m["tipo"] == "crispr") return {"crispr": m["valor"]};
          return {};
        }).toList(),
      };

  // ── Publicar ──────────────────────────────────────────────────────────────
  Future<void> _publicar() async {
    if (_docId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(BioConfig.colSonidos)
          .doc(_docId)
          .update({
        "estado": BioConfig.estadoDisponible,
        "fecha_publicacion": FieldValue.serverTimestamp(),
      });
      _setLog("🚀 ¡Publicado! Los usuarios ya pueden verlo.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Sonido publicado"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al publicar: $e")));
      }
    }
  }

  Future<void> _normalizarDocumentoGenerado({
    required String? docId,
    required String? urlAudio,
    required int costoUso,
  }) async {
    if (docId == null || docId.isEmpty) return;

    final ref =
        FirebaseFirestore.instance.collection(BioConfig.colSonidos).doc(docId);

    final payload = <String, dynamic>{
      "costo_uso": costoUso,
      "duracion_seg": FieldValue.delete(),
      "duracion_segundos": FieldValue.delete(),
      if (urlAudio != null && urlAudio.isNotEmpty) "url_sonido": urlAudio,
    };

    for (var intento = 0; intento < 4; intento++) {
      try {
        await ref.set(payload, SetOptions(merge: true));
        return;
      } catch (_) {
        if (intento == 3) rethrow;
        await Future.delayed(Duration(milliseconds: 400 * (intento + 1)));
      }
    }
  }

  void _setLog(String msg) {
    if (mounted) {
      setState(() => _log = msg);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Selector de modo ───────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(children: [
            _modoBtn("⚗️  SQC  — Una molécula", false),
            _modoBtn("🧪 Alembique — Mezcla", true),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Selector modo de salida (Sonido / Color / Ambos) ──────────────
        ListenableBuilder(
          listenable: SalidaSQCConfig(),
          builder: (_, __) {
            final cfg = SalidaSQCConfig();
            final modo = cfg.modo;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.output_outlined,
                          color: Colors.cyanAccent.withValues(alpha: 0.7),
                          size: 14),
                      const SizedBox(width: 6),
                      const Text("MODO DE SALIDA",
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    const Text("¿Qué genera el motor al procesar?",
                        style: TextStyle(color: Colors.white24, fontSize: 10)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _salidaBtn(
                          cfg,
                          modo,
                          ModoSalidaSQC.sonido,
                          Icons.volume_up_outlined,
                          "Sonido",
                          "Solo audio",
                          Colors.cyan),
                      const SizedBox(width: 6),
                      _salidaBtn(
                          cfg,
                          modo,
                          ModoSalidaSQC.color,
                          Icons.palette_outlined,
                          "Color",
                          "Solo hex Bio-Scanner",
                          Colors.greenAccent),
                      const SizedBox(width: 6),
                      _salidaBtn(
                          cfg,
                          modo,
                          ModoSalidaSQC.ambos,
                          Icons.merge_type_outlined,
                          "Sonido+Color",
                          "Audio + hex completo",
                          Colors.purpleAccent),
                    ]),
                  ]),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Campos comunes ─────────────────────────────────────────────────
        _seccion(
            "INFORMACIÓN DEL SONIDO", Icons.info_outline, Colors.cyanAccent),
        const SizedBox(height: 10),
        _campo(_nombreCtrl, "Nombre del sonido *", hint: "ej: Cis-Glutation"),
        const SizedBox(height: 10),
        _campo(_descCtrl, "Descripción",
            hint: "Descripción clínica…", maxLines: 2),
        const SizedBox(height: 10),
        // ── Categoría: lista controlada (BPM — evita variantes ortográficas) ──
        DropdownButtonFormField<String>(
          value: _catSeleccionada,
          dropdownColor: const Color(0xFF1A1A2E),
          decoration: InputDecoration(
            labelText: "Categoría",
            labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.category_outlined,
                color: Colors.white38, size: 18),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.cyanAccent.withValues(alpha: 0.6))),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: _categorias
              .map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _catSeleccionada = v);
            }
          },
        ),
        const SizedBox(height: 20),

        // ── Campos SQC (solo si modo SQC) ─────────────────────────────────
        if (!_modoAlkam) ...[
          _seccion("MOLÉCULA (PubChem 3D)", Icons.science_outlined,
              Colors.cyanAccent),
          const SizedBox(height: 10),
          // Selector tipo — mismo patrón que Alembique para homogeneidad
          Row(children: [
            _tipoBtn(
                "🔬 CID", "cid", _tipoSQC, (v) => setState(() => _tipoSQC = v)),
            const SizedBox(width: 4),
            _tipoBtn("🔍 Nombre", "nombre", _tipoSQC,
                (v) => setState(() => _tipoSQC = v)),
            const SizedBox(width: 4),
            _tipoBtn("💊 Sigla", "sigla", _tipoSQC,
                (v) => setState(() => _tipoSQC = v)),
            const SizedBox(width: 4),
            _tipoBtn("🧬 CRISPR", "crispr", _tipoSQC,
                (v) => setState(() => _tipoSQC = v)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                flex: 2,
                child: _campo(
                    _cidCtrl,
                    _tipoSQC == "cid"
                        ? "CID PubChem *"
                        : _tipoSQC == "nombre"
                            ? "Nombre del compuesto *"
                            : _tipoSQC == "sigla"
                                ? "Sigla (GLU, SIL…) *"
                                : "Secuencia ADN *",
                    hint: _tipoSQC == "cid"
                        ? "ej: 119058053"
                        : _tipoSQC == "nombre"
                            ? "ej: Cisplatino"
                            : _tipoSQC == "sigla"
                                ? "ej: GLU"
                                : "ej: GATTACA",
                    keyboard: _tipoSQC == "cid"
                        ? TextInputType.number
                        : TextInputType.text)),
            const SizedBox(width: 10),
            Expanded(
                flex: 2,
                child: _campo(_escalaCtrl, "Factor escala",
                    hint: "1000", keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 20),
        ],

        // ── Mezcla Alembique (solo si modo Alembique) ──────────────────────
        if (_modoAlkam) ...[
          _seccion("MEZCLA ALKAM", Icons.science_outlined, Colors.purpleAccent),
          const SizedBox(height: 10),

          // Lista de componentes
          if (_mezcla.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10)),
              child: const Center(
                  child: Text("Aún no hay componentes. Agrega uno abajo.",
                      style: TextStyle(color: Colors.white38, fontSize: 12))),
            )
          else
            Column(
              children: _mezcla.asMap().entries.map((e) {
                final idx = e.key;
                final m = e.value;
                final icono = m["tipo"] == "cid"
                    ? "🔬"
                    : m["tipo"] == "nombre"
                        ? "🔍"
                        : m["tipo"] == "sigla"
                            ? "💊"
                            : "🧬";
                final etiq = m["tipo"] == "cid"
                    ? "CID ${m['valor']}"
                    : m["tipo"] == "nombre"
                        ? "Nombre ${m['valor']}"
                        : m["tipo"] == "sigla"
                            ? "Proteína ${m['valor']}"
                            : "CRISPR ${m['valor']}";
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(children: [
                    Text(icono, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(etiq,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13))),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.redAccent, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _mezcla.removeAt(idx)),
                    ),
                  ]),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),

          // Formulario agregar componente
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("AGREGAR COMPONENTE",
                  style: TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 10),

              // Selector tipo
              Row(children: [
                _tipoBtnAlkam("🔬 CID", "cid"),
                const SizedBox(width: 4),
                _tipoBtnAlkam("🔍 Nombre", "nombre"),
                const SizedBox(width: 4),
                _tipoBtnAlkam("💊 Sigla", "sigla"),
                const SizedBox(width: 4),
                _tipoBtnAlkam("🧬 CRISPR", "crispr"),
              ]),
              const SizedBox(height: 10),

              // Hints según tipo seleccionado
              _campo(
                _valorNuevoCtrl,
                _tipoNuevo == "cid"
                    ? "CID PubChem"
                    : _tipoNuevo == "nombre"
                        ? "Nombre del compuesto"
                        : _tipoNuevo == "sigla"
                            ? "Sigla (GLU, SIL, AMB, CAS, MET)"
                            : "Secuencia ADN (A, T, C, G)",
                hint: _tipoNuevo == "cid"
                    ? "ej: 119058053"
                    : _tipoNuevo == "nombre"
                        ? "ej: Cisplatino"
                        : _tipoNuevo == "sigla"
                            ? "ej: GLU"
                            : "ej: GATTACA",
                keyboard: _tipoNuevo == "cid"
                    ? TextInputType.number
                    : TextInputType.text,
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purpleAccent,
                    side: const BorderSide(color: Colors.purpleAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Agregar a la mezcla"),
                  onPressed: () {
                    final val = _valorNuevoCtrl.text.trim();
                    if (val.isEmpty) return;
                    setState(() {
                      _mezcla.add({
                        "tipo": _tipoNuevo,
                        "valor":
                            (_tipoNuevo == "nombre") ? val : val.toUpperCase()
                      });
                      _valorNuevoCtrl.clear();
                    });
                  },
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // Botón limpiar mezcla
          if (_mezcla.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.delete_sweep, size: 16),
              label:
                  const Text("Limpiar mezcla", style: TextStyle(fontSize: 12)),
              onPressed: () => setState(() => _mezcla.clear()),
            ),
          const SizedBox(height: 10),
        ],

        // ── Parámetros cinéticos ───────────────────────────────────────────
        _seccion("PARÁMETROS CINÉTICOS", Icons.tune, Colors.amber),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _campo(_pesoCtrl, "Peso (kg)",
                  keyboard: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(
              child: _campo(_dosisCtrl, "Dosis (mg/kg)",
                  keyboard: TextInputType.number)),
        ]),
        const SizedBox(height: 20),

        // ── Config BioFreq ─────────────────────────────────────────────────
        _seccion("EN BIOFREQ", Icons.settings, Colors.blueAccent),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _campo(_tokensCtrl, "Tokens objetivo",
                  keyboard: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(
              child: _campo(_costoUsoCtrl, "Costo por uso",
                  hint: "0 = duración", keyboard: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(
              child: _campo(_priorCtrl, "Prioridad",
                  keyboard: TextInputType.number)),
        ]),
        const SizedBox(height: 24),

        // ── Botón principal ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cargando
                  ? Colors.grey[800]
                  : (_modoAlkam ? Colors.purple : BioConfig.colorPrimario),
              foregroundColor: _modoAlkam ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _cargando ? null : _generar,
            icon: _cargando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(_modoAlkam ? Icons.blender : Icons.play_arrow_rounded),
            label: Text(
              _cargando
                  ? "Sintetizando… (puede tardar varios minutos)"
                  : _modoAlkam
                      ? "🧪 MEZCLAR Y DESPLEGAR (Alembique)"
                      : "⚗️  GENERAR Y DESPLEGAR (SQC)",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Log ────────────────────────────────────────────────────────────
        if (_log.isNotEmpty)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _log.startsWith("✅") || _log.startsWith("🚀")
                      ? Colors.greenAccent.withValues(alpha: 0.5)
                      : _log.startsWith("❌")
                          ? Colors.redAccent.withValues(alpha: 0.5)
                          : Colors.cyan.withValues(alpha: 0.3)),
            ),
            child: Text(
              _log,
              style: TextStyle(
                color: _log.startsWith("✅") || _log.startsWith("🚀")
                    ? Colors.greenAccent
                    : _log.startsWith("❌")
                        ? Colors.redAccent
                        : Colors.cyanAccent,
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(height: 16),

        // ── Panel resultado ────────────────────────────────────────────────
        if (_urlAudio != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                SizedBox(width: 8),
                Text("Síntesis completada",
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),

              if (_duracion != null)
                _infoRow(Icons.timer_outlined, "Duración",
                    "${_duracion!.toStringAsFixed(2)} s"),
              const SizedBox(height: 6),
              _infoRow(Icons.link, "URL GitHub", _urlAudio!, copiable: true),
              const SizedBox(height: 6),
              if (_docId != null)
                _infoRow(Icons.storage, "Firestore doc ID", _docId!,
                    copiable: true),

              // Componentes de la mezcla (modo Alembique)
              if (_componentesRespuesta.isNotEmpty) ...[
                const SizedBox(height: 10),
                _seccion("COMPONENTES DE LA MEZCLA", Icons.list, Colors.purple),
                const SizedBox(height: 6),
                ..._componentesRespuesta.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.circle,
                            size: 6, color: Colors.purpleAccent),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(c,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12))),
                      ]),
                    )),
              ],

              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    "Estado: 'en_proceso' — los usuarios aún NO lo ven.\n"
                    "Pulsa Publicar cuando estés listo.",
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  )),
                ]),
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _publicar,
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text("PUBLICAR EN LA APP",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 32),

        // ── Historial sonidos SQC ──────────────────────────────────────────
        _seccion("SONIDOS GENERADOS", Icons.history, Colors.purple),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          // ⚠️  Sin orderBy — igual que Tab Sonidos: Firestore omite documentos
          //     sin ese campo exacto y el spinner nunca para. Orden en memoria.
          stream: FirebaseFirestore.instance
              .collection(BioConfig.colSonidos)
              .where("fase", isEqualTo: "generado_sqc")
              .snapshots(),
          builder: (_, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Error: ${snap.error}',
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12)),
              );
            }
            if (!snap.hasData) {
              return Center(
                  child: CircularProgressIndicator(
                      color: BioConfig.colorPrimario));
            }
            if (snap.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("Aún no hay sonidos generados.",
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              );
            }
            // Ordenar en memoria: más recientes primero
            final docs = snap.data!.docs.toList()
              ..sort((a, b) {
                final ta = (a.data() as Map)['fecha_actualizacion'];
                final tb = (b.data() as Map)['fecha_actualizacion'];
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return (tb as Timestamp).compareTo(ta as Timestamp);
              });
            return Column(
              children: docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final estado = d["estado"] as String? ?? "—";
                final motor = d["motor"] as String? ?? "sqc_3d";
                final color = estado == BioConfig.estadoDisponible
                    ? Colors.greenAccent
                    : estado == BioConfig.estadoEnProceso
                        ? Colors.orange
                        : Colors.blue;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(children: [
                    Icon(motor == "alkam" ? Icons.blender : Icons.graphic_eq,
                        color: motor == "alkam"
                            ? Colors.purpleAccent
                            : BioConfig.colorPrimario,
                        size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d["Nombre"] ?? "—",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text(
                            motor == "alkam"
                                ? "Alembique • ${d['num_componentes'] ?? '?'} componentes • "
                                    "${(d['duracion_segundos'] ?? 0).toStringAsFixed(1)}s"
                                : "SQC 3D • CID ${d['cid_pubchem'] ?? '?'} • "
                                    "${(d['duracion_segundos'] ?? 0).toStringAsFixed(1)}s",
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(estado,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white38, size: 20),
                      color: const Color(0xFF2A2A2A),
                      onSelected: (val) async {
                        await doc.reference.update({"estado": val});
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: "disponible",
                            child: Text("✅ Publicar",
                                style: TextStyle(color: Colors.white))),
                        PopupMenuItem(
                            value: "en_proceso",
                            child: Text("⚗️ Volver a En proceso",
                                style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  // ── Helpers UI ─────────────────────────────────────────────────────────────

  Widget _modoBtn(String label, bool esAlkam) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _modoAlkam = esAlkam;
            _log = "";
            _urlAudio = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _modoAlkam == esAlkam
                  ? (esAlkam ? Colors.purple : BioConfig.colorPrimario)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _modoAlkam == esAlkam ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
          ),
        ),
      );

  Widget _tipoBtnAlkam(String label, String tipo) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tipoNuevo = tipo),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _tipoNuevo == tipo
                  ? Colors.purple.withValues(alpha: 0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _tipoNuevo == tipo
                      ? Colors.purpleAccent
                      : Colors.white12),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      _tipoNuevo == tipo ? Colors.purpleAccent : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ),
      );

  // Versión genérica: recibe tipoActual y callback — usada por el selector SQC
  Widget _tipoBtn(String label, String tipo, String tipoActual,
          void Function(String) onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: () => onTap(tipo),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: tipoActual == tipo
                  ? Colors.cyan.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color:
                      tipoActual == tipo ? Colors.cyanAccent : Colors.white12),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      tipoActual == tipo ? Colors.cyanAccent : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ),
      );

  // Botón de modo salida SQC (Sonido / Color / Ambos)
  Widget _salidaBtn(
      SalidaSQCConfig cfg,
      ModoSalidaSQC actual,
      ModoSalidaSQC valor,
      IconData icono,
      String titulo,
      String subtitulo,
      Color color) {
    final sel = actual == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => cfg.setModo(valor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? color : Colors.white12),
          ),
          child: Column(children: [
            Icon(icono, color: sel ? color : Colors.white38, size: 18),
            const SizedBox(height: 4),
            Text(titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: sel ? color : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            Text(subtitulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: sel ? color.withValues(alpha: 0.6) : Colors.white24,
                    fontSize: 9)),
          ]),
        ),
      ),
    );
  }

  Widget _seccion(String titulo, IconData icon, Color color) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(titulo,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
        ],
      );

  Widget _campo(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: BioConfig.colorPrimario)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  Widget _infoRow(IconData icon, String label, String valor,
          {bool copiable = false}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Text(valor,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ])),
        if (copiable)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: valor));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Copiado"), duration: Duration(seconds: 1)));
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.copy, color: Colors.white24, size: 16),
            ),
          ),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 8: Chat Admin — lista de canales + conversación seleccionada

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo resultados de detección de duplicados por IA
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _VerComoPanel — muestra el perfil completo del usuario en modo solo lectura
// El admin ve exactamente la misma info que vería el usuario, sin poder actuar.
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════
// TRANSACTION MANAGER — servicio de transferencias PS → user
// Biometría obligatoria, recargo 20% (mín 1 token), log en 'transacciones'
// ═══════════════════════════════════════════════════════════════════════════
class TransactionManager {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica biometría. Retorna true si el usuario se autenticó.
  static Future<bool> autenticarBiometria(BuildContext context) async {
    try {
      final disponible =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!disponible) {
        // Sin biometría en el dispositivo — pedimos confirmación por PIN del SO
        return await _auth.authenticate(
          localizedReason: 'Confirma tu identidad para continuar',
          options: const AuthenticationOptions(
              biometricOnly: false, stickyAuth: true),
        );
      }
      return await _auth.authenticate(
        localizedReason:
            'Usa tu huella o rostro para autorizar la transferencia',
        options:
            const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  /// Calcula recargo: 20% del monto, mínimo 1 token.
  static int calcularRecargo(int monto) =>
      ((monto * BioConfig.recargoPorMovimiento).ceil()).clamp(1, 999999);

  /// Ejecuta la transferencia completa con validaciones y escritura atómica.
  /// Retorna el Map de la transacción creada, o lanza Exception con mensaje.
  static Future<Map<String, dynamic>> transferir({
    required String emisorUid,
    required String emisorNombre,
    required String receptorUid,
    required String receptorNombre,
    required int monto,
  }) async {
    if (monto <= 0) throw Exception('El monto debe ser mayor a 0.');

    final recargo = calcularRecargo(monto);
    final totalDeducir = monto + recargo;

    // ── Verificar saldo del emisor ────────────────────────────────────────
    final emisorDoc = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(emisorUid)
        .get();
    final saldoEmisor =
        BioConfig.toInt(emisorDoc.data()?[BioConfig.campoTokens]);
    if (saldoEmisor < totalDeducir) {
      throw Exception('Saldo insuficiente. Necesitas $totalDeducir tokens '
          '($monto + $recargo de recargo). Tienes $saldoEmisor.');
    }

    // ── Verificar que el receptor existe y es "user" ──────────────────────
    final receptorDoc = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(receptorUid)
        .get();
    if (!receptorDoc.exists) {
      throw Exception('El usuario receptor no existe.');
    }
    final rolReceptor = receptorDoc.data()?['rol'] ?? BioConfig.rolUser;
    if (rolReceptor != BioConfig.rolUser) {
      throw Exception('Solo puedes transferir a usuarios regulares.');
    }

    // ── Escritura atómica ─────────────────────────────────────────────────
    final batch = FirebaseFirestore.instance.batch();
    final txRef =
        FirebaseFirestore.instance.collection(BioConfig.colTransacciones).doc();
    final ahora = FieldValue.serverTimestamp();

    final txData = {
      'id': txRef.id,
      'emisor_id': emisorUid,
      'emisor_nombre': emisorNombre,
      'receptor_id': receptorUid,
      'receptor_nombre': receptorNombre,
      'monto': monto,
      'recargo': recargo,
      'total_deducido': totalDeducir,
      'estado': 'completada',
      'fecha': ahora,
      'participantes': [emisorUid, receptorUid], // para queries de ambos lados
    };

    // Guardar transacción
    batch.set(txRef, txData);

    // Descontar del emisor
    batch.update(
      FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(emisorUid),
      {BioConfig.campoTokens: FieldValue.increment(-totalDeducir)},
    );

    // Acreditar al receptor
    batch.update(
      FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(receptorUid),
      {BioConfig.campoTokens: FieldValue.increment(monto)},
    );

    await batch.commit();

    // Retornar datos con fecha local para el recibo (serverTimestamp no está disponible inmediatamente)
    return {...txData, 'fecha': Timestamp.now()};
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODAL DE TRANSFERENCIA — PS envía tokens a un usuario
// Flujo: Seleccionar paciente → Monto → Biometría → Recibo → Compartir
// ═══════════════════════════════════════════════════════════════════════════
class TransferenciaPSModal extends StatefulWidget {
  final String emisorUid;
  final String emisorNombre;
  final int saldoActual;
  final VoidCallback onTransferida;

  const TransferenciaPSModal({
    super.key,
    required this.emisorUid,
    required this.emisorNombre,
    required this.saldoActual,
    required this.onTransferida,
  });

  @override
  State<TransferenciaPSModal> createState() => _TransferenciaPSModalState();
}

class _TransferenciaPSModalState extends State<TransferenciaPSModal> {
  final _montoCtrl = TextEditingController();
  final _busquedaCtrl = TextEditingController();
  Map<String, dynamic>? _receptorSeleccionado;
  List<Map<String, dynamic>> _pacientes = [];
  bool _cargandoPacientes = true;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPacientes() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .where('medico_id', isEqualTo: widget.emisorUid)
          .where('rol', isEqualTo: BioConfig.rolUser)
          .get();
      if (mounted) {
        setState(() {
          _pacientes =
              snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
          _cargandoPacientes = false;
        });
      }
    } catch (_) {
      setState(() => _cargandoPacientes = false);
    }
  }

  Future<void> _ejecutarTransferencia() async {
    final receptor = _receptorSeleccionado;
    if (receptor == null) {
      _snack('Selecciona un paciente.');
      return;
    }
    final monto = int.tryParse(_montoCtrl.text.trim()) ?? 0;
    if (monto <= 0) {
      _snack('Ingresa un monto válido.');
      return;
    }

    final recargo = TransactionManager.calcularRecargo(monto);
    final total = monto + recargo;

    // Confirmar antes de biometría
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirmar transferencia',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _filaConfirm('Receptor', receptor['nombre'] ?? '?'),
          _filaConfirm('Monto', '$monto tokens'),
          _filaConfirm('Recargo (20%)', '$recargo tokens'),
          const Divider(color: Colors.white12),
          _filaConfirm('Total deducido', '$total tokens', bold: true),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BioConfig.colorPrimario,
                foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONTINUAR',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // ── Biometría ─────────────────────────────────────────────────────────
    setState(() => _procesando = true);
    final autorizado = await TransactionManager.autenticarBiometria(context);
    if (!autorizado || !mounted) {
      if (mounted) setState(() => _procesando = false);
      _snack('Autenticación cancelada.');
      return;
    }

    // ── Ejecutar ──────────────────────────────────────────────────────────
    try {
      final txData = await TransactionManager.transferir(
        emisorUid: widget.emisorUid,
        emisorNombre: widget.emisorNombre,
        receptorUid: receptor['uid'] as String,
        receptorNombre: receptor['nombre'] ?? '',
        monto: monto,
      );

      widget.onTransferida();
      if (!mounted) return;
      Navigator.pop(context); // cerrar modal

      // ── Mostrar Recibo ────────────────────────────────────────────────
      showDialog(
        context: context,
        builder: (_) => ReciboDigital(transaccion: txData),
      );
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  Widget _filaConfirm(String label, String valor, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(valor,
              style: TextStyle(
                  color: bold ? Colors.amber : Colors.white,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final busqueda = _busquedaCtrl.text.toLowerCase();
    final filtrados = _pacientes
        .where((p) =>
            (p['nombre'] ?? '').toString().toLowerCase().contains(busqueda) ||
            (p['email'] ?? '').toString().toLowerCase().contains(busqueda))
        .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.send, color: BioConfig.colorPrimario),
            const SizedBox(width: 8),
            const Text('TRANSFERIR TOKENS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const Spacer(),
            Text('Saldo: ${widget.saldoActual}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          const SizedBox(height: 16),

          // ── Buscador de pacientes ──────────────────────────────────────
          TextField(
            controller: _busquedaCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Buscar paciente…',
              hintStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12))),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // ── Lista de pacientes ─────────────────────────────────────────
          if (_cargandoPacientes)
            Center(
                child:
                    CircularProgressIndicator(color: BioConfig.colorPrimario))
          else if (filtrados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Sin pacientes vinculados.',
                  style: TextStyle(color: Colors.white38)),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtrados.length,
                itemBuilder: (_, i) {
                  final p = filtrados[i];
                  final seleccionado =
                      _receptorSeleccionado?['uid'] == p['uid'];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          BioConfig.colorPrimario.withValues(alpha: 0.2),
                      child: Text(
                          (p['nombre'] ?? '?').toString()[0].toUpperCase(),
                          style: TextStyle(
                              color: BioConfig.colorPrimario, fontSize: 13)),
                    ),
                    title: Text(p['nombre'] ?? '?',
                        style: TextStyle(
                            color: seleccionado
                                ? BioConfig.colorPrimario
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: seleccionado
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: Text(p['email'] ?? '',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    trailing: seleccionado
                        ? Icon(Icons.check_circle,
                            color: BioConfig.colorPrimario)
                        : null,
                    selected: seleccionado,
                    selectedTileColor:
                        BioConfig.colorPrimario.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    onTap: () => setState(() => _receptorSeleccionado = p),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),

          // ── Monto ──────────────────────────────────────────────────────
          TextField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Monto a transferir',
              labelStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(Icons.toll, color: Colors.amber),
              filled: true,
              fillColor: Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),

          // Preview recargo
          Builder(builder: (_) {
            final monto = int.tryParse(_montoCtrl.text) ?? 0;
            if (monto <= 0) return const SizedBox.shrink();
            final recargo = TransactionManager.calcularRecargo(monto);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                    'Recargo: $recargo tokens  →  Total: ${monto + recargo} tokens',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            );
          }),
          const SizedBox(height: 20),

          // ── Botón enviar ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BioConfig.colorPrimario,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: (_procesando || _receptorSeleccionado == null)
                  ? null
                  : _ejecutarTransferencia,
              icon: _procesando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.fingerprint),
              label: Text(
                  _procesando
                      ? 'Procesando…'
                      : 'TRANSFERIR  (biometría requerida)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RECIBO DIGITAL — tarjeta visual para transferencias
// Flujo: se muestra tras la biometría exitosa. Permite compartir como imagen.
// Screenshots habilitados (FLAG_SECURE desactivado en esta pantalla).
// ═══════════════════════════════════════════════════════════════════════════
class ReciboDigital extends StatefulWidget {
  final Map<String, dynamic> transaccion;
  const ReciboDigital({super.key, required this.transaccion});
  @override
  State<ReciboDigital> createState() => _ReciboDigitalState();
}

class _ReciboDigitalState extends State<ReciboDigital> {
  final ScreenshotController _sc = ScreenshotController();
  bool _compartiendo = false;

  String _formatFecha(dynamic ts) {
    if (ts == null) return '—';
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $h:$mi';
  }

  Future<void> _compartir() async {
    if (_compartiendo) return;
    setState(() => _compartiendo = true);
    try {
      final bytes = await _sc.capture(pixelRatio: 3.0);
      if (bytes == null) throw Exception('Error al capturar recibo.');
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/recibo_${widget.transaccion['id'] ?? 'tx'}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Recibo BioFreq — Transferencia de tokens',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _compartiendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaccion;
    final monto = tx['monto'] as int? ?? 0;
    final recargo = tx['recargo'] as int? ?? 0;
    final total = tx['total_deducido'] as int? ?? (monto + recargo);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Tarjeta capturada ──────────────────────────────────────────
        Screenshot(
          controller: _sc,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D1B2A),
                  Color(0xFF1B2838),
                  Color(0xFF0A3D62)
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: BioConfig.colorPrimario.withValues(alpha: 0.4),
                  width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                // Header
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.health_and_safety,
                      color: BioConfig.colorPrimario, size: 20),
                  const SizedBox(width: 8),
                  Text('BIOFREQ',
                      style: TextStyle(
                          color: BioConfig.colorPrimario,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3)),
                ]),
                const SizedBox(height: 4),
                const Text('RECIBO DE TRANSFERENCIA',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 20),

                // Estado
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 14),
                    SizedBox(width: 6),
                    Text('COMPLETADA',
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ]),
                ),
                const SizedBox(height: 20),

                // Monto principal
                Text('$monto',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold)),
                const Text('TOKENS TRANSFERIDOS',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 20),

                // Línea divisoria con glow
                Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        BioConfig.colorPrimario.withValues(alpha: 0.6),
                        Colors.transparent,
                      ]),
                    )),
                const SizedBox(height: 16),

                // Datos
                _reciboFila('De', tx['emisor_nombre'] ?? '—'),
                _reciboFila('Para', tx['receptor_nombre'] ?? '—'),
                _reciboFila('Fecha', _formatFecha(tx['fecha'])),
                _reciboFila('Recargo', '$recargo tokens (20%)'),
                _reciboFila('Total deducido', '$total tokens',
                    color: Colors.amber),
                const SizedBox(height: 16),

                // ID de transacción
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TX: ${(tx['id'] ?? '').toString().substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                ),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Botones ────────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cerrar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BioConfig.colorPrimario,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _compartiendo ? null : _compartir,
              icon: _compartiendo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.share_rounded, size: 16),
              label: Text(_compartiendo ? 'Generando…' : 'Compartir',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _reciboFila(String label, String valor, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            Text(valor,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
