// ======================================================================
// BioFreq — Módulo: account
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

class PantallaMiCuenta extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> uData;
  // ⚠️  remoteVersion: versión disponible en GitHub — SIEMPRE pasar desde el
  //     padre (_BioFreqAppState._remoteVersion). Sin esto el botón muestra la
  //     versión local en vez de la última disponible.
  final VersionInfo? remoteVersion;
  const PantallaMiCuenta({
    super.key,
    required this.uid,
    required this.uData,
    this.remoteVersion, // opcional para no romper compilaciones antiguas
  });
  @override
  State<PantallaMiCuenta> createState() => _PantallaMiCuentaState();
}

class _PantallaMiCuentaState extends State<PantallaMiCuenta> {
  final _llaveCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  String _sexo = '';
  String _tipoId = '';
  final _numIdCtrl = TextEditingController();
  bool _esVoluntario = false;
  bool _guardando = false;

  // ── Descarga APK ──────────────────────────────────────────────────────────
  bool _descargando = false;
  double _progresoDescarga = 0.0;

  // ⚠️  URL fallback hardcoded — se usa solo si remoteVersion.apkUrl es null.
  //     Actualizar cuando cambie la URL del Drive. Lo ideal es mantenerla
  //     actualizada en el remote_config.json de GitHub (campo apk_url).
  String get _apkUrl => AppUpdateConfig.resolve(widget.remoteVersion?.apkUrl);
  String? get _apkSha256 => widget.remoteVersion?.apkSha256;

  // ⚠️  Usar .raw del VersionInfo remoto — es el string exacto del version.json
  //     (ej: "4.0.0"). Si aún no cargó, mostrar "…" en lugar de la versión
  //     instalada para no confundir al usuario.
  String get _versionRemotaLabel {
    final rv = widget.remoteVersion;
    if (rv == null) return '…';
    // raw puede incluir build number ("4.0.0+76") — mostrar solo semver
    final semver = rv.raw.contains('+') ? rv.raw.split('+').first : rv.raw;
    return 'v$semver';
  }

  // Descarga el APK a un archivo temporal y lo abre con el instalador nativo.
  // Usa Dio (ya disponible) para mostrar progreso real.
  // Si Android rechaza por REQUEST_INSTALL_PACKAGES, abre la config del sistema.
  // ════════════════════════════════════════════════════════════════
  // ⚠️  INSTALADOR APK — pide permiso REQUEST_INSTALL_PACKAGES
  //     ANTES de descargar. Android 8+ lo exige en runtime.
  //     Sin este check la instalación falla silenciosamente.
  //     NO simplificar este flujo ni eliminar el check de permiso.
  // ════════════════════════════════════════════════════════════════
  Future<void> _descargarEInstalarAPK() async {
    if (_descargando) return;

    if (mounted) {
      setState(() {
        _descargando = true;
        _progresoDescarga = 0;
      });
    }

    try {
      await instalarActualizacionDesdeUrl(
        context,
        _apkUrl,
        expectedSha256: _apkSha256,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progresoDescarga = progress);
        },
      );

      // Dio con HttpOverrides ya activo → SSL no bloqueará la descarga de Drive

      // ⚠️  Abrir con instalador nativo.
      //     Si falla por REQUEST_INSTALL_PACKAGES (permiso denegado),
      //     llevamos al usuario a Configuración en vez de mostrar un error mudo.
      //     AndroidManifest.xml DEBE tener:
      //       <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    } finally {
      if (mounted) {
        setState(() {
          _descargando = false;
          _progresoDescarga = 0;
        });
      }
    }
  }

  // ── Solicitud PS ──
  bool _solicitandoPS = false;
  bool _mostrarFormPS = false;
  final _psNombreCtrl = TextEditingController();
  final _psCedulaCtrl = TextEditingController();
  final _psRegistroCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-llenar con datos existentes
    _llaveCtrl.text = widget.uData['llave_breb'] ?? '';
    _edadCtrl.text = widget.uData['edad']?.toString() ?? '';
    _sexo = widget.uData['sexo'] ?? '';
    _tipoId = widget.uData['tipo_id'] ?? '';
    _numIdCtrl.text = widget.uData['numero_id']?.toString() ?? '';
    _esVoluntario = widget.uData['rol'] == 'voluntario';
  }

  @override
  void dispose() {
    _llaveCtrl.dispose();
    _edadCtrl.dispose();
    _numIdCtrl.dispose();
    _psNombreCtrl.dispose();
    _psCedulaCtrl.dispose();
    _psRegistroCtrl.dispose();
    super.dispose();
  }

  // ── Modal QR de invitación ──────────────────────────────────────────────
  void _mostrarQR(BuildContext context, String codigo) {
    // Link de descarga con código incrustado — el usuario solo toca y listo
    final String linkConCodigo = AppUpdateConfig.withReferralCode(codigo);
    final String mensajeCompartir =
        '🎵 Te invito a BioFreq — terapias bioacústicas\n\n'
        '👉 Descarga la app aquí:\n$linkConCodigo\n\n'
        '📋 Tu código de acceso: $codigo\n'
        '(Ingrésalo al registrarte si la app lo pide)';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Invita a alguien a BioFreq',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Comparte el QR, el link o el código',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),

          // ── QR ──────────────────────────────────────────────────
          // QR codifica el link completo — escanear abre descarga directa
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 20)
                ],
              ),
              child: RepaintBoundary(
                child: QrImageView(
                  data: linkConCodigo,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme().qrForeground,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppTheme().qrForeground,
                  ),
                  backgroundColor: AppTheme().qrBackground,
                  gapless: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Escanear abre la descarga directamente',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 20),

          // ── Código ──────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado 📋')));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(codigo,
                    style: const TextStyle(
                        color: Colors.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 3)),
                const SizedBox(width: 10),
                const Icon(Icons.copy, color: Colors.cyan, size: 16),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // ── Link completo ───────────────────────────────────────
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: linkConCodigo));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copiado 🔗')));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                const Icon(Icons.link, color: Colors.white38, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(linkConCodigo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10))),
                const Icon(Icons.copy, color: Colors.white24, size: 14),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Botón compartir ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BioConfig.colorPrimario,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Compartir invitación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => Share.share(mensajeCompartir,
                  subject: 'Te invito a BioFreq 🎵'),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _guardar() async {
    // Voluntarios deben tener todos los campos
    if (_esVoluntario) {
      if (_edadCtrl.text.trim().isEmpty ||
          _sexo.isEmpty ||
          _tipoId.isEmpty ||
          _numIdCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Como voluntario debes completar edad, sexo, tipo y número de ID.")));
        return;
      }
    }
    setState(() => _guardando = true);
    try {
      Map<String, dynamic> datos = {};
      if (_llaveCtrl.text.trim().isNotEmpty) {
        datos['llave_breb'] = _llaveCtrl.text.trim();
      }
      if (_edadCtrl.text.trim().isNotEmpty) {
        datos['edad'] = int.tryParse(_edadCtrl.text.trim()) ?? 0;
      }
      if (_sexo.isNotEmpty) datos['sexo'] = _sexo;
      if (_tipoId.isNotEmpty) datos['tipo_id'] = _tipoId;
      if (_numIdCtrl.text.trim().isNotEmpty) {
        datos['numero_id'] = _numIdCtrl.text.trim();
      }

      await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(widget.uid)
          .update(datos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Datos guardados correctamente")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  // ── Chip de selección para "Ver como" ────────────────────────────────────
  Widget _chipVerComo({
    required String label,
    required bool seleccionado,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: seleccionado
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: seleccionado ? color : Colors.white12,
              width: seleccionado ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: seleccionado ? color : Colors.white38,
                fontSize: 12,
                fontWeight:
                    seleccionado ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BioConfig.colorPrimario)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
      );

  @override
  Widget build(BuildContext context) {
    final String codigo = widget.uData[BioConfig.campoCodigoPropio] ?? '---';
    final String email = FirebaseAuth.instance.currentUser?.email ?? '';
    final String nivel =
        widget.uData[BioConfig.campoNivel] ?? BioConfig.nivelBasico;
    final int tokens = BioConfig.toInt(widget.uData[BioConfig.campoTokens]);

    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text("Mi Cuenta",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white70),
        ),
        body: BioPageBackground(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Resumen ──────────────────────────────────────────────────────
                BioGlassPanel(
                  padding: const EdgeInsets.all(18),
                  radius: 24,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.person_outline,
                              color: BioConfig.colorPrimario, size: 20),
                          const SizedBox(width: 8),
                          Text(email,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.toll, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text("$tokens tokens disponibles",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.star_outline,
                              color: AccesibleColors.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text("Nivel: ${nivel.toUpperCase()}",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ]),
                        const SizedBox(height: 10),
                        // ── Código + QR de invitación ──────────────────────────
                        GestureDetector(
                          onTap: () => _mostrarQR(context, codigo),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: BioConfig.colorPrimario
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: BioConfig.colorPrimario
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Row(children: [
                              Icon(Icons.qr_code_rounded,
                                  color: BioConfig.colorPrimario, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Código de invitación',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 11)),
                                  Text(codigo,
                                      style: TextStyle(
                                          color: BioConfig.colorPrimario,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 1.5)),
                                ],
                              )),
                              const Icon(Icons.open_in_new_rounded,
                                  color: Colors.white24, size: 16),
                            ]),
                          ),
                        ),

                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BioConfig.colorPrimario,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            onPressed:
                                _descargando ? null : _descargarEInstalarAPK,
                            icon: _descargando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.black, strokeWidth: 2.5))
                                : const Icon(Icons.download_for_offline,
                                    size: 22),
                            // ⚠️  Mostrar _versionRemotaLabel (versión en GitHub),
                            //     NO BioConfig.versionDisplay (versión instalada).
                            label: Text(
                              _descargando
                                  ? 'Descargando… ${(_progresoDescarga * 100).toStringAsFixed(0)}%'
                                  : 'Descargar Última Versión ($_versionRemotaLabel)',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        // Barra de progreso durante descarga
                        if (_descargando) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _progresoDescarga > 0
                                  ? _progresoDescarga
                                  : null,
                              minHeight: 6,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  BioConfig.colorPrimario),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          'Se descarga e instala directamente en tu dispositivo',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ]),
                ),
                const SizedBox(height: 24),

                // ── Ver como (solo Admin y Tester) ───────────────────────────────
                Builder(builder: (ctx) {
                  final rolReal = widget.uData['rol'] ?? BioConfig.rolUser;
                  final rolesDisp = ViewAsManager.rolesDisponibles(rolReal);
                  if (rolesDisp.isEmpty) return const SizedBox.shrink();

                  return ListenableBuilder(
                    listenable: ViewAsManager(),
                    builder: (_, __) {
                      final vm = ViewAsManager();
                      final activo = vm.estaActivo;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: activo
                              ? Colors.orange.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: activo
                                  ? Colors.orange.withValues(alpha: 0.5)
                                  : Colors.white12),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.visibility_outlined,
                                    color:
                                        activo ? Colors.orange : Colors.white54,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text("Ver como",
                                    style: TextStyle(
                                        color: activo
                                            ? Colors.orange
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const Spacer(),
                                // Badge rol real
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                      "Tu rol: ${rolReal.toUpperCase()}",
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ]),
                              const SizedBox(height: 4),
                              const Text(
                                "Simula la vista de otro rol sin cambiar tu cuenta en Firebase.\n"
                                "Las escrituras siempre usan tu cuenta real.",
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    height: 1.4),
                              ),
                              const SizedBox(height: 14),

                              // Chips de rol disponibles
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                // Chip "Mi rol real" (siempre disponible — desactiva ViewAs)
                                _chipVerComo(
                                  label: "👤 Mi rol (${rolReal.toUpperCase()})",
                                  seleccionado: !activo,
                                  color: Colors.white54,
                                  onTap: vm.desactivar,
                                ),
                                // Chips de roles disponibles según jerarquía
                                ...rolesDisp.map((rol) {
                                  final Color c = rol == BioConfig.rolPS
                                      ? Colors.tealAccent
                                      : rol == BioConfig.rolTester
                                          ? Colors.amber
                                          : BioConfig.colorPrimario;
                                  final String emoji = rol == BioConfig.rolPS
                                      ? '🩺'
                                      : rol == BioConfig.rolTester
                                          ? '⚡'
                                          : '🧑‍⚕️';
                                  return _chipVerComo(
                                    label: "$emoji ${rol.toUpperCase()}",
                                    seleccionado:
                                        activo && vm.rolSimulado == rol,
                                    color: c,
                                    onTap: () => vm.activar(rol),
                                  );
                                }),
                              ]),

                              // Estado activo
                              if (activo) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.orange
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.info_outline,
                                        color: Colors.orange, size: 14),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                      "Viendo la app como ${vm.rolSimulado!.toUpperCase()}. "
                                      "El banner naranja en el AppBar te lo recuerda. "
                                      "Toca '✕ Salir' en el banner para volver a tu rol real.",
                                      style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 11,
                                          height: 1.4),
                                    )),
                                  ]),
                                ),
                              ],
                            ]),
                      );
                    },
                  );
                }),
                const SizedBox(height: 24),
                if ((widget.uData['rol'] ?? BioConfig.rolUser) !=
                    BioConfig.rolUser) ...[
                  const Text("DATOS DE COBRO",
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _llaveCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 40,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      LengthLimitingTextInputFormatter(40),
                    ],
                    decoration:
                        _deco("Llave BreB para retiros", Icons.key_outlined)
                            .copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Datos personales ─────────────────────────────────────────────
                Row(children: [
                  const Text("DATOS PERSONALES",
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(
                      _esVoluntario
                          ? "(obligatorio para voluntarios)"
                          : "(opcional)",
                      style:
                          const TextStyle(color: Colors.white24, fontSize: 10)),
                ]),
                const SizedBox(height: 10),

                // Edad
                TextField(
                  controller: _edadCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: _deco("Edad", Icons.cake_outlined)
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 16),

                // Sexo
                const Text("Sexo",
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  for (final op in ['Masculino', 'Femenino', 'Otro'])
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(op,
                            style: TextStyle(
                                color:
                                    _sexo == op ? Colors.black : Colors.white70,
                                fontSize: 12)),
                        selected: _sexo == op,
                        selectedColor: BioConfig.colorPrimario,
                        backgroundColor: Colors.white10,
                        onSelected: (_) => setState(() => _sexo = op),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),

                // Tipo de ID
                const Text("Tipo de identificación",
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final op in ['CC', 'CE', 'Pasaporte', 'NIT', 'Otro'])
                    ChoiceChip(
                      label: Text(op,
                          style: TextStyle(
                              color:
                                  _tipoId == op ? Colors.black : Colors.white70,
                              fontSize: 12)),
                      selected: _tipoId == op,
                      selectedColor: BioConfig.colorPrimario,
                      backgroundColor: Colors.white10,
                      onSelected: (_) => setState(() => _tipoId = op),
                    ),
                ]),
                const SizedBox(height: 16),

                // Número de ID
                TextField(
                  controller: _numIdCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  maxLength: 20,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(20),
                  ],
                  decoration:
                      _deco("Número de identificación", Icons.badge_outlined)
                          .copyWith(counterText: ''),
                ),
                const SizedBox(height: 32),

                // ── SECCIÓN: Modo de Reproducción ─────────────────────────────────
                _SeccionModoReproduccion(),
                const SizedBox(height: 24),

                // ── SECCIÓN: Personalización ──────────────────────────────────────
                _SeccionPersonalizacion(),
                const SizedBox(height: 32),

                // ── Guardar ──────────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: BioConfig.colorPrimario,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.save_outlined),
                    label: Text(_guardando ? "Guardando..." : "Guardar cambios",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

                // ── SECCIÓN: Solicitar ser Profesional de la Salud ────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 30),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.tealAccent.withValues(alpha: 0.4)),
                  ),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(BioConfig.colUsuarios)
                        .doc(widget.uid)
                        .snapshots(),
                    builder: (_, uSnap) {
                      final d = uSnap.hasData && uSnap.data!.exists
                          ? uSnap.data!.data() as Map<String, dynamic>
                          : <String, dynamic>{};
                      final rol = d['rol'] ?? BioConfig.rolUser;
                      final estadoPS = d['estado_ps'] ?? '';
                      final esPS = rol == BioConfig.rolPS;
                      final pendiente = estadoPS == 'pendiente';

                      if (esPS) {
                        return const SizedBox
                            .shrink(); // Referidos: próximamente
                      }
                      if (pendiente) {
                        return const Row(children: [
                          Icon(Icons.hourglass_top,
                              color: Colors.orange, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  'Solicitud PS en revisión ⏳\nEl administrador la revisará pronto.',
                                  style: TextStyle(
                                      color: Colors.orange, fontSize: 13))),
                        ]);
                      }
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Switch(
                                value: _mostrarFormPS,
                                onChanged: (v) =>
                                    setState(() => _mostrarFormPS = v),
                                activeColor: Colors.tealAccent,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                  child: Text('Soy Profesional de la Salud',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14))),
                            ]),
                            if (_mostrarFormPS) ...[
                              const SizedBox(height: 14),
                              const Text(
                                  'Para verificar tu identidad, completa los siguientes datos:',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _psNombreCtrl,
                                maxLength: 80,
                                style: const TextStyle(color: Colors.white),
                                decoration: _deco(
                                    'Nombre completo', Icons.person_outline),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _psCedulaCtrl,
                                maxLength: 20,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration:
                                    _deco('Cédula / DNI', Icons.badge_outlined),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _psRegistroCtrl,
                                maxLength: 40,
                                style: const TextStyle(color: Colors.white),
                                decoration: _deco(
                                    'Número de registro profesional',
                                    Icons.medical_information_outlined),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.tealAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  icon: _solicitandoPS
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black))
                                      : const Icon(Icons.send, size: 18),
                                  label: Text(
                                      _solicitandoPS
                                          ? 'Enviando...'
                                          : 'Enviar solicitud PS',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  onPressed: _solicitandoPS
                                      ? null
                                      : _enviarSolicitudPS,
                                ),
                              ),
                            ],
                          ]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Future<void> _enviarSolicitudPS() async {
    final nombre = _psNombreCtrl.text.trim();
    final cedula = _psCedulaCtrl.text.trim();
    final registro = _psRegistroCtrl.text.trim();
    if (nombre.isEmpty || cedula.isEmpty || registro.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Completa todos los campos.')));
      return;
    }
    setState(() => _solicitandoPS = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      // Crear solicitud
      final solRef = FirebaseFirestore.instance
          .collection(BioConfig.colSolicitudesPS)
          .doc();
      batch.set(solRef, {
        'usuario_id': widget.uid,
        'nombre_completo': nombre,
        'cedula': cedula,
        'registro_profesional': registro,
        'estado': 'pendiente',
        'fecha': FieldValue.serverTimestamp(),
      });
      // Marcar usuario como pendiente
      batch.update(
          FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .doc(widget.uid),
          {
            'estado_ps': 'pendiente',
          });
      await batch.commit();
      if (mounted)
        setState(() {
          _mostrarFormPS = false;
          _solicitandoPS = false;
        });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                '✅ Solicitud enviada. El administrador la revisará pronto.'),
            backgroundColor: Colors.teal));
      }
    } catch (e) {
      setState(() => _solicitandoPS = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
} // fin _PantallaMiCuentaState

// ─────────────────────────────────────────────────────────────────────────────
// _SeccionModoReproduccion — Selector de modo en Mi Cuenta
// ─────────────────────────────────────────────────────────────────────────────
class _SeccionModoReproduccion extends StatefulWidget {
  @override
  State<_SeccionModoReproduccion> createState() =>
      _SeccionModoReproduccionState();
}

class _SeccionModoReproduccionState extends State<_SeccionModoReproduccion> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ReproduccionConfig(),
      builder: (_, __) {
        final cfg = ReproduccionConfig();
        final modo = cfg.modo;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.vibration, color: BioConfig.colorPrimario, size: 20),
              const SizedBox(width: 8),
              const Text('MODO DE REPRODUCCIÓN',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            const Text('Elige cómo sentir las frecuencias',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 14),
            _opcion(
                cfg,
                modo,
                ModoReproduccion.sonido,
                Icons.volume_up_outlined,
                'Solo Sonido',
                'Reproduce el audio normalmente',
                Colors.cyan),
            const SizedBox(height: 8),
            _opcion(
                cfg,
                modo,
                ModoReproduccion.dual,
                Icons.waves,
                'Resonancia Dual',
                'Sonido + vibración sincronizada',
                Colors.deepPurpleAccent),
            const SizedBox(height: 8),
            _opcion(
                cfg,
                modo,
                ModoReproduccion.vibracion,
                Icons.vibration,
                'Solo Vibración',
                'Silencio total — ideal para no despertar a nadie 🌙',
                Colors.orange),
          ]),
        );
      },
    );
  }

  Widget _opcion(
      ReproduccionConfig cfg,
      ModoReproduccion actual,
      ModoReproduccion valor,
      IconData icono,
      String titulo,
      String subtitulo,
      Color color) {
    final sel = actual == valor;
    return GestureDetector(
      onTap: () => cfg.setModo(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: sel
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? color : Colors.white12, width: sel ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icono, color: sel ? color : Colors.white38, size: 22),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(titulo,
                    style: TextStyle(
                        color: sel ? color : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ])),
          if (sel) Icon(Icons.check_circle, color: color, size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SeccionPersonalizacion — Paleta + color picker + imagen de fondo
// ─────────────────────────────────────────────────────────────────────────────
class _SeccionPersonalizacion extends StatefulWidget {
  @override
  State<_SeccionPersonalizacion> createState() =>
      _SeccionPersonalizacionState();
}

class _SeccionPersonalizacionState extends State<_SeccionPersonalizacion> {
  final _urlCtrl = TextEditingController();

  // Paleta de colores predefinidos
  static const List<Color> _paleta = [
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.white,
    Color(0xFFE0E0E0),
    Color(0xFF9E9E9E),
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = AppTheme().imagenFondo;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Abre el diálogo con paleta + rueda libre ──────────────────────────────
  Future<void> _elegirColor(String tipo) async {
    Color inicial;
    switch (tipo) {
      case 'primario':
        inicial = AppTheme().colorPrimario;
        break;
      case 'fondo':
        inicial = AppTheme().colorFondo;
        break;
      case 'texto':
        inicial = AppTheme().colorTexto;
        break;
      case 'navbar':
        inicial = AppTheme().colorNavBar;
        break;
      case 'qr_frente':
        inicial = AppTheme().qrForeground;
        break;
      case 'qr_fondo':
        inicial = AppTheme().qrBackground;
        break;
      default:
        inicial = Colors.cyan;
    }

    Color seleccionado = inicial;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            tipo == 'primario'
                ? '🎨 Color Primario'
                : tipo == 'fondo'
                    ? '🖤 Color de Fondo'
                    : tipo == 'texto'
                        ? '✍️ Color de Texto'
                        : tipo == 'navbar'
                            ? '📱 Barra de Navegación'
                            : tipo == 'qr_frente'
                                ? '⬛ Color del QR (módulos)'
                                : '⬜ Color de fondo del QR',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Paleta predefinida
              const Text('Paleta rápida',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paleta
                    .map((c) => GestureDetector(
                          onTap: () => setS(() => seleccionado = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: seleccionado == c
                                    ? Colors.white
                                    : Colors.white24,
                                width: seleccionado == c ? 2.5 : 1,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              // Rueda de color libre
              const Text('Color personalizado',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 10),
              ColorPicker(
                pickerColor: seleccionado,
                onColorChanged: (c) => setS(() => seleccionado = c),
                enableAlpha: false,
                labelTypes: const [],
                pickerAreaHeightPercent: 0.6,
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme().colorPrimario,
                  foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                switch (tipo) {
                  case 'primario':
                    await AppTheme().setColorPrimario(seleccionado);
                    break;
                  case 'fondo':
                    await AppTheme().setColorFondo(seleccionado);
                    break;
                  case 'texto':
                    await AppTheme().setColorTexto(seleccionado);
                    break;
                  case 'navbar':
                    await AppTheme().setColorNavBar(seleccionado);
                    break;
                  case 'qr_frente':
                    await AppTheme().setQrForeground(seleccionado);
                    break;
                  case 'qr_fondo':
                    await AppTheme().setQrBackground(seleccionado);
                    break;
                }
                if (mounted) {
                  setState(() {});
                }
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Abre la galería para elegir imagen ────────────────────────────────────
  Future<void> _elegirImagenGaleria() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await AppTheme().setImagenFondo(picked.path);
      _urlCtrl.text = picked.path;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme();

    return ListenableBuilder(
      listenable: theme,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Título sección ──────────────────────────────────────────────
          Row(children: [
            Icon(Icons.palette_outlined, color: theme.colorPrimario, size: 20),
            const SizedBox(width: 8),
            const Text('PERSONALIZACIÓN',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),

          // ── Colores ─────────────────────────────────────────────────────
          _filaCor('Color primario', 'primario', theme.colorPrimario),
          const SizedBox(height: 10),
          _filaCor('Color de fondo', 'fondo', theme.colorFondo),
          const SizedBox(height: 10),
          _filaCor('Color de texto', 'texto', theme.colorTexto),
          const SizedBox(height: 10),
          _filaCor('Barra de navegación', 'navbar', theme.colorNavBar),
          const SizedBox(height: 10),
          _filaCor('QR — módulos', 'qr_frente', theme.qrForeground),
          const SizedBox(height: 10),
          _filaCor('QR — fondo', 'qr_fondo', theme.qrBackground),
          const SizedBox(height: 20),

          // ── Imagen de fondo ─────────────────────────────────────────────
          const Text('Imagen de fondo',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          // Preview si hay imagen
          if (theme.imagenFondo.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: theme.imagenFondo.startsWith('http')
                  ? Image.network(theme.imagenFondo,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white38,
                          size: 40))
                  : Image.file(File(theme.imagenFondo),
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white38,
                          size: 40)),
            ),
            const SizedBox(height: 10),
          ],

          // Campo URL
          Row(children: [
            Expanded(
              child: TextField(
                controller: _urlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://... o pega un link de imagen/gif',
                  hintStyle:
                      const TextStyle(color: Colors.white24, fontSize: 12),
                  prefixIcon:
                      const Icon(Icons.link, color: Colors.white38, size: 18),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.colorPrimario)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (v) async {
                  await AppTheme().setImagenFondo(v.trim());
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Botón galería
            Tooltip(
              message: 'Elegir de galería',
              child: InkWell(
                onTap: _elegirImagenGaleria,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: theme.colorPrimario.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: theme.colorPrimario.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.photo_library_outlined,
                      color: theme.colorPrimario, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Botón aplicar URL
            Tooltip(
              message: 'Aplicar URL',
              child: InkWell(
                onTap: () async {
                  await AppTheme().setImagenFondo(_urlCtrl.text.trim());
                  if (mounted) {
                    setState(() {});
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: theme.colorPrimario.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: theme.colorPrimario.withValues(alpha: 0.5)),
                  ),
                  child:
                      Icon(Icons.check, color: theme.colorPrimario, size: 20),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('Foto, GIF, o URL de internet',
              style: TextStyle(color: Colors.white24, fontSize: 11)),

          const SizedBox(height: 20),

          // ── Resetear ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white38,
                side: const BorderSide(color: Colors.white12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restaurar valores por defecto',
                  style: TextStyle(fontSize: 13)),
              onPressed: () async {
                await AppTheme().resetearTodo();
                _urlCtrl.text = '';
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _filaCor(String label, String tipo, Color colorActual) {
    return Row(children: [
      Expanded(
        child: Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ),
      GestureDetector(
        onTap: () => _elegirColor(tipo),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colorActual,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.edit, color: Colors.white38, size: 14),
        ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ALEMBIQUE DIO — Cliente HTTP singleton con SSL Pinning + Keep-Alive
//
// Optimizaciones de red (v2.10.3):
//
//  1. WARM-UP: AlembiqueDio.warmUp() se llama en main() antes de runApp().
//     El SecurityContext y el cert.pem se cargan una sola vez al arrancar.
//     Cuando el usuario llega al botón, el handshake TLS ya está listo.
//
//  2. KEEP-ALIVE: _httpClient es un singleton que nunca se cierra entre
//     peticiones. idleTimeout largo (10 min) + autoUncompress = false para
//     no desperdiciar ciclos. El túnel TLS se reutiliza en cada mezcla.
//
//  3. SIN DNS: el servidor corre en IP local (192.168.x.x / 127.0.0.1).
//     Al pasar la IP directamente no hay consulta DNS externa.
//     badCertificateCallback = true acepta el cert autofirmado sin que
//     SecurityContext falle con CERTIFICATE_VERIFY_FAILED en Android.
//
//  Cuando el Alembique tenga dominio + Let's Encrypt, reemplazar el
//  badCertificateCallback por un SecurityContext con el cert de la CA.
// ═══════════════════════════════════════════════════════════════════════════
