part of '../main.dart';

// Rescatado desde main.dart monolitico de VS Code History (snapshot 5VOf.dart).
// Este modulo no aparecio como archivo independiente en el historial, pero
// su contenido si estaba presente dentro de una version anterior de lib/main.dart.

class PantallaInvestigacion extends StatefulWidget {
  final String sonidoId;
  final Map<String, dynamic> sonidoData;
  final int saldoActual;
  final String nivelUsuario;

  const PantallaInvestigacion({
    super.key,
    required this.sonidoId,
    required this.sonidoData,
    required this.saldoActual,
    required this.nivelUsuario,
  });

  @override
  State<PantallaInvestigacion> createState() => _PantallaInvestigacionState();
}

class _PantallaInvestigacionState extends State<PantallaInvestigacion> {
  int _saldoActual = 0;
  bool _yaEnsayista = false;
  String _contadorTexto = "";
  Timer? _contadorTimer;

  @override
  void initState() {
    super.initState();
    _saldoActual = widget.saldoActual;
    _verificarEnsayista();
    _iniciarContador();
  }

  void _iniciarContador() {
    final Timestamp? fechaLimite = widget.sonidoData['fecha_limite_donacion'];
    if (fechaLimite == null) return;
    _actualizarContador(fechaLimite.toDate());
    _contadorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _actualizarContador(fechaLimite.toDate());
    });
  }

  void _actualizarContador(DateTime limite) {
    final restante = limite.difference(DateTime.now());
    if (restante.isNegative) {
      setState(() => _contadorTexto = "⏰ Tiempo agotado");
      return;
    }
    final d = restante.inDays;
    final h = restante.inHours % 24;
    final m = restante.inMinutes % 60;
    final s = restante.inSeconds % 60;
    setState(() => _contadorTexto = "${d.toString().padLeft(2, '0')}:"
        "${h.toString().padLeft(2, '0')}:"
        "${m.toString().padLeft(2, '0')}:"
        "${s.toString().padLeft(2, '0')}");
  }

  Future<void> _verificarEnsayista() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var doc = await FirebaseFirestore.instance
        .collection(BioConfig.colEnsayos)
        .doc('${widget.sonidoId}_${user.uid}')
        .get();
    if (mounted) setState(() => _yaEnsayista = doc.exists);
  }

  Future<void> _registrarEnsayista() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection(BioConfig.colEnsayos)
        .doc('${widget.sonidoId}_${user.uid}')
        .set({
      'usuario_id': user.uid,
      'sonido_id': widget.sonidoId,
      'fecha': FieldValue.serverTimestamp(),
      'estado': 'pendiente',
    });
    setState(() => _yaEnsayista = true);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "✅ ¡Te has registrado como sujeto de ensayo! Te contactaremos pronto.")));
  }

  Future<void> _mostrarModalDonacion() async {
    final TextEditingController ctrl = TextEditingController();
    String metodo = 'tokens'; // 'tokens' o 'mercadopago'
    double valorToken = 100.0;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .get();
        final userData =
            Map<String, dynamic>.from((userDoc.data() as Map?) ?? {});
        valorToken = await MacroSegmentoConfig.resolveValorTokenCopForUserData(
          userData,
          fallback: 100,
        );
      }
    } catch (_) {}

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          int tokens = int.tryParse(ctrl.text) ?? 0;
          double cop = tokens * valorToken;
          bool alcanza = metodo == 'tokens' ? _saldoActual >= tokens : true;

          return Padding(
            padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("💡 Donar a esta investigación",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                    "Tu donación financia el desarrollo de: "
                    "${widget.sonidoData['Nombre'] ?? 'este sonido'}",
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 20),

                // Selector método
                Row(children: [
                  Expanded(
                      child: GestureDetector(
                    onTap: () => setModal(() => metodo = 'tokens'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: metodo == 'tokens'
                            ? BioConfig.colorPrimario.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: metodo == 'tokens'
                                ? BioConfig.colorPrimario
                                : Colors.white12),
                      ),
                      child: const Column(children: [
                        Icon(Icons.toll, color: Colors.amber),
                        SizedBox(height: 4),
                        Text("Mis Tokens",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: GestureDetector(
                    onTap: () => setModal(() => metodo = 'mercadopago'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: metodo == 'mercadopago'
                            ? Colors.blue.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: metodo == 'mercadopago'
                                ? Colors.blue
                                : Colors.white12),
                      ),
                      child: const Column(children: [
                        Icon(Icons.credit_card, color: Colors.blue),
                        SizedBox(height: 4),
                        Text("MercadoPago",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 16),

                // Campo cantidad
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    counterText: '',
                    hintText:
                        metodo == 'tokens' ? "Tokens a donar" : "Pesos COP",
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 16),
                  ),
                  onChanged: (_) => setModal(() {}),
                ),
                const SizedBox(height: 10),

                // Resumen
                if (tokens > 0)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: alcanza
                              ? Colors.white12
                              : Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: Column(children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Donación:",
                                style: TextStyle(color: Colors.white54)),
                            Text(
                                metodo == 'tokens'
                                    ? "$tokens tokens (≈ \$${cop.toStringAsFixed(0)} COP)"
                                    : "\$$tokens COP (≈ ${(tokens / valorToken).toStringAsFixed(0)} tokens)",
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold)),
                          ]),
                      if (metodo == 'tokens') ...[
                        const SizedBox(height: 4),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Tu saldo:",
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              Text("$_saldoActual tokens",
                                  style: TextStyle(
                                      color: alcanza
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      fontSize: 12)),
                            ]),
                      ],
                      if (!alcanza && metodo == 'tokens')
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text("⚠️ Saldo insuficiente",
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 12)),
                        ),
                    ]),
                  ),
                const SizedBox(height: 16),

                // Botón confirmar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (tokens > 0 && alcanza)
                          ? (metodo == 'tokens'
                              ? BioConfig.colorPrimario
                              : Colors.blue)
                          : Colors.grey[800],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.favorite, size: 20),
                    label: Text(
                      metodo == 'tokens'
                          ? "Donar $tokens tokens"
                          : "Donar con MercadoPago",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: (tokens > 0 && alcanza)
                        ? () async {
                            Navigator.pop(ctx);
                            await _procesarDonacion(tokens, metodo, cop);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _procesarDonacion(int tokens, String metodo, double cop) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Validar límites
    if (tokens <= 0 || tokens > 10000000) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Cantidad de tokens inválida.")));
      return;
    }

    try {
      if (metodo == 'tokens') {
        // Re-verificar saldo actual desde servidor antes de descontar
        final userDoc = await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .get();
        final saldoServidor =
            BioConfig.toInt(userDoc.data()?[BioConfig.campoTokens]);
        if (saldoServidor < tokens) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    "❌ Saldo insuficiente. Actualiza y vuelve a intentar.")));
          return;
        }
        await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .update({BioConfig.campoTokens: FieldValue.increment(-tokens)});
        setState(() => _saldoActual = saldoServidor - tokens);
      }
      // Registrar donación
      await FirebaseFirestore.instance.collection(BioConfig.colDonaciones).add({
        'usuario_id': user.uid,
        'sonido_id': widget.sonidoId,
        'tokens': tokens,
        'monto_cop': cop,
        'metodo': metodo,
        'fecha': FieldValue.serverTimestamp(),
      });
      // Actualizar contador en el sonido
      await FirebaseFirestore.instance
          .collection(BioConfig.colSonidos)
          .doc(widget.sonidoId)
          .update({'donaciones_recibidas': FieldValue.increment(tokens)});

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("❤️ ¡Gracias! Donaste $tokens tokens a esta investigación."),
          backgroundColor: Colors.green[800],
        ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void dispose() {
    _contadorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.sonidoData['Nombre'] ?? 'Investigación';
    final descripcion = widget.sonidoData['descripcion'] ?? '';
    final estado = widget.sonidoData['estado'] ?? BioConfig.estadoInvestigacion;
    final bool enInvestigacion = estado == BioConfig.estadoInvestigacion;
    final int meta = BioConfig.toInt(widget.sonidoData['meta_donacion']);
    final bool ensayosAbiertos = widget.sonidoData['ensayos_abiertos'] == true;

    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      appBar: AppBar(
        backgroundColor: BioConfig.colorFondo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(nombre,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(BioConfig.colSonidos)
            .doc(widget.sonidoId)
            .snapshots(),
        builder: (context, snap) {
          int donacionActual = snap.hasData && snap.data!.exists
              ? BioConfig.toInt(snap.data!['donaciones_recibidas'])
              : 0;
          double progreso =
              meta > 0 ? (donacionActual / meta).clamp(0.0, 1.0) : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge de estado
                Center(
                    child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (enInvestigacion ? Colors.orange : Colors.blue)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: enInvestigacion ? Colors.orange : Colors.blue),
                  ),
                  child: Text(
                    enInvestigacion
                        ? "🔬 Recibiendo donaciones"
                        : "⚗️ En proceso",
                    style: TextStyle(
                        color: enInvestigacion ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.bold),
                  ),
                )),
                const SizedBox(height: 20),

                // Descripción
                if (descripcion.isNotEmpty) ...[
                  Text(descripcion,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14, height: 1.5)),
                  const SizedBox(height: 20),
                ],

                // Progreso de donaciones
                if (meta > 0 && enInvestigacion) ...[
                  const Text("FINANCIACIÓN",
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 14,
                      backgroundColor: Colors.white10,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("$donacionActual tokens recibidos",
                            style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        Text("Meta: $meta tokens",
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ]),
                  const SizedBox(height: 4),
                  Center(
                      child: Text(
                          "${(progreso * 100).toStringAsFixed(1)}% financiado",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12))),
                  const SizedBox(height: 16),
                ],

                // Contador tiempo restante
                if (_contadorTexto.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(children: [
                      const Text("⏱ Tiempo para donar",
                          style:
                              TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 6),
                      Text(_contadorTexto,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const Text("DD : HH : MM : SS",
                          style:
                              TextStyle(color: Colors.white24, fontSize: 10)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // Botón donar
                if (enInvestigacion) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.favorite, size: 22),
                      label: const Text("Donar a esta investigación",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: _mostrarModalDonacion,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Botón sujeto de ensayo
                if (ensayosAbiertos) ...[
                  GestureDetector(
                    onTap: _yaEnsayista
                        ? null
                        : () async {
                            bool confirmar = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A1A1A),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: const Text("🧪 Grupo de ensayo",
                                        style: TextStyle(color: Colors.white)),
                                    content: const Text(
                                        "Quiero ser parte del grupo de ensayos para este sonido. "
                                        "Entiendo que seré contactado por el equipo de BioFreq "
                                        "cuando el sonido esté en etapa de pruebas.",
                                        style: TextStyle(
                                            color: Colors.white70,
                                            height: 1.5)),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancelar",
                                            style: TextStyle(
                                                color: Colors.white38)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                BioConfig.colorPrimario,
                                            foregroundColor: Colors.black),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child:
                                            const Text("¡Quiero participar!"),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (confirmar) _registrarEnsayista();
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _yaEnsayista
                            ? Colors.green.withValues(alpha: 0.08)
                            : BioConfig.colorPrimario.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _yaEnsayista
                              ? Colors.green.withValues(alpha: 0.4)
                              : BioConfig.colorPrimario.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          _yaEnsayista ? Icons.check_circle : Icons.science,
                          color: _yaEnsayista
                              ? Colors.greenAccent
                              : BioConfig.colorPrimario,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _yaEnsayista
                                  ? "✅ Ya estás registrado en el grupo de ensayos"
                                  : "🧪 Quiero ser parte del grupo de ensayos",
                              style: TextStyle(
                                  color: _yaEnsayista
                                      ? Colors.greenAccent
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _yaEnsayista
                                  ? "Te contactaremos cuando inicie la fase de pruebas."
                                  : "Sé parte del proceso de investigación de este sonido.",
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        )),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA RETIROS Y TESTIMONIOS
// ═════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════
// PANTALLA MI CUENTA
// ═══════════════════════════════════════════════

class PantallaRetiros extends StatefulWidget {
  const PantallaRetiros({super.key});
  @override
  State<PantallaRetiros> createState() => _PantallaRetirosState();
}

class _PantallaRetirosState extends State<PantallaRetiros>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _llaveCtrl = TextEditingController();
  final _confirmaCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _ytCtrl = TextEditingController();
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _cargarLlavePredeterminada();
  }

  Future<void> _cargarLlavePredeterminada() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .get();
      final llave = doc.data()?['llave_breb'] ?? '';
      if (llave.isNotEmpty && mounted) {
        setState(() => _llaveCtrl.text = llave);
      }
    } catch (e) {
      debugPrint("Error cargando llave: $e");
    }
  }

  @override
  void dispose() {
    // Limpiar datos sensibles de memoria antes de destruir
    _llaveCtrl.clear();
    _confirmaCtrl.clear();
    _montoCtrl.clear();
    _ytCtrl.clear();
    _tab.dispose();
    _llaveCtrl.dispose();
    _confirmaCtrl.dispose();
    _montoCtrl.dispose();
    _ytCtrl.dispose();
    super.dispose();
  }

  // ── Solicitar retiro ──────────────────────────────────────────────────────
  Future<void> _solicitarRetiro() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String llave = _llaveCtrl.text.trim();
    final String confirma = _confirmaCtrl.text.trim();
    final int monto = int.tryParse(_montoCtrl.text.trim()) ?? 0;

    if (llave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Ingresa tu llave BreB.")));
      return;
    }
    if (llave.length > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Llave demasiado larga.")));
      return;
    }
    if (llave != confirma) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("❌ Las llaves no coinciden. Verifica e intenta de nuevo.")));
      return;
    }
    if (monto < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("❌ El monto mínimo de retiro es \$1.000 COP.")));
      return;
    }
    if (monto > 10000000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("❌ Monto máximo por solicitud: \$10.000.000 COP.")));
      return;
    }

    setState(() => _cargando = true);
    try {
      await FirebaseFirestore.instance.collection(BioConfig.colRetiros).add({
        'usuario_id': user.uid,
        'usuario_email': user.email ?? '',
        'monto_cop': monto,
        'llave_breb': llave,
        'estado': 'pendiente',
        'fecha_solicitud': FieldValue.serverTimestamp(),
        'fecha_pago': null,
      });
      _llaveCtrl.clear();
      _confirmaCtrl.clear();
      _montoCtrl.clear();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "✅ Solicitud enviada. Recibirás tu pago en máximo 24 horas."),
          backgroundColor: Colors.green,
        ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _cargando = false);
  }

  // ── Enviar testimonio ─────────────────────────────────────────────────────
  Future<void> _enviarTestimonio(String sonidoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final url = _ytCtrl.text.trim();
    // Validación estricta de URL YouTube
    final urlLower = url.toLowerCase();
    final bool esYoutube = (urlLower.startsWith('https://www.youtube.com/') ||
        urlLower.startsWith('https://youtube.com/') ||
        urlLower.startsWith('https://youtu.be/'));
    if (!esYoutube || url.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("❌ Ingresa un link válido de YouTube (https://...).")));
      return;
    }
    setState(() => _cargando = true);
    try {
      await FirebaseFirestore.instance
          .collection(BioConfig.colTestimonios)
          .add({
        'usuario_id': user.uid,
        'sonido_id': sonidoId,
        'url_youtube': url,
        'estado': 'pendiente',
        'fecha_envio': FieldValue.serverTimestamp(),
        'tokens_acreditados': 0,
      });
      _ytCtrl.clear();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Testimonio enviado. Lo revisaremos pronto."),
          backgroundColor: Colors.green,
        ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      appBar: AppBar(
        backgroundColor: BioConfig.colorFondo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Mis Ganancias",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: BioConfig.colorPrimario,
          labelColor: BioConfig.colorPrimario,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet), text: "Retiros"),
            Tab(icon: Icon(Icons.video_camera_front), text: "Testimonios"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── TAB 1: RETIROS ────────────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BioConfig.colorPrimario.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: BioConfig.colorPrimario.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    "💡 Puedes retirar desde \$1.000 COP. Los pagos se hacen "
                    "por llave BreB en máximo 24 horas.",
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),

                // Monto a retirar
                const Text("MONTO A RETIRAR (COP)",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: _montoCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  maxLength: 12,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: _inputDeco("Ej: 50000", Icons.attach_money)
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 20),

                // Llave BreB
                const Text("LLAVE BREB",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: _llaveCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 40,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(40),
                  ],
                  decoration: _inputDeco("Tu llave BreB", Icons.key)
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 12),

                // Confirmar llave
                const Text("CONFIRMAR LLAVE",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmaCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 40,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(40),
                  ],
                  decoration:
                      _inputDeco("Confirma tu llave BreB", Icons.key_outlined)
                          .copyWith(counterText: ''),
                ),
                const SizedBox(height: 24),

                // Botón retirar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BioConfig.colorPrimario,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _cargando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.send, size: 22),
                    label: Text(_cargando ? "Enviando..." : "Solicitar retiro",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: _cargando ? null : _solicitarRetiro,
                  ),
                ),
                const SizedBox(height: 32),

                // Historial de retiros
                const Text("HISTORIAL DE RETIROS",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(BioConfig.colRetiros)
                      .where('usuario_id', isEqualTo: user?.uid)
                      .orderBy('fecha_solicitud', descending: true)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData)
                      return Center(
                          child: CircularProgressIndicator(
                              color: BioConfig.colorPrimario));
                    if (snap.data!.docs.isEmpty)
                      return const Text(
                          "Aún no has hecho solicitudes de retiro.",
                          style: TextStyle(color: Colors.white38));
                    return Column(
                      children: snap.data!.docs.map((doc) {
                        var d = doc.data() as Map<String, dynamic>;
                        bool pagado = d['estado'] == 'pagado';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: pagado
                                    ? Colors.green.withValues(alpha: 0.4)
                                    : Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("\$${d['monto_cop']} COP",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Text(d['llave_breb'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11)),
                                  ]),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (pagado ? Colors.green : Colors.orange)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  pagado ? "✅ Pagado" : "⏳ Pendiente",
                                  style: TextStyle(
                                      color: pagado
                                          ? Colors.greenAccent
                                          : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── TAB 2: TESTIMONIOS ────────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    "🎥 Sube tu video a YouTube con el hashtag "
                    "#BioFreqTestimonio, pega el link aquí y lo revisaremos. "
                    "Si es aprobado, recibirás tokens según la fórmula de reconocimiento.",
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),

                // Selector de sonido
                const Text("SONIDO DEL TESTIMONIO",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(BioConfig.colSonidos)
                      .where('estado', isEqualTo: BioConfig.estadoDisponible)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) return const CircularProgressIndicator();
                    String? _sonidoSeleccionado;
                    return StatefulBuilder(
                      builder: (ctx, setSt) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _sonidoSeleccionado,
                            dropdownColor: const Color(0xFF1A1A1A),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDeco(
                                "Selecciona el sonido", Icons.music_note),
                            items: snap.data!.docs.map((doc) {
                              var d = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(d['Nombre'] ?? doc.id,
                                    style:
                                        const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setSt(() => _sonidoSeleccionado = v),
                          ),
                          const SizedBox(height: 16),

                          // Link YouTube
                          const Text("LINK DE YOUTUBE",
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _ytCtrl,
                            style: const TextStyle(color: Colors.white),
                            maxLength: 200,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              LengthLimitingTextInputFormatter(200),
                            ],
                            decoration: _inputDeco(
                                    "https://youtube.com/...", Icons.link)
                                .copyWith(counterText: ''),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.send),
                              label: const Text("Enviar testimonio",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: (_sonidoSeleccionado != null &&
                                      !_cargando)
                                  ? () =>
                                      _enviarTestimonio(_sonidoSeleccionado!)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Historial testimonios
                const Text("MIS TESTIMONIOS",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(BioConfig.colTestimonios)
                      .where('usuario_id', isEqualTo: user?.uid)
                      .orderBy('fecha_envio', descending: true)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData)
                      return CircularProgressIndicator(
                          color: BioConfig.colorPrimario);
                    if (snap.data!.docs.isEmpty)
                      return const Text("Aún no has enviado testimonios.",
                          style: TextStyle(color: Colors.white38));
                    return Column(
                      children: snap.data!.docs.map((doc) {
                        var d = doc.data() as Map<String, dynamic>;
                        String est = d['estado'] ?? 'pendiente';
                        Color estColor = est == 'aprobado'
                            ? Colors.greenAccent
                            : est == 'rechazado'
                                ? Colors.redAccent
                                : Colors.orange;
                        String estLabel = est == 'aprobado'
                            ? "✅ Aprobado"
                            : est == 'rechazado'
                                ? "❌ Rechazado"
                                : "⏳ En revisión";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection(BioConfig.colSonidos)
                                        .doc(d['sonido_id'])
                                        .get(),
                                    builder: (_, s) => Text(
                                        s.hasData && s.data!.exists
                                            ? s.data!['Nombre'] ??
                                                d['sonido_id']
                                            : d['sonido_id'],
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  Text(estLabel,
                                      style: TextStyle(
                                          color: estColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(d['url_youtube'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (est == 'aprobado' &&
                                  (d['tokens_acreditados'] ?? 0) > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                    "💰 ${d['tokens_acreditados']} tokens acreditados",
                                    style: const TextStyle(
                                        color: Colors.amber, fontSize: 12)),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BioConfig.colorPrimario)),
      );
}
