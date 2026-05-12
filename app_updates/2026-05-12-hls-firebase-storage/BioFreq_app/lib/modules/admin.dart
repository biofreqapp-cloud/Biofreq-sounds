// ======================================================================
// BioFreq — Módulo: admin
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

class PantallaAdmin extends StatefulWidget {
  const PantallaAdmin({super.key});

  // Static aquí para poder llamar PantallaAdmin.esAdmin()
  static Future<bool> esAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      // Intentar servidor primero, con fallback a caché automático de Firestore
      final doc = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .get();
      return (doc.data()?['rol'] ?? '') == BioConfig.rolAdmin;
    } catch (_) {
      return false;
    }
  }

  @override
  State<PantallaAdmin> createState() => _PantallaAdminState();
}

class _PantallaAdminState extends State<PantallaAdmin>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  late Future<bool> _esAdminFuture;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 12, vsync: this);
    _esAdminFuture = PantallaAdmin.esAdmin();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Decoración de campos ──────────────────────────────────────────────────
  static InputDecoration _deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white38),
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
      );

  // ── Alta de Sonido ────────────────────────────────────────────────────────
  void _dialogNuevoSonido() {
    final nombre = TextEditingController();
    final desc = TextEditingController();
    final urlAudio = TextEditingController();
    final urlImagen = TextEditingController();
    String categoriaVal = 'Oncológico'; // dropdown — no necesita controller
    final tokens = TextEditingController();
    final prioridad = TextEditingController(text: '1');
    bool publicando = false;

    // Lista de categorías (misma que TabSQC — BPM)
    const List<String> categoriasAdmin = [
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.add_circle_outline, color: BioConfig.colorPrimario),
            const SizedBox(width: 10),
            const Text("Nuevo Sonido",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campoTexto(nombre, "Nombre"),
              _campoTexto(desc, "Descripción", maxLines: 3),
              _campoTexto(urlAudio, "URL Audio (Storage)",
                  hint: "gs://... o https://..."),
              _campoTexto(urlImagen, "URL Imagen", hint: "https://..."),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: categoriaVal,
                dropdownColor: const Color(0xFF1A1A1A),
                decoration: InputDecoration(
                  labelText: "Categoría",
                  labelStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: BioConfig.colorPrimario)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: categoriasAdmin
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setSt(() => categoriaVal = v);
                  }
                },
              ),
              const SizedBox(height: 8),
              _campoTexto(tokens, "Tokens objetivo",
                  keyboard: TextInputType.number),
              _campoTexto(prioridad, "Prioridad (1=alta)",
                  keyboard: TextInputType.number),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar",
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BioConfig.colorPrimario,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: publicando
                  ? null
                  : () async {
                      if (nombre.text.trim().isEmpty) return;
                      setSt(() => publicando = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection(BioConfig.colSonidos)
                            .add({
                          'Nombre': nombre.text.trim(),
                          'descripcion': desc.text.trim(),
                          'url_audio': urlAudio.text.trim(),
                          'url_imagen': urlImagen.text.trim(),
                          'categoria': categoriaVal,
                          'tokens_objetivo': int.tryParse(tokens.text) ?? 0,
                          'prioridad': int.tryParse(prioridad.text) ?? 1,
                          'estado': BioConfig.estadoEnProceso,
                          'fase': 'desarrollo',
                          'donaciones_recibidas': 0,
                          'total_usos': 0,
                          'ensayos_abiertos': false,
                          'nivel_requerido': '',
                          'fecha_creacion': FieldValue.serverTimestamp(),
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "✅ Sonido publicado correctamente")));
                        }
                      } catch (e) {
                        setSt(() => publicando = false);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
              child: publicando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text("Publicar",
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Alta de Investigación ─────────────────────────────────────────────────
  void _dialogNuevaInvestigacion() {
    final titulo = TextEditingController();
    final fase = TextEditingController(text: 'Fase I');
    final sujetos = TextEditingController();
    final resultado = TextEditingController();
    final fecha = TextEditingController(
        text: DateTime.now().toIso8601String().substring(0, 10));
    bool publicando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.biotech, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text("Nueva Investigación",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _campoTexto(titulo, "Título"),
              _campoTexto(fase, "Fase", hint: "Fase I / II / III"),
              _campoTexto(sujetos, "N° de sujetos",
                  keyboard: TextInputType.number),
              _campoTexto(resultado, "Resultado / Hallazgo principal",
                  maxLines: 4),
              _campoTexto(fecha, "Fecha (YYYY-MM-DD)"),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar",
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: publicando
                  ? null
                  : () async {
                      if (titulo.text.trim().isEmpty) return;
                      setSt(() => publicando = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection('investigaciones')
                            .add({
                          'titulo': titulo.text.trim(),
                          'fase': fase.text.trim(),
                          'sujetos': int.tryParse(sujetos.text) ?? 0,
                          'resultado': resultado.text.trim(),
                          'fecha': fecha.text.trim(),
                          'publicado_por':
                              FirebaseAuth.instance.currentUser?.uid,
                          'fecha_creacion': FieldValue.serverTimestamp(),
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("✅ Investigación publicada")));
                        }
                      } catch (e) {
                        setSt(() => publicando = false);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
              child: publicando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text("Publicar",
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper campo de texto ─────────────────────────────────────────────────
  static Widget _campoTexto(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _deco(label, hint: hint),
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _esAdminFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
              backgroundColor: BioConfig.colorFondo,
              body: const Center(child: CircularProgressIndicator()));
        }
        if (snap.data == false) {
          return Scaffold(
            backgroundColor: BioConfig.colorFondo,
            body: Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                const Text("Acceso restringido",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Solo administradores",
                    style: TextStyle(color: Colors.white38)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Volver"),
                ),
              ],
            )),
          );
        }

        return Scaffold(
          backgroundColor: BioConfig.colorFondo,
          appBar: AppBar(
            backgroundColor: BioConfig.colorFondo,
            iconTheme: const IconThemeData(color: Colors.white70),
            title: const Row(children: [
              Icon(Icons.admin_panel_settings,
                  color: Colors.purpleAccent, size: 22),
              SizedBox(width: 10),
              Text("Panel Admin",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: StreamBuilder<List<int>>(
                // ⚠️  Stream combinado que cuenta pendientes por tab.
                //     Escucha en tiempo real: el badge se actualiza solo cuando
                //     se resuelve o llega una nueva solicitud. NO modificar.
                // ⚠️  Rx.combineLatest2 no está disponible sin rxdart.
                //     Usamos switchMap sobre el stream de retiros para leer
                //     el último valor de solicPS en tiempo real.
                stream: FirebaseFirestore.instance
                    .collection(BioConfig.colRetiros)
                    .where('estado', isEqualTo: 'pendiente')
                    .snapshots()
                    .asyncMap((retSnap) async {
                  final psSnap = await FirebaseFirestore.instance
                      .collection(BioConfig.colSolicitudesPS)
                      .where('estado', isEqualTo: 'pendiente')
                      .get();
                  final recetasSnap = await FirebaseFirestore.instance
                      .collection(BioConfig.colSolicitudesPrescripcion)
                      .where('estado', isEqualTo: 'pendiente')
                      .get();
                  return [
                    retSnap.docs.length,
                    psSnap.docs.length,
                    recetasSnap.docs.length
                  ];
                }),
                initialData: const [0, 0, 0],
                builder: (_, snap) {
                  final counts = snap.data ?? [0, 0];
                  final nRetiros = counts[0];
                  final nPS = counts[1];
                  final nRecetas = counts.length > 2 ? counts[2] : 0;

                  // ── Widget helper para tab con badge ──────────────────────
                  Widget tabConBadge(IconData icon, String label, int count) {
                    return Tab(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(icon, size: 18),
                            const SizedBox(height: 2),
                            Text(label, style: const TextStyle(fontSize: 10)),
                          ]),
                          if (count > 0)
                            Positioned(
                              right: -10,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return TabBar(
                    controller: _tab,
                    indicatorColor: BioConfig.colorPrimario,
                    labelColor: BioConfig.colorPrimario,
                    unselectedLabelColor: Colors.white38,
                    isScrollable: true,
                    tabs: [
                      const Tab(
                          icon: Icon(Icons.music_note, size: 18),
                          text: 'Sonidos'),
                      const Tab(
                          icon: Icon(Icons.rate_review, size: 18),
                          text: 'Testimonios'),
                      const Tab(
                          icon: Icon(Icons.biotech, size: 18),
                          text: 'Investigaciones'),
                      tabConBadge(Icons.account_balance, 'Tesorería', nRetiros),
                      tabConBadge(Icons.verified_user, 'PS', nPS),
                      tabConBadge(
                          Icons.medical_services_outlined, 'Recetas', nRecetas),
                      const Tab(
                          icon: Icon(Icons.science, size: 18), text: 'SQC'),
                      const Tab(
                          icon: Icon(Icons.card_membership, size: 18),
                          text: 'Planes'),
                      const Tab(
                          icon: Icon(Icons.qr_code_2_outlined, size: 18),
                          text: 'Códigos Macro'),
                      const Tab(
                          icon: Icon(Icons.campaign, size: 18),
                          text: 'Marketing'),
                      const Tab(
                        icon: Icon(Icons.account_tree_outlined, size: 18),
                        text: 'Árbol Genealógico',
                      ),
                      const Tab(
                        icon: Icon(Icons.monitor_heart_outlined, size: 18),
                        text: 'Estado Técnico',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── FAB contextual por tab ───────────────────────────────────────
          floatingActionButton: AnimatedBuilder(
            animation: _tab,
            builder: (_, __) {
              if (_tab.index != 0 && _tab.index != 2) {
                return const SizedBox.shrink();
              }
              return FloatingActionButton.extended(
                backgroundColor: BioConfig.colorPrimario,
                foregroundColor: Colors.black,
                onPressed: _tab.index == 0
                    ? _dialogNuevoSonido
                    : _dialogNuevaInvestigacion,
                icon: const Icon(Icons.add),
                label: Text(
                  _tab.index == 0 ? "Nuevo Sonido" : "Nueva Investigación",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),

          body: TabBarView(
            controller: _tab,
            children: [
              // ── Tab 1: Sonidos — Biblioteca + Gestión completa ─────────
              // ⚠️  Sin orderBy('fecha_creacion') — si el campo no existe en un
              //     doc Firestore lo omite silenciosamente → lista vacía.
              //     Ordenamos en memoria por Nombre.
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(BioConfig.colSonidos)
                    .snapshots(),
                builder: (_, snap) {
                  if (snap.hasError) {
                    return _emptyState(Icons.music_off,
                        'Error cargando sonidos', snap.error.toString());
                  }
                  if (!snap.hasData) {
                    return Center(
                        child: CircularProgressIndicator(
                            color: BioConfig.colorPrimario));
                  }
                  // Ordenar en memoria — evita problemas de índice
                  final docs = snap.data!.docs.toList()
                    ..sort((a, b) {
                      final na = (a.data() as Map)['Nombre'] ?? '';
                      final nb = (b.data() as Map)['Nombre'] ?? '';
                      return na.toString().compareTo(nb.toString());
                    });
                  if (docs.isEmpty) {
                    return _emptyState(Icons.music_off, 'Sin sonidos aún',
                        'Toca + para agregar el primero');
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final ref = docs[i].reference;
                      final nombre = d['Nombre'] ?? '—';
                      final estado = d['estado'] ?? '';
                      final fase = d['fase'] ?? '—';
                      final usos = BioConfig.toInt(d['total_usos']);
                      final donas = BioConfig.toInt(d['donaciones_recibidas']);
                      final tokens = BioConfig.toInt(d['tokens_objetivo']);
                      final costoUso = BioConfig.toInt(d['costo_uso']);
                      final version = d['version_sonido']?.toString() ?? '1';
                      final nivelReq =
                          (d['nivel_requerido'] ?? '').toString().trim();
                      final Color estadoColor =
                          estado == BioConfig.estadoDisponible
                              ? Colors.greenAccent
                              : estado == BioConfig.estadoEnProceso
                                  ? Colors.orange
                                  : Colors.blueAccent;

                      return _adminCard(
                        icon: Icons.graphic_eq,
                        iconColor: BioConfig.colorPrimario,
                        title: nombre,
                        coreStyle: true,
                        onTap: () => _mostrarEditorSonidoAdmin(
                          sonidoId: docs[i].id,
                          ref: ref,
                          data: d,
                        ),
                        subtitle: d['descripcion']?.toString() ?? '',
                        chips: [
                          _chip(
                            BioConfig.etiquetaEstadoSonido(estado),
                            estadoColor.withValues(alpha: 0.15),
                            textColor: estadoColor,
                          ),
                          _chip(
                            costoUso > 0
                                ? '$costoUso tkn/sesión'
                                : 'Taxímetro activo',
                            Colors.tealAccent.withValues(alpha: 0.12),
                            textColor: Colors.tealAccent,
                          ),
                          if (nivelReq.isNotEmpty)
                            _chip(
                              'Nivel $nivelReq',
                              Colors.purple.withValues(alpha: 0.18),
                              textColor: Colors.purpleAccent,
                            ),
                          _chip('$usos usos', Colors.white24),
                          _chip('$donas donaciones', Colors.white24),
                          _chip('Fase: $fase', Colors.white10),
                          _chip('v$version', Colors.white10),
                          _chip('$tokens objetivo', Colors.white10),
                        ],
                        actions: [
                          // ── Menú completo de gestión ──────────────────────
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white54, size: 20),
                            color: const Color(0xFF1E1E2E),
                            onSelected: (val) async {
                              switch (val) {
                                // ── Estado ──────────────────────────────────
                                case 'estado_proceso':
                                  await ref.update(
                                      {'estado': BioConfig.estadoEnProceso});
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                '⚗️ Estado → En proceso')));
                                  }
                                  break;
                                case 'estado_disponible':
                                  await ref.update(
                                      {'estado': BioConfig.estadoDisponible});
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('✅ Estado → Disponible')));
                                  }
                                  break;
                                case 'estado_investigacion':
                                  await ref.update({
                                    'estado': BioConfig.estadoInvestigacion
                                  });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                '🔬 Estado → Investigación')));
                                  }
                                  break;
                                // ── Fase ─────────────────────────────────────
                                case 'fase':
                                  _dialogEditarCampoTexto(
                                    titulo: 'Cambiar fase',
                                    campo: 'fase',
                                    valorActual: fase,
                                    ref: ref,
                                    hint: 'desarrollo / pruebas / produccion',
                                  );
                                  break;
                                // ── Tokens objetivo ──────────────────────────
                                case 'tokens':
                                  _dialogEditarCampoNumero(
                                    titulo: 'Tokens objetivo',
                                    campo: 'tokens_objetivo',
                                    valorActual: tokens,
                                    ref: ref,
                                  );
                                  break;
                                // ── Versión ──────────────────────────────────
                                case 'version':
                                  _dialogEditarCampoTexto(
                                    titulo: 'Versión del sonido',
                                    campo: 'version_sonido',
                                    valorActual: version,
                                    ref: ref,
                                    hint: '1, 2, 1.1…',
                                  );
                                  break;
                                // ── Eliminar ─────────────────────────────────
                                case 'eliminar':
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E1E2E),
                                      title: const Text('¿Eliminar sonido?',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      content: Text(
                                          'Se eliminará "$nombre" permanentemente de Firestore. '
                                          'El archivo de audio en GitHub NO se borra.',
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar',
                                                style: TextStyle(
                                                    color: Colors.white38))),
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red.shade900),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Eliminar',
                                                style: TextStyle(
                                                    color: Colors.white))),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await ref.delete();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  '🗑️ "$nombre" eliminado')));
                                    }
                                  }
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                  enabled: false,
                                  height: 24,
                                  child: Text('ESTADO',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10))),
                              const PopupMenuItem(
                                  value: 'estado_proceso',
                                  child: Text('⚗️ En proceso',
                                      style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(
                                  value: 'estado_disponible',
                                  child: Text('✅ Disponible',
                                      style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(
                                  value: 'estado_investigacion',
                                  child: Text('🔬 En investigación',
                                      style: TextStyle(color: Colors.white))),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                  enabled: false,
                                  height: 24,
                                  child: Text('EDITAR',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10))),
                              const PopupMenuItem(
                                  value: 'fase',
                                  child: Text('📍 Cambiar fase',
                                      style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(
                                  value: 'tokens',
                                  child: Text('🪙 Tokens objetivo',
                                      style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(
                                  value: 'version',
                                  child: Text('🔢 Versión del sonido',
                                      style: TextStyle(color: Colors.white))),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                  value: 'eliminar',
                                  child: Text('🗑️ Eliminar sonido',
                                      style:
                                          TextStyle(color: Colors.redAccent))),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              // ── Tab 2: Testimonios pendientes ──────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(BioConfig.colTestimonios)
                    .where('estado', isEqualTo: 'pendiente')
                    .snapshots(),
                builder: (_, snap) {
                  if (snap.hasError) {
                    return _emptyState(
                        Icons.rate_review_outlined,
                        "Aún no hay información aquí",
                        "No se encontraron testimonios pendientes");
                  }
                  if (!snap.hasData) {
                    return Center(
                        child: CircularProgressIndicator(
                            color: BioConfig.colorPrimario));
                  }
                  if (snap.data!.docs.isEmpty) {
                    return _emptyState(Icons.check_circle_outline,
                        "Todo al día", "No hay testimonios pendientes ✅");
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (_, i) {
                      var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                      var ref = snap.data!.docs[i].reference;
                      return _adminCard(
                        icon: Icons.rate_review,
                        iconColor: Colors.amber,
                        title: d['nombre_usuario'] ?? 'Usuario',
                        subtitle: d['texto'] ?? '',
                        chips: [
                          _chip(d['sonido_nombre'] ?? '—', Colors.white12),
                        ],
                        actions: [
                          // Aprobar
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.greenAccent, size: 28),
                            tooltip: "Aprobar",
                            onPressed: () async {
                              await ref.update({'estado': 'aprobado'});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("✅ Testimonio aprobado")));
                              }
                            },
                          ),
                          // Rechazar (borrar)
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.redAccent, size: 28),
                            tooltip: "Rechazar",
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF1A1A1A),
                                  title: const Text("¿Rechazar testimonio?",
                                      style: TextStyle(color: Colors.white)),
                                  content: const Text(
                                      "Se eliminará permanentemente.",
                                      style: TextStyle(color: Colors.white54)),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancelar")),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("Eliminar",
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await ref.delete();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "🗑️ Testimonio rechazado")));
                                }
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              // ── Tab 3: Investigaciones ─────────────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('investigaciones')
                    .orderBy('fecha_creacion', descending: true)
                    .snapshots(),
                builder: (_, snap) {
                  if (snap.hasError) {
                    return _emptyState(Icons.science_outlined,
                        "Aún no hay información aquí", "");
                  }
                  if (!snap.hasData) {
                    return Center(
                        child: CircularProgressIndicator(
                            color: BioConfig.colorPrimario));
                  }
                  if (snap.data!.docs.isEmpty) {
                    return _emptyState(
                        Icons.science_outlined,
                        "Sin investigaciones",
                        "Toca + para publicar la primera");
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (_, i) {
                      var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                      var ref = snap.data!.docs[i].reference;
                      return _adminCard(
                        icon: Icons.biotech,
                        iconColor: Colors.greenAccent,
                        title: d['titulo'] ?? '—',
                        subtitle: d['resultado'] ?? '',
                        chips: [
                          _chip(d['fase'] ?? '—',
                              Colors.blue.withValues(alpha: 0.3),
                              textColor: Colors.lightBlue),
                          _chip("${d['sujetos'] ?? 0} sujetos", Colors.white12),
                          _chip(d['fecha'] ?? '—', Colors.white12),
                        ],
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 22),
                            tooltip: "Eliminar",
                            onPressed: () async {
                              await ref.delete();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "🗑️ Investigación eliminada")));
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              // ── Tab 4: Tesorería ───────────────────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(BioConfig.colRetiros)
                    .where('estado', isEqualTo: 'pendiente')
                    .orderBy('fecha_solicitud', descending: false)
                    .snapshots(),
                builder: (_, snap) {
                  if (snap.hasError) {
                    return _emptyState(Icons.account_balance,
                        "Aún no hay información aquí", "");
                  }
                  if (!snap.hasData) {
                    return Center(
                        child: CircularProgressIndicator(
                            color: BioConfig.colorPrimario));
                  }
                  if (snap.data!.docs.isEmpty) {
                    return _emptyState(
                        Icons.check_circle_outline,
                        "Sin cobros pendientes",
                        "Todas las solicitudes están al día ✅");
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (_, i) {
                      final doc = snap.data!.docs[i];
                      final d = doc.data() as Map<String, dynamic>;
                      DateTime? fechaSol;
                      if (d['fecha_solicitud'] != null) {
                        fechaSol = (d['fecha_solicitud'] as Timestamp).toDate();
                      }

                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: Colors.orange.withValues(alpha: 0.4))),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _verDetalleRetiro(doc),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('${d['monto_cop']} COP',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18)),
                                          Text(
                                              d['usuario_email'] ??
                                                  d['usuario_id'] ??
                                                  '—',
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11)),
                                        ]),
                                    const Icon(Icons.chevron_right,
                                        color: Colors.orange, size: 24),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(children: [
                                  _chip('⏳ Pendiente',
                                      Colors.orange.withValues(alpha: 0.2),
                                      textColor: Colors.orange),
                                  _chip('🔑 ${d['llave_breb'] ?? '—'}',
                                      Colors.white10),
                                  if (fechaSol != null)
                                    _chip(
                                        '📅 ${fechaSol.day}/${fechaSol.month}/${fechaSol.year}',
                                        Colors.white10),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  // Confirmar pago
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      icon: const Icon(Icons.check_circle,
                                          size: 18),
                                      label: const Text("Confirmar pago",
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                      onPressed: () => _confirmarPago(doc),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Rechazar
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(
                                              color: Colors.redAccent),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      icon: const Icon(Icons.cancel, size: 18),
                                      label: const Text("Rechazar",
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                      onPressed: () => _rechazarRetiro(doc),
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // ── Tab 5: Solicitudes PS ──────────────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(BioConfig.colSolicitudesPS)
                    .where('estado', isEqualTo: 'pendiente')
                    .orderBy('fecha', descending: false)
                    .snapshots(),
                builder: (_, snap) {
                  if (snap.hasError) {
                    return _emptyState(
                        Icons.verified_user, "Aún no hay información aquí", "");
                  }
                  if (!snap.hasData) {
                    return Center(
                        child: CircularProgressIndicator(
                            color: BioConfig.colorPrimario));
                  }
                  if (snap.data!.docs.isEmpty) {
                    return _emptyState(
                        Icons.verified_user,
                        "Sin solicitudes PS pendientes",
                        "No hay nuevas solicitudes de verificación ✅");
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (_, i) {
                      final doc = snap.data!.docs[i];
                      final d = doc.data() as Map<String, dynamic>;
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color:
                                    Colors.tealAccent.withValues(alpha: 0.4))),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.medical_services_outlined,
                                      color: Colors.tealAccent, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d['nombre_completo'] ?? '—',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                      Text(d['usuario_id'] ?? '',
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11)),
                                    ],
                                  )),
                                ]),
                                const SizedBox(height: 8),
                                Wrap(children: [
                                  _chip('CC: ${d['cedula'] ?? '—'}',
                                      Colors.white10),
                                  _chip(
                                      'Reg: ${d['registro_profesional'] ?? '—'}',
                                      Colors.teal.withValues(alpha: 0.2),
                                      textColor: Colors.tealAccent),
                                ]),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.tealAccent,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      icon:
                                          const Icon(Icons.verified, size: 18),
                                      label: const Text('Aprobar PS',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      onPressed: () => _aprobarPS(doc),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(
                                              color: Colors.redAccent),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      icon: const Icon(Icons.cancel, size: 18),
                                      label: const Text('Rechazar',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () => _rechazarPS(doc),
                                    ),
                                  ),
                                ]),
                              ]),
                        ),
                      );
                    },
                  );
                },
              ),

              // ── Tab 6: Recetas — Solicitudes pendientes de sonidos ──────────
              const _TabRecetasPendientes(),

              // ── Tab 7: SQC ────────────────────────────────────────────────
              const TabSQC(),

              // ── Tab 7: Árbol Familiar BioFreq ─────────────────────────────

              // ── Tab 8: Chat Admin ──────────────────────────────────────────
              // ⚠️  Centraliza todos los mensajes donde receptor_id == 'admin'.
              //     Al abrir un canal, marca todos sus mensajes como leídos.
              //     NO mover a otro widget — necesita acceso al contexto del panel.

              // ── Tab 9: Planes de Suscripción ───────────────────────────
              const _TabPlanesSuscripcion(),
              const _TabCodigosMacro(),
              const _TabMarketingAdmin(),
              const _TabArbolGenealogico(),
              const _TabEstadoTecnico(),
            ],
          ),
        );
      },
    );
  }

  // ── Aprobar PS ──────────────────────────────────────────────────────────────
  Future<void> _aprobarPS(QueryDocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final uid = d['usuario_id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("¿Aprobar como PS?",
            style: TextStyle(color: Colors.white)),
        content: Text(
            "El usuario ${d['nombre_completo']} recibirá rol PS y código BIOMED-XXXX.",
            style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Aprobar"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Generar código BIOMED
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final rng = Random();
      final sufijo =
          List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
      final codigoPS = 'BIOMED-$sufijo';

      final batch = FirebaseFirestore.instance.batch();
      // Actualizar usuario
      batch.update(
          FirebaseFirestore.instance.collection(BioConfig.colUsuarios).doc(uid),
          {
            'rol': BioConfig.rolPS,
            'can_invite': true,
            'estado_ps': 'aprobado',
            BioConfig.campoCodigoPropio: codigoPS,
          });
      // Marcar solicitud como aprobada
      batch.update(doc.reference, {
        'estado': 'aprobado',
        'fecha_resolucion': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '✅ ${d['nombre_completo']} aprobado como PS con código $codigoPS')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Rechazar solicitud PS ───────────────────────────────────────────────────
  Future<void> _rechazarPS(QueryDocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final uid = d['usuario_id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("¿Rechazar solicitud PS?",
            style: TextStyle(color: Colors.white)),
        content: Text("Se rechazará la solicitud de ${d['nombre_completo']}.",
            style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Rechazar"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(doc.reference, {
        'estado': 'rechazado',
        'fecha_resolucion': FieldValue.serverTimestamp(),
      });
      batch.update(
          FirebaseFirestore.instance.collection(BioConfig.colUsuarios).doc(uid),
          {
            'estado_ps': 'rechazado',
          });
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Solicitud rechazada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Ver detalle del retiro ──────────────────────────────────────────────────
  void _verDetalleRetiro(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime? fechaSol;
    if (d['fecha_solicitud'] != null) {
      fechaSol = (d['fecha_solicitud'] as Timestamp).toDate();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DETALLE DE SOLICITUD",
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 16),
              _detalleRow(Icons.attach_money, "Monto", '${d['monto_cop']} COP'),
              _detalleRow(
                  Icons.key_outlined, "Llave BreB", d['llave_breb'] ?? '—'),
              _detalleRow(
                  Icons.person_outline,
                  "Usuario",
                  d['usuario_nombre'] ??
                      d['usuario_email'] ??
                      d['usuario_id'] ??
                      '—'),
              _detalleRow(
                  Icons.email_outlined, "Correo", d['usuario_email'] ?? '—'),
              if (fechaSol != null)
                _detalleRow(
                    Icons.calendar_today,
                    "Solicitado",
                    '${fechaSol.day}/${fechaSol.month}/${fechaSol.year} '
                        '${fechaSol.hour}:${fechaSol.minute.toString().padLeft(2, '0')}'),
              const SizedBox(height: 8),
              // Botón copiar llave
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: BioConfig.colorPrimario,
                      side: BorderSide(color: BioConfig.colorPrimario)),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text("Copiar llave BreB"),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: d['llave_breb'] ?? ''));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("📋 Llave copiada al portapapeles")));
                    }
                  },
                ),
              ),
            ]),
      ),
    );
  }

  Widget _detalleRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );

  // ── Confirmar pago ──────────────────────────────────────────────────────────
  Future<void> _confirmarPago(QueryDocumentSnapshot doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("¿Confirmar pago?",
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Marcar ${(doc.data() as Map)['monto_cop']} COP como pagado.',
            style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("Confirmar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await doc.reference.update({
        'estado': 'pagado',
        'fecha_pago': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Pago confirmado"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // ── Rechazar retiro + devolver tokens ──────────────────────────────────────
  Future<void> _rechazarRetiro(QueryDocumentSnapshot doc) async {
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Rechazar solicitud",
            style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Ingresa un motivo breve (se mostrará al usuario):",
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: motivoCtrl,
            maxLength: 120,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Ej: Llave incorrecta, cuenta no válida...",
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12)),
              counterStyle: const TextStyle(color: Colors.white38),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Rechazar y devolver tokens",
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final d = doc.data() as Map<String, dynamic>;
      final uid = d['usuario_id'] as String;
      final tokens = BioConfig.toInt(d['tokens_usados'] ?? d['monto_cop']);
      final batch = FirebaseFirestore.instance.batch();

      // Cambiar estado del retiro
      batch.update(doc.reference, {
        'estado': 'rechazado',
        'motivo_rechazo': motivoCtrl.text.trim(),
        'fecha_rechazo': FieldValue.serverTimestamp(),
      });

      // Devolver tokens al usuario
      batch.update(
        FirebaseFirestore.instance.collection(BioConfig.colUsuarios).doc(uid),
        {BioConfig.campoTokens: FieldValue.increment(tokens)},
      );

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "❌ Solicitud rechazada. $tokens tokens devueltos al usuario.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // ── Diálogo editar campo texto (fase, versión, etc.) ─────────────────────
  void _mostrarEditorSonidoAdmin({
    required String sonidoId,
    required DocumentReference ref,
    required Map<String, dynamic> data,
  }) {
    final costoCtrl = TextEditingController(
        text: BioConfig.toInt(data['costo_uso']).toString());
    final faseCtrl =
        TextEditingController(text: (data['fase'] ?? '').toString());
    final descripcion = (data['descripcion'] ?? '').toString();
    final nombre = (data['Nombre'] ?? sonidoId).toString();
    String estado =
        (data['estado'] ?? BioConfig.estadoDisponible).toString().trim();
    String nivel =
        (data['nivel_requerido'] ?? '').toString().trim().toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: BioConfig.colorPrimario),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (descripcion.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: costoCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _deco(
                    'Costo por uso (tokens)',
                    hint: '0 = usar taxímetro por duración',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      side: const BorderSide(color: Colors.tealAccent),
                    ),
                    onPressed: () => setModalState(() => costoCtrl.text = '0'),
                    icon: const Icon(Icons.speed, size: 18),
                    label: const Text('Usar taxímetro'),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: estado,
                  dropdownColor: const Color(0xFF1E1E2E),
                  decoration: _deco('Estado'),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: BioConfig.estadoDisponible,
                      child: Text('Disponible'),
                    ),
                    DropdownMenuItem(
                      value: BioConfig.estadoEnProceso,
                      child: Text('En proceso'),
                    ),
                    DropdownMenuItem(
                      value: BioConfig.estadoInvestigacion,
                      child: Text('En investigación'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => estado = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: nivel.isEmpty ? 'NINGUNO' : nivel,
                  dropdownColor: const Color(0xFF1E1E2E),
                  decoration: _deco('Nivel requerido'),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'NINGUNO', child: Text('Ninguno')),
                    DropdownMenuItem(value: 'PRO', child: Text('PRO')),
                    DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => nivel = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: faseCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _deco(
                    'Fase / etapa',
                    hint: 'desarrollo, pruebas, producción...',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        onPressed: () async {
                          final confirmar = await showDialog<bool>(
                            context: sheetCtx,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E2E),
                              title: const Text(
                                '¿Eliminar sonido?',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                'Se eliminará "$nombre" permanentemente de Firestore.',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (confirmar == true) {
                            await ref.delete();
                            if (!mounted) return;
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('🗑️ "$nombre" eliminado')),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Eliminar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BioConfig.colorPrimario,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          final costo = int.tryParse(costoCtrl.text.trim());
                          if (costo == null || costo < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Costo por uso inválido'),
                              ),
                            );
                            return;
                          }
                          await ref.update({
                            'costo_uso': costo,
                            'estado': estado,
                            'nivel_requerido': nivel == 'NINGUNO' ? '' : nivel,
                            'fase': faseCtrl.text.trim(),
                            'duracion_seg': FieldValue.delete(),
                            'duracion_segundos': FieldValue.delete(),
                          });
                          if (!mounted) return;
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Sonido actualizado'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dialogEditarCampoTexto({
    required String titulo,
    required String campo,
    required String valorActual,
    required DocumentReference ref,
    String hint = '',
  }) {
    final ctrl = TextEditingController(text: valorActual);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(titulo, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BioConfig.colorPrimario,
                  foregroundColor: Colors.black),
              onPressed: () async {
                final val = ctrl.text.trim();
                if (val.isEmpty) return;
                await ref.update({campo: val});
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ $titulo actualizado')));
                }
              },
              child: const Text('Guardar')),
        ],
      ),
    );
  }

  // ── Diálogo editar campo numérico (tokens objetivo, etc.) ─────────────────
  void _dialogEditarCampoNumero({
    required String titulo,
    required String campo,
    required int valorActual,
    required DocumentReference ref,
  }) {
    final ctrl = TextEditingController(text: valorActual.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(titulo, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ingresa el valor',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BioConfig.colorPrimario,
                  foregroundColor: Colors.black),
              onPressed: () async {
                final val = int.tryParse(ctrl.text.trim());
                if (val == null) return;
                await ref.update({campo: val});
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('✅ $titulo: $val')));
                }
              },
              child: const Text('Guardar')),
        ],
      ),
    );
  }

  static Widget _emptyState(IconData icon, String title, String sub) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white12, size: 64),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: Colors.white24, fontSize: 12)),
      ]));

  static Widget _chip(String label, Color bg,
          {Color textColor = Colors.white54}) =>
      Container(
        margin: const EdgeInsets.only(right: 6, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: textColor, fontSize: 10)),
      );

  Widget _adminCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> chips,
    required List<Widget> actions,
    bool coreStyle = false,
    VoidCallback? onTap,
  }) =>
      Card(
        color: coreStyle
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFF1E1E1E),
        margin: coreStyle
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
            : const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(coreStyle ? 16 : 14),
          side: BorderSide(color: coreStyle ? Colors.white12 : Colors.white10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(coreStyle ? 16 : 14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(coreStyle ? 14 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: iconColor, size: coreStyle ? 36 : 22),
                  SizedBox(width: coreStyle ? 12 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                coreStyle ? FontWeight.w600 : FontWeight.bold,
                            fontSize: coreStyle ? 15 : 14,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: coreStyle ? Colors.grey : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                ]),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(children: chips),
                ],
              ],
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// CONSULTORIO VIRTUAL — Centro operativo exclusivo para roles PS y Admin
// Tabs: Prescripciones · Comunicación · Invitaciones · Papers · Alertas Bio-Scanner
// ═══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// Tab Admin: Arbol Genealogico
// ─────────────────────────────────────────────────────────────────────────────
class _TabArbolGenealogico extends StatefulWidget {
  const _TabArbolGenealogico();

  @override
  State<_TabArbolGenealogico> createState() => _TabArbolGenealogicoState();
}

class _TabArbolGenealogicoState extends State<_TabArbolGenealogico> {
  String _txt(dynamic value) => value?.toString().trim() ?? '';

  String _nombreUsuario(Map<String, dynamic> data) {
    return _txt(data['nombre']).isNotEmpty
        ? _txt(data['nombre'])
        : _txt(data['displayName']).isNotEmpty
            ? _txt(data['displayName'])
            : _txt(data['email']).isNotEmpty
                ? _txt(data['email'])
                : 'Sin nombre';
  }

  List<String> _uidsDeRama(
    String uid,
    Map<String, Map<String, dynamic>> usuariosPorUid,
    Map<String, List<String>> hijosPorUid,
  ) {
    final resultado = <String>[];
    void recorrer(String actual) {
      resultado.add(actual);
      for (final hijo in hijosPorUid[actual] ?? const <String>[]) {
        recorrer(hijo);
      }
    }

    if (usuariosPorUid.containsKey(uid)) recorrer(uid);
    return resultado;
  }

  String? _resolverMedicoParaUid(
    String uid,
    Map<String, Map<String, dynamic>> usuariosPorUid,
    Map<String, String> uidPorCodigo,
  ) {
    final actual = usuariosPorUid[uid];
    if (actual == null) return null;
    final rolActual = _txt(actual['rol']);
    if (rolActual == BioConfig.rolPS || rolActual == BioConfig.rolAdmin) {
      return uid;
    }

    final visitados = <String>{uid};
    String codigoPadre = _txt(actual[BioConfig.campoReferidoPor]);
    while (codigoPadre.isNotEmpty) {
      final uidPadre = uidPorCodigo[codigoPadre];
      if (uidPadre == null || visitados.contains(uidPadre)) break;
      visitados.add(uidPadre);
      final padre = usuariosPorUid[uidPadre];
      if (padre == null) break;
      final rolPadre = _txt(padre['rol']);
      if (rolPadre == BioConfig.rolPS || rolPadre == BioConfig.rolAdmin) {
        return uidPadre;
      }
      codigoPadre = _txt(padre[BioConfig.campoReferidoPor]);
    }

    for (final entry in usuariosPorUid.entries) {
      if (_txt(entry.value['rol']) == BioConfig.rolAdmin) return entry.key;
    }
    return null;
  }

  Future<void> _recalcularMedicos(
    Iterable<String> uids,
    Map<String, Map<String, dynamic>> usuariosPorUid,
    Map<String, String> uidPorCodigo,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final uid in uids) {
      final medicoId =
          _resolverMedicoParaUid(uid, usuariosPorUid, uidPorCodigo);
      batch.set(
        FirebaseFirestore.instance.collection(BioConfig.colUsuarios).doc(uid),
        {BioConfig.campoMedicoId: medicoId ?? ''},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> _cambiarRol(
    String uid,
    String nuevoRol,
    Map<String, Map<String, dynamic>> usuariosPorUid,
    Map<String, String> uidPorCodigo,
    Map<String, List<String>> hijosPorUid,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance.collection(BioConfig.colUsuarios).doc(uid),
      {'rol': nuevoRol},
      SetOptions(merge: true),
    );
    await batch.commit();
    final rama = _uidsDeRama(uid, usuariosPorUid, hijosPorUid);
    final copia = {
      for (final e in usuariosPorUid.entries)
        e.key: Map<String, dynamic>.from(e.value),
    };
    copia[uid] = {...?copia[uid], 'rol': nuevoRol};
    await _recalcularMedicos(rama, copia, uidPorCodigo);
  }

  Future<void> _moverNodo({
    required String uid,
    required String? codigoDestino,
    required bool moverRamaCompleta,
    required Map<String, Map<String, dynamic>> usuariosPorUid,
    required Map<String, String> uidPorCodigo,
    required Map<String, List<String>> hijosPorUid,
  }) async {
    final actual = usuariosPorUid[uid];
    if (actual == null) return;
    final codigoAnterior = _txt(actual[BioConfig.campoReferidoPor]);
    final batch = FirebaseFirestore.instance.batch();
    final refUsuario =
        FirebaseFirestore.instance.collection(BioConfig.colUsuarios).doc(uid);

    batch.set(
      refUsuario,
      {BioConfig.campoReferidoPor: codigoDestino ?? ''},
      SetOptions(merge: true),
    );

    if (!moverRamaCompleta) {
      for (final hijoUid in hijosPorUid[uid] ?? const <String>[]) {
        batch.set(
          FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .doc(hijoUid),
          {BioConfig.campoReferidoPor: codigoAnterior},
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();

    final copia = {
      for (final e in usuariosPorUid.entries)
        e.key: Map<String, dynamic>.from(e.value),
    };
    copia[uid] = {
      ...?copia[uid],
      BioConfig.campoReferidoPor: codigoDestino ?? ''
    };
    if (!moverRamaCompleta) {
      for (final hijoUid in hijosPorUid[uid] ?? const <String>[]) {
        copia[hijoUid] = {
          ...?copia[hijoUid],
          BioConfig.campoReferidoPor: codigoAnterior,
        };
      }
    }

    final ramaPrincipal = _uidsDeRama(uid, copia, _construirHijosPorUid(copia));
    final ramaAjustada = <String>{...ramaPrincipal};
    if (!moverRamaCompleta) {
      for (final hijoUid in hijosPorUid[uid] ?? const <String>[]) {
        ramaAjustada
            .addAll(_uidsDeRama(hijoUid, copia, _construirHijosPorUid(copia)));
      }
    }
    await _recalcularMedicos(ramaAjustada, copia, uidPorCodigo);
  }

  Map<String, List<String>> _construirHijosPorUid(
    Map<String, Map<String, dynamic>> usuariosPorUid,
  ) {
    final uidPorCodigo = <String, String>{};
    for (final entry in usuariosPorUid.entries) {
      final codigo = _txt(entry.value[BioConfig.campoCodigoPropio]);
      if (codigo.isNotEmpty) uidPorCodigo[codigo] = entry.key;
    }

    final hijos = <String, List<String>>{};
    for (final entry in usuariosPorUid.entries) {
      final codigoPadre = _txt(entry.value[BioConfig.campoReferidoPor]);
      final uidPadre = uidPorCodigo[codigoPadre];
      if (uidPadre == null) continue;
      hijos.putIfAbsent(uidPadre, () => <String>[]).add(entry.key);
    }
    return hijos;
  }

  Future<void> _banear({
    required String uid,
    required bool ramaCompleta,
    required Map<String, Map<String, dynamic>> usuariosPorUid,
    required Map<String, List<String>> hijosPorUid,
    required bool suspendido,
  }) async {
    final objetivos = ramaCompleta
        ? _uidsDeRama(uid, usuariosPorUid, hijosPorUid)
        : <String>[uid];
    final batch = FirebaseFirestore.instance.batch();
    for (final itemUid in objetivos) {
      batch.set(
        FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(itemUid),
        {
          BioConfig.campoSuspendido: suspendido,
          BioConfig.campoEstadoCuenta: suspendido ? 'baneado' : 'activo',
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> _abrirAccionesNodo({
    required String uid,
    required Map<String, dynamic> data,
    required Map<String, Map<String, dynamic>> usuariosPorUid,
    required Map<String, String> uidPorCodigo,
    required Map<String, List<String>> hijosPorUid,
  }) async {
    final rama = _uidsDeRama(uid, usuariosPorUid, hijosPorUid).toSet();
    final codigoPropio = _txt(data[BioConfig.campoCodigoPropio]);
    final destinos = usuariosPorUid.entries.where((e) {
      final codigo = _txt(e.value[BioConfig.campoCodigoPropio]);
      return codigo.isNotEmpty &&
          !rama.contains(e.key) &&
          codigo != codigoPropio;
    }).toList()
      ..sort(
          (a, b) => _nombreUsuario(a.value).compareTo(_nombreUsuario(b.value)));

    String rolSeleccionado =
        _txt(data['rol']).isNotEmpty ? _txt(data['rol']) : BioConfig.rolUser;
    String? destinoSeleccionado;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreUsuario(data),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  codigoPropio.isEmpty ? 'Sin codigo propio' : codigoPropio,
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: rolSeleccionado,
                  dropdownColor: const Color(0xFF1E1E1E),
                  decoration: _PantallaAdminState._deco('Cambiar rol'),
                  items: const [
                    DropdownMenuItem(
                        value: BioConfig.rolUser, child: Text('User')),
                    DropdownMenuItem(value: BioConfig.rolPS, child: Text('PS')),
                    DropdownMenuItem(
                        value: BioConfig.rolTester, child: Text('Tester')),
                    DropdownMenuItem(
                      value: BioConfig.rolMarketing,
                      child: Text('Marketing'),
                    ),
                    DropdownMenuItem(
                        value: BioConfig.rolAdmin, child: Text('Admin')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => rolSeleccionado = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: destinoSeleccionado,
                  dropdownColor: const Color(0xFF1E1E1E),
                  decoration: _PantallaAdminState._deco('Mover bajo codigo'),
                  items: destinos
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: _txt(entry.value[BioConfig.campoCodigoPropio]),
                          child: Text(
                            '${_nombreUsuario(entry.value)} (${_txt(entry.value[BioConfig.campoCodigoPropio])})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setModalState(() => destinoSeleccionado = v),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _cambiarRol(
                          uid,
                          rolSeleccionado,
                          usuariosPorUid,
                          uidPorCodigo,
                          hijosPorUid,
                        );
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Guardar rol'),
                    ),
                    ElevatedButton.icon(
                      onPressed: destinoSeleccionado == null
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _moverNodo(
                                uid: uid,
                                codigoDestino: destinoSeleccionado,
                                moverRamaCompleta: false,
                                usuariosPorUid: usuariosPorUid,
                                uidPorCodigo: uidPorCodigo,
                                hijosPorUid: hijosPorUid,
                              );
                            },
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Mover user'),
                    ),
                    ElevatedButton.icon(
                      onPressed: destinoSeleccionado == null
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _moverNodo(
                                uid: uid,
                                codigoDestino: destinoSeleccionado,
                                moverRamaCompleta: true,
                                usuariosPorUid: usuariosPorUid,
                                uidPorCodigo: uidPorCodigo,
                                hijosPorUid: hijosPorUid,
                              );
                            },
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text('Mover linea'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _banear(
                          uid: uid,
                          ramaCompleta: false,
                          usuariosPorUid: usuariosPorUid,
                          hijosPorUid: hijosPorUid,
                          suspendido: true,
                        );
                      },
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Banear user'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _banear(
                          uid: uid,
                          ramaCompleta: true,
                          usuariosPorUid: usuariosPorUid,
                          hijosPorUid: hijosPorUid,
                          suspendido: true,
                        );
                      },
                      icon: const Icon(Icons.device_hub_outlined),
                      label: const Text('Banear rama'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _banear(
                          uid: uid,
                          ramaCompleta: true,
                          usuariosPorUid: usuariosPorUid,
                          hijosPorUid: hijosPorUid,
                          suspendido: false,
                        );
                      },
                      icon: const Icon(Icons.restart_alt_outlined),
                      label: const Text('Desbanear rama'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipNodo(String texto, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNodo(
    String uid,
    int depth,
    Map<String, Map<String, dynamic>> usuariosPorUid,
    Map<String, String> uidPorCodigo,
    Map<String, List<String>> hijosPorUid,
  ) {
    final data = usuariosPorUid[uid]!;
    final nombre = _nombreUsuario(data);
    final codigo = _txt(data[BioConfig.campoCodigoPropio]);
    final referidoPor = _txt(data[BioConfig.campoReferidoPor]);
    final rol = _txt(data['rol']);
    final hijos = List<String>.from(hijosPorUid[uid] ?? const <String>[])
      ..sort((a, b) => _nombreUsuario(usuariosPorUid[a]!)
          .compareTo(_nombreUsuario(usuariosPorUid[b]!)));
    final suspendido = BioConfig.cuentaBaneada(data);
    final referidoUid = uidPorCodigo[referidoPor];
    final referidoData =
        referidoUid == null ? null : usuariosPorUid[referidoUid];
    final medicoUid = _txt(data[BioConfig.campoMedicoId]);
    final medicoData = medicoUid.isEmpty ? null : usuariosPorUid[medicoUid];

    return Container(
      margin: EdgeInsets.only(left: depth * 18.0, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: suspendido
              ? Colors.redAccent.withValues(alpha: 0.45)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: BioConfig.colorPrimario.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_circle_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      codigo.isEmpty ? 'Sin codigo propio' : codigo,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _abrirAccionesNodo(
                  uid: uid,
                  data: data,
                  usuariosPorUid: usuariosPorUid,
                  uidPorCodigo: uidPorCodigo,
                  hijosPorUid: hijosPorUid,
                ),
                icon: const Icon(Icons.edit_outlined, color: Colors.white54),
              ),
            ],
          ),
          Wrap(
            children: [
              _chipNodo(BioConfig.etiquetaRol(rol), Colors.orangeAccent),
              if (suspendido) _chipNodo('Baneado', Colors.redAccent),
              if (referidoData != null)
                _chipNodo(
                  'Debajo de ${_nombreUsuario(referidoData)}',
                  Colors.lightBlueAccent,
                ),
              if (medicoData != null)
                _chipNodo(
                  'PS ${_nombreUsuario(medicoData)}',
                  Colors.tealAccent,
                ),
              if (hijos.isNotEmpty)
                _chipNodo('${hijos.length} referidos directos', Colors.white70),
            ],
          ),
          if (hijos.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...hijos.map(
              (childUid) => _buildNodo(
                childUid,
                depth + 1,
                usuariosPorUid,
                uidPorCodigo,
                hijosPorUid,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.tealAccent),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Sin usuarios todavia',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final usuariosPorUid = <String, Map<String, dynamic>>{
          for (final doc in docs) doc.id: Map<String, dynamic>.from(doc.data()),
        };
        final uidPorCodigo = <String, String>{};
        for (final entry in usuariosPorUid.entries) {
          final codigo = _txt(entry.value[BioConfig.campoCodigoPropio]);
          if (codigo.isNotEmpty) uidPorCodigo[codigo] = entry.key;
        }
        final hijosPorUid = _construirHijosPorUid(usuariosPorUid);
        final raices = usuariosPorUid.entries
            .where((entry) {
              final codigoPadre = _txt(entry.value[BioConfig.campoReferidoPor]);
              if (codigoPadre.isEmpty) return true;
              return !uidPorCodigo.containsKey(codigoPadre);
            })
            .map((entry) => entry.key)
            .toList()
          ..sort(
            (a, b) => _nombreUsuario(usuariosPorUid[a]!)
                .compareTo(_nombreUsuario(usuariosPorUid[b]!)),
          );

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'Admin puede mover users o lineas completas, cambiar rol y banear ramas sin salir del arbol.',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.35),
              ),
            ),
            const SizedBox(height: 8),
            ...raices.map(
              (uid) => _buildNodo(
                uid,
                0,
                usuariosPorUid,
                uidPorCodigo,
                hijosPorUid,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Admin: Planes de Suscripcion - editar precios desde el panel
// Guarda en: configuracion/planes_suscripcion -> {plan_15d, plan_1m, plan_6m, plan_1a}
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Tab Admin: Códigos Macro - configuración de segmentos por prefijo
// Guarda en: configuracion/segmentos_macro -> { segmentos: [...] }
// ─────────────────────────────────────────────────────────────────────────────
class _TabCodigosMacroLegacyTemp extends StatefulWidget {
  const _TabCodigosMacroLegacyTemp();

  @override
  State<_TabCodigosMacroLegacyTemp> createState() =>
      _TabCodigosMacroLegacyTempState();
}

class _TabCodigosMacroLegacyTempState
    extends State<_TabCodigosMacroLegacyTemp> {
  bool _cargando = true;
  bool _guardando = false;
  List<Map<String, dynamic>> _segmentos = const [];

  String _txt(dynamic value) => value?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool force = true}) async {
    if (mounted) {
      setState(() => _cargando = true);
    }
    final items = await MacroSegmentoConfig.load(force: force);
    if (!mounted) return;
    setState(() {
      _segmentos =
          items.map((item) => Map<String, dynamic>.from(item)).toList();
      _cargando = false;
    });
  }

  void _snack(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        content: Text(message),
      ),
    );
  }

  Future<void> _guardarSegmentos(
    List<Map<String, dynamic>> items, {
    required String okMessage,
  }) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await MacroSegmentoConfig.saveAll(items);
      final fresh = await MacroSegmentoConfig.load(force: true);
      if (!mounted) return;
      setState(() {
        _segmentos =
            fresh.map((item) => Map<String, dynamic>.from(item)).toList();
      });
      _snack(okMessage, backgroundColor: Colors.green);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _crearSegmento() async {
    final nuevo = await _dialogSegmento();
    if (nuevo == null) return;
    await _guardarSegmentos(
      [..._segmentos, nuevo],
      okMessage: 'Segmento macro creado',
    );
  }

  Future<void> _editarSegmento(Map<String, dynamic> original) async {
    final editado = await _dialogSegmento(initial: original);
    if (editado == null) return;
    final id = _txt(original['id']);
    final next = _segmentos
        .map(
          (item) => _txt(item['id']) == id
              ? editado
              : Map<String, dynamic>.from(item),
        )
        .toList();
    await _guardarSegmentos(
      next,
      okMessage: 'Segmento macro actualizado',
    );
  }

  Future<void> _eliminarSegmento(Map<String, dynamic> item) async {
    if (_guardando) return;
    final nombre = _txt(item['nombre']).isNotEmpty
        ? _txt(item['nombre'])
        : _txt(item['prefijo_codigo']);
    final prefijo = _txt(item['prefijo_codigo']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar segmento macro',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Se eliminará "$nombre" y dejará de aplicarse al prefijo $prefijo.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final targetId = _txt(item['id']);
    final next = _segmentos
        .where((segmento) => _txt(segmento['id']) != targetId)
        .map((segmento) => Map<String, dynamic>.from(segmento))
        .toList();
    await _guardarSegmentos(
      next,
      okMessage: 'Segmento macro eliminado',
    );
  }

  int? _parseOptionalInt(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 0;
    final value = int.tryParse(text);
    if (value == null || value < 0) return null;
    return value;
  }

  Future<Map<String, dynamic>?> _dialogSegmento({
    Map<String, dynamic>? initial,
  }) async {
    final nombreCtrl = TextEditingController(text: _txt(initial?['nombre']));
    final descripcionCtrl =
        TextEditingController(text: _txt(initial?['descripcion']));
    final prefijoCtrl =
        TextEditingController(text: _txt(initial?['prefijo_codigo']));
    final valorTokenActual =
        BioConfig.toInt(initial?[BioConfig.campoValorTokenCop]);
    final maxInvitadosActual =
        BioConfig.toInt(initial?[BioConfig.campoMaxInvitados]);
    final valorTokenCtrl = TextEditingController(
      text: valorTokenActual > 0 ? valorTokenActual.toString() : '',
    );
    final maxInvitadosCtrl = TextEditingController(
      text: maxInvitadosActual > 0 ? maxInvitadosActual.toString() : '',
    );

    var activo = initial?['activo'] != false;
    bool? canInvite =
        initial?['can_invite'] is bool ? initial!['can_invite'] as bool : null;
    var editableValorToken = initial?['editable_valor_token'] == true;
    var editableCanInvite = initial?['editable_can_invite'] == true;
    var editableMaxInvitados = initial?['editable_max_invitados'] == true;
    final currentId = _txt(initial?['id']);

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) {
            void submit() {
              final nombre = nombreCtrl.text.trim();
              final prefijo =
                  MacroSegmentoConfig.normalizarPrefijo(prefijoCtrl.text);
              final valorToken = _parseOptionalInt(valorTokenCtrl.text);
              final maxInvitados = _parseOptionalInt(maxInvitadosCtrl.text);

              if (nombre.isEmpty) {
                _snack('El nombre es obligatorio');
                return;
              }
              if (prefijo.isEmpty) {
                _snack('El prefijo del código es obligatorio');
                return;
              }
              if (valorToken == null) {
                _snack('Valor token COP inválido');
                return;
              }
              if (maxInvitados == null) {
                _snack('Máximo de invitados inválido');
                return;
              }

              final repetido = _segmentos.any((segmento) {
                final sameId = _txt(segmento['id']) == currentId;
                if (sameId) return false;
                return MacroSegmentoConfig.normalizarPrefijo(
                      _txt(segmento['prefijo_codigo']),
                    ) ==
                    prefijo;
              });
              if (repetido) {
                _snack('Ya existe otro segmento usando ese prefijo');
                return;
              }

              final fallbackId = currentId.isNotEmpty
                  ? currentId
                  : 'macro_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

              Navigator.pop(
                ctx,
                MacroSegmentoConfig.normalizarSegmento(
                  {
                    'id': currentId.isNotEmpty ? currentId : fallbackId,
                    'nombre': nombre,
                    'descripcion': descripcionCtrl.text.trim(),
                    'prefijo_codigo': prefijo,
                    'activo': activo,
                    BioConfig.campoValorTokenCop: valorToken,
                    'can_invite': canInvite,
                    BioConfig.campoMaxInvitados: maxInvitados,
                    'editable_valor_token': editableValorToken,
                    'editable_can_invite': editableCanInvite,
                    'editable_max_invitados': editableMaxInvitados,
                  },
                  fallbackId: fallbackId,
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.qr_code_2_outlined,
                      color: Colors.cyanAccent),
                  const SizedBox(width: 10),
                  Text(
                    initial == null
                        ? 'Nuevo código macro'
                        : 'Editar código macro',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Usa 0 o deja vacío para heredar la configuración base. Los prefijos se guardan en mayúsculas y sin espacios.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PantallaAdminState._campoTexto(nombreCtrl, 'Nombre'),
                      _PantallaAdminState._campoTexto(
                        descripcionCtrl,
                        'Descripción',
                        hint: 'Contexto comercial, afiliado o convenio',
                        maxLines: 3,
                      ),
                      _PantallaAdminState._campoTexto(
                        prefijoCtrl,
                        'Prefijo del código',
                        hint: 'Ej: BIOVIP o MED-',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _PantallaAdminState._campoTexto(
                              valorTokenCtrl,
                              'Valor token COP',
                              hint: '0 = heredar',
                              keyboard: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PantallaAdminState._campoTexto(
                              maxInvitadosCtrl,
                              'Máx. usuarios invitados',
                              hint: '0 = heredar',
                              keyboard: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _switchTile(
                        color: Colors.greenAccent,
                        icon: Icons.toggle_on_outlined,
                        title: 'Segmento activo',
                        subtitle:
                            'Si está inactivo, el prefijo queda registrado pero no se aplica.',
                        value: activo,
                        onChanged: (value) => setSt(() => activo = value),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: canInvite == null
                            ? 'inherit'
                            : (canInvite == true ? 'yes' : 'no'),
                        dropdownColor: const Color(0xFF1A1A1A),
                        iconEnabledColor: Colors.white70,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration:
                            _PantallaAdminState._deco('Permiso de invitación'),
                        items: const [
                          DropdownMenuItem(
                            value: 'inherit',
                            child: Text(
                              'Heredar configuración base',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'yes',
                            child: Text(
                              'Permitir invitaciones',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'no',
                            child: Text(
                              'Bloquear invitaciones',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSt(() {
                            if (value == 'yes') {
                              canInvite = true;
                            } else if (value == 'no') {
                              canInvite = false;
                            } else {
                              canInvite = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Campos editables por el usuario',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _switchTile(
                        color: Colors.orangeAccent,
                        icon: Icons.toll_outlined,
                        title: 'Editable valor del token',
                        subtitle:
                            'El usuario puede modificar su valor_token_cop.',
                        value: editableValorToken,
                        onChanged: (value) =>
                            setSt(() => editableValorToken = value),
                      ),
                      _switchTile(
                        color: Colors.lightBlueAccent,
                        icon: Icons.group_add_outlined,
                        title: 'Editable can_invite',
                        subtitle:
                            'El usuario puede cambiar si invita o no desde su ficha.',
                        value: editableCanInvite,
                        onChanged: (value) =>
                            setSt(() => editableCanInvite = value),
                      ),
                      _switchTile(
                        color: Colors.purpleAccent,
                        icon: Icons.groups_2_outlined,
                        title: 'Editable max_usuarios_invitados',
                        subtitle:
                            'El usuario puede ajustar su tope de invitados.',
                        value: editableMaxInvitados,
                        onChanged: (value) =>
                            setSt(() => editableMaxInvitados = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: submit,
                  icon: Icon(initial == null ? Icons.add : Icons.save_outlined),
                  label: Text(
                    initial == null ? 'Crear segmento' : 'Guardar cambios',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      nombreCtrl.dispose();
      descripcionCtrl.dispose();
      prefijoCtrl.dispose();
      valorTokenCtrl.dispose();
      maxInvitadosCtrl.dispose();
    }
  }

  Widget _switchTile({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        activeColor: color,
        value: value,
        onChanged: onChanged,
        title: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelCard({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSegmentoCard(Map<String, dynamic> item) {
    final nombre = _txt(item['nombre']).isNotEmpty
        ? _txt(item['nombre'])
        : _txt(item['prefijo_codigo']);
    final descripcion = _txt(item['descripcion']);
    final prefijo = _txt(item['prefijo_codigo']);
    final activo = item['activo'] != false;
    final canInvite = item['can_invite'] as bool?;
    final valorToken = BioConfig.toInt(item[BioConfig.campoValorTokenCop]);
    final maxInvitados = BioConfig.toInt(item[BioConfig.campoMaxInvitados]);
    final editableValorToken = item['editable_valor_token'] == true;
    final editableCanInvite = item['editable_can_invite'] == true;
    final editableMaxInvitados = item['editable_max_invitados'] == true;
    final canInviteLabel = canInvite == null
        ? 'Invita: hereda'
        : (canInvite ? 'Invita: sí' : 'Invita: no');
    final canInviteColor = canInvite == null
        ? Colors.white10
        : (canInvite
            ? Colors.lightBlueAccent.withValues(alpha: 0.16)
            : Colors.redAccent.withValues(alpha: 0.16));
    final canInviteTextColor = canInvite == null
        ? Colors.white60
        : (canInvite ? Colors.lightBlueAccent : Colors.redAccent);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (activo ? Colors.cyanAccent : Colors.white30)
              .withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (activo ? Colors.cyanAccent : Colors.white38)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  activo ? Icons.qr_code_2_outlined : Icons.qr_code_2_rounded,
                  color: activo ? Colors.cyanAccent : Colors.white54,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descripcion.isNotEmpty
                          ? descripcion
                          : 'Sin descripción adicional',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              _PantallaAdminState._chip(
                'Prefijo $prefijo',
                Colors.cyanAccent.withValues(alpha: 0.14),
                textColor: Colors.cyanAccent,
              ),
              _PantallaAdminState._chip(
                activo ? 'Activo' : 'Inactivo',
                (activo ? Colors.green : Colors.redAccent)
                    .withValues(alpha: 0.16),
                textColor: activo ? Colors.greenAccent : Colors.redAccent,
              ),
              _PantallaAdminState._chip(
                canInviteLabel,
                canInviteColor,
                textColor: canInviteTextColor,
              ),
              _PantallaAdminState._chip(
                valorToken > 0 ? 'Token $valorToken COP' : 'Token: hereda',
                Colors.orangeAccent.withValues(alpha: 0.16),
                textColor: Colors.orangeAccent,
              ),
              _PantallaAdminState._chip(
                maxInvitados > 0
                    ? 'Máx. invitados $maxInvitados'
                    : 'Máx. invitados: hereda',
                Colors.purpleAccent.withValues(alpha: 0.16),
                textColor: Colors.purpleAccent,
              ),
              _PantallaAdminState._chip(
                editableValorToken ? 'Token editable' : 'Token fijo',
                editableValorToken
                    ? Colors.orangeAccent.withValues(alpha: 0.16)
                    : Colors.white10,
                textColor:
                    editableValorToken ? Colors.orangeAccent : Colors.white60,
              ),
              _PantallaAdminState._chip(
                editableCanInvite
                    ? 'Invitaciones editables'
                    : 'Invitaciones fijas',
                editableCanInvite
                    ? Colors.lightBlueAccent.withValues(alpha: 0.16)
                    : Colors.white10,
                textColor:
                    editableCanInvite ? Colors.lightBlueAccent : Colors.white60,
              ),
              _PantallaAdminState._chip(
                editableMaxInvitados ? 'Máx. editable' : 'Máx. fijo',
                editableMaxInvitados
                    ? Colors.purpleAccent.withValues(alpha: 0.16)
                    : Colors.white10,
                textColor:
                    editableMaxInvitados ? Colors.purpleAccent : Colors.white60,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _guardando ? null : () => _editarSegmento(item),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _guardando ? null : () => _eliminarSegmento(item),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Center(
        child: CircularProgressIndicator(color: BioConfig.colorPrimario),
      );
    }

    final activos = _segmentos.where((item) => item['activo'] != false).length;
    final conInvitaciones =
        _segmentos.where((item) => item['can_invite'] == true).length;

    return RefreshIndicator(
      color: BioConfig.colorPrimario,
      onRefresh: () => _cargar(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        children: [
          _panelCard(
            color: Colors.cyanAccent,
            icon: Icons.qr_code_2_outlined,
            title: 'Códigos Macro',
            description:
                'Administra segmentos por prefijo y guarda la configuración remota en configuracion/segmentos_macro usando MacroSegmentoConfig.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PantallaAdminState._chip(
                      '${_segmentos.length} segmentos',
                      Colors.cyanAccent.withValues(alpha: 0.16),
                      textColor: Colors.cyanAccent,
                    ),
                    _PantallaAdminState._chip(
                      '$activos activos',
                      Colors.greenAccent.withValues(alpha: 0.16),
                      textColor: Colors.greenAccent,
                    ),
                    _PantallaAdminState._chip(
                      '$conInvitaciones con invitaciones',
                      Colors.lightBlueAccent.withValues(alpha: 0.16),
                      textColor: Colors.lightBlueAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'La coincidencia se resuelve por prefijo. Al guardar, MacroSegmentoConfig ordena primero los prefijos más largos para priorizar el match más específico.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _guardando ? null : _crearSegmento,
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: Text(
                        _guardando ? 'Guardando...' : 'Nuevo segmento macro',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _guardando ? null : () => _cargar(force: true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Recargar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_segmentos.isEmpty)
            SizedBox(
              height: 320,
              child: _PantallaAdminState._emptyState(
                Icons.qr_code_2_outlined,
                'Sin segmentos macro',
                'Crea el primer prefijo para empezar a clasificar códigos.',
              ),
            )
          else
            ..._segmentos.map(_buildSegmentoCard),
        ],
      ),
    );
  }
}

class _TabPlanesSuscripcion extends StatefulWidget {
  const _TabPlanesSuscripcion();
  @override
  State<_TabPlanesSuscripcion> createState() => _TabPlanesSuscripcionState();
}

class _TabPlanesSuscripcionState extends State<_TabPlanesSuscripcion> {
  Map<String, int> _precios = Map.from(BioConfig.planesDefecto);
  bool _cargando = true;
  bool _guardando = false;
  final TextEditingController _urlActualizadorCtrl = TextEditingController();
  final TextEditingController _urlEdmarkCtrl = TextEditingController();
  final TextEditingController _valorTokenCtrl =
      TextEditingController(text: '100');

  final Map<String, TextEditingController> _ctrls = {
    '15d': TextEditingController(),
    '1m': TextEditingController(),
    '6m': TextEditingController(),
    '1a': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _urlActualizadorCtrl.dispose();
    _urlEdmarkCtrl.dispose();
    _valorTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    var precios = Map<String, int>.from(BioConfig.planesDefecto);
    var urlActualizador = AppUpdateConfig.currentApkUrl;
    var urlEdmark = EdMarkConfig.currentBaseUrl ?? '';
    var valorTokenCop = 100;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection(BioConfig.colConfiguracion)
            .doc(BioConfig.docPlanesSuscripcion)
            .get(),
        FirebaseFirestore.instance
            .collection(BioConfig.colConfiguracion)
            .doc(BioConfig.docApp)
            .get(),
      ]);
      final planesDoc = results[0];
      final appDoc = results[1];
      if (planesDoc.exists && planesDoc.data() != null) {
        final d = planesDoc.data()!;
        precios = {
          '15d': (d['plan_15d'] as num?)?.toInt() ??
              BioConfig.planesDefecto['15d']!,
          '1m':
              (d['plan_1m'] as num?)?.toInt() ?? BioConfig.planesDefecto['1m']!,
          '6m':
              (d['plan_6m'] as num?)?.toInt() ?? BioConfig.planesDefecto['6m']!,
          '1a':
              (d['plan_1a'] as num?)?.toInt() ?? BioConfig.planesDefecto['1a']!,
        };
      }
      if (appDoc.exists && appDoc.data() != null) {
        final d = appDoc.data()!;
        urlActualizador = AppUpdateConfig.resolve(
          d[BioConfig.campoUrlActualizadorApk]?.toString(),
        );
        urlEdmark =
            EdMarkConfig.resolve(d[BioConfig.campoUrlEdmark]?.toString()) ?? '';
        valorTokenCop =
            BioConfig.toInt(d[BioConfig.campoValorTokenCop], valorTokenCop);
        AppUpdateConfig.setCachedUrl(urlActualizador);
        EdMarkConfig.setCachedUrl(urlEdmark);
      }
    } catch (e) {
      debugPrint('[Planes] Error cargando: $e');
    }
    _precios = precios;
    for (final e in _precios.entries) {
      _ctrls[e.key]!.text = e.value.toString();
    }
    _urlActualizadorCtrl.text = urlActualizador;
    _urlEdmarkCtrl.text = urlEdmark;
    _valorTokenCtrl.text = valorTokenCop.toString();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final nuevos = <String, dynamic>{};
      for (final e in _ctrls.entries) {
        final v = int.tryParse(e.value.text.trim());
        if (v == null || v <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade900,
              content:
                  Text('Valor invalido para ${BioConfig.planesNombre[e.key]}'),
            ),
          );
          setState(() => _guardando = false);
          return;
        }
        nuevos['plan_${e.key}'] = v;
      }
      final urlActualizador =
          AppUpdateConfig.normalizeUrl(_urlActualizadorCtrl.text.trim());
      if (urlActualizador == null || urlActualizador.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: const Text('URL del actualizador invalida'),
          ),
        );
        setState(() => _guardando = false);
        return;
      }
      final rawEdmark = _urlEdmarkCtrl.text.trim();
      final urlEdmark = EdMarkConfig.normalizeBaseUrl(rawEdmark);
      if (rawEdmark.isNotEmpty && (urlEdmark == null || urlEdmark.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: const Text('URL de EdMark invalida'),
          ),
        );
        setState(() => _guardando = false);
        return;
      }
      final valorTokenCop = int.tryParse(_valorTokenCtrl.text.trim());
      if (valorTokenCop == null || valorTokenCop <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: const Text('Valor del token invalido'),
          ),
        );
        setState(() => _guardando = false);
        return;
      }

      await Future.wait([
        FirebaseFirestore.instance
            .collection(BioConfig.colConfiguracion)
            .doc(BioConfig.docPlanesSuscripcion)
            .set(nuevos, SetOptions(merge: true)),
        FirebaseFirestore.instance
            .collection(BioConfig.colConfiguracion)
            .doc(BioConfig.docApp)
            .set({
          BioConfig.campoUrlActualizadorApk: urlActualizador,
          BioConfig.campoUrlEdmark: urlEdmark ?? '',
          BioConfig.campoValorTokenCop: valorTokenCop,
        }, SetOptions(merge: true)),
      ]);
      AppUpdateConfig.setCachedUrl(urlActualizador);
      EdMarkConfig.setCachedUrl(urlEdmark);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Configuracion remota actualizada'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _guardando = false);
  }

  Widget _configCard({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planes de Suscripcion',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Edita los planes, el valor del token y las URLs remotas sin recompilar la app.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          ...BioConfig.planesNombre.entries.map((e) {
            final clave = e.key;
            final nombre = e.value;
            final dias = BioConfig.planesDias[clave]!;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.tealAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.all_inclusive,
                      color: Colors.tealAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$dias dias de acceso ilimitado',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _ctrls[clave],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: const TextStyle(color: Colors.white24),
                        suffixText: 'tkn',
                        suffixStyle: const TextStyle(
                            color: Colors.tealAccent, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          _configCard(
            color: Colors.orangeAccent,
            icon: Icons.toll,
            title: 'Valor del token',
            description:
                'Controla cuantos COP representa 1 token dentro de la app.',
            child: SizedBox(
              width: 160,
              child: TextField(
                controller: _valorTokenCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  hintText: '100',
                  hintStyle: const TextStyle(color: Colors.white24),
                  suffixText: 'COP',
                  suffixStyle: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _configCard(
            color: Colors.lightBlueAccent,
            icon: Icons.cloud_upload_outlined,
            title: 'Servidor EdMark',
            description:
                'Marketing usara esta URL para subir banners sin tocar Alembique.',
            child: TextField(
              controller: _urlEdmarkCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Base URL de EdMark',
                hintText:
                    'https://edmark.tu-dominio.com o http://192.168.1.5:5051',
                labelStyle: const TextStyle(color: Colors.white54),
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _configCard(
            color: Colors.cyanAccent,
            icon: Icons.system_update_alt,
            title: 'URL del actualizador APK',
            description:
                'Acepta link directo o una URL normalizable. La app la usa sin recompilar.',
            child: TextField(
              controller: _urlActualizadorCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://.../app-release.apk',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                _guardando ? 'Guardando...' : 'Guardar configuracion',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoTecnicoData {
  final String packageName;
  final String localVersion;
  final String fullVersion;
  final String updaterUrl;
  final String updaterSource;
  final String edmarkUrl;
  final int valorTokenCop;
  final VersionInfo? remoteVersion;
  final VersionDelta versionDelta;
  final String? configError;
  final _ResumenRecetasTecnico recetas;
  final _EventosSeguridadTecnico eventos;

  const _EstadoTecnicoData({
    required this.packageName,
    required this.localVersion,
    required this.fullVersion,
    required this.updaterUrl,
    required this.updaterSource,
    required this.edmarkUrl,
    required this.valorTokenCop,
    required this.remoteVersion,
    required this.versionDelta,
    required this.configError,
    required this.recetas,
    required this.eventos,
  });
}

class _ResumenRecetasTecnico {
  final int vencidas;
  final int atascadas;
  final int sinPs;
  final int accesosRevisados;
  final int solicitudesRevisadas;
  final String? error;

  const _ResumenRecetasTecnico({
    required this.vencidas,
    required this.atascadas,
    required this.sinPs,
    required this.accesosRevisados,
    required this.solicitudesRevisadas,
    required this.error,
  });
}

class _EventosSeguridadTecnico {
  final List<_EventoSeguridadTecnico> items;
  final String? fuente;
  final String? error;

  const _EventosSeguridadTecnico({
    required this.items,
    required this.fuente,
    required this.error,
  });
}

class _EventoSeguridadTecnico {
  final String titulo;
  final String detalle;
  final String tipo;
  final DateTime? fecha;

  const _EventoSeguridadTecnico({
    required this.titulo,
    required this.detalle,
    required this.tipo,
    required this.fecha,
  });
}

class _TabEstadoTecnico extends StatefulWidget {
  const _TabEstadoTecnico();

  @override
  State<_TabEstadoTecnico> createState() => _TabEstadoTecnicoState();
}

class _TabEstadoTecnicoState extends State<_TabEstadoTecnico> {
  late Future<_EstadoTecnicoData> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarEstado();
  }

  void _recargar() {
    setState(() => _future = _cargarEstado());
  }

  Future<_EstadoTecnicoData> _cargarEstado() async {
    final packageFuture = PackageInfo.fromPlatform();
    final appDocFuture = FirebaseFirestore.instance
        .collection(BioConfig.colConfiguracion)
        .doc(BioConfig.docApp)
        .get();
    final versionFuture = VersionManager.check(BioConfig.version);
    final recetasFuture = _cargarResumenRecetas();
    final eventosFuture = _cargarEventosSeguridad();

    var packageName = 'BioFreq';
    try {
      final info = await packageFuture;
      packageName = info.packageName;
    } catch (_) {}

    var updaterUrl = AppUpdateConfig.currentApkUrl;
    var updaterSource = 'Fallback local';
    var edmarkUrl = EdMarkConfig.currentBaseUrl ?? '';
    var valorTokenCop = 100;
    String? configError;

    try {
      final appDoc = await appDocFuture;
      final data = appDoc.data() ?? <String, dynamic>{};
      final rawUpdater =
          data[BioConfig.campoUrlActualizadorApk]?.toString().trim() ?? '';
      final rawEdmark = data[BioConfig.campoUrlEdmark]?.toString().trim() ?? '';

      updaterUrl = AppUpdateConfig.resolve(rawUpdater);
      updaterSource = rawUpdater.isEmpty ? 'Fallback local' : 'Firestore';
      edmarkUrl = EdMarkConfig.resolve(rawEdmark) ?? '';
      valorTokenCop =
          BioConfig.toInt(data[BioConfig.campoValorTokenCop], valorTokenCop);
      if (!appDoc.exists) {
        configError =
            'No existe configuracion/app; se muestran valores en memoria.';
      }
    } catch (e) {
      configError =
          'No se pudo leer configuracion/app: ${_mensajeFirestore(e)}';
    }

    VersionInfo? remoteVersion;
    var versionDelta = VersionDelta.upToDate;
    try {
      final result = await versionFuture;
      remoteVersion = result.remote;
      versionDelta = result.delta;
    } catch (_) {}

    return _EstadoTecnicoData(
      packageName: packageName,
      localVersion: BioConfig.versionDisplay,
      fullVersion: BioConfig.version,
      updaterUrl: updaterUrl,
      updaterSource: updaterSource,
      edmarkUrl: edmarkUrl,
      valorTokenCop: valorTokenCop,
      remoteVersion: remoteVersion,
      versionDelta: versionDelta,
      configError: configError,
      recetas: await recetasFuture,
      eventos: await eventosFuture,
    );
  }

  Future<_ResumenRecetasTecnico> _cargarResumenRecetas() async {
    final now = DateTime.now();
    var vencidas = 0;
    var atascadas = 0;
    var sinPs = 0;
    var accesosRevisados = 0;
    var solicitudesRevisadas = 0;
    final errores = <String>[];

    try {
      final accesosSnap = await FirebaseFirestore.instance
          .collectionGroup(BioConfig.colAccesosSonidos)
          .where('aprobado', isEqualTo: true)
          .limit(350)
          .get();
      accesosRevisados = accesosSnap.docs.length;

      for (final doc in accesosSnap.docs) {
        final data = doc.data();
        final tratamientoActivo = data['tratamiento_activo'] == true;
        final tokensPagados = data['tokens_pagados'] == true;
        final inicio = _fecha(data['fecha_inicio']) ??
            _fecha(data['fecha_prescripcion']) ??
            _fecha(data['fecha_aprobacion']);
        final diasTratamiento = BioConfig.toInt(data['dias_tratamiento']);

        if (_txt(data['medico_id']).isEmpty) sinPs++;

        if (tratamientoActivo &&
            tokensPagados &&
            inicio != null &&
            diasTratamiento > 0 &&
            now.isAfter(inicio.add(Duration(days: diasTratamiento)))) {
          vencidas++;
        }

        final sesionesHoy = BioConfig.toInt(data['sesiones_hoy']);
        final proximoCiclo = _fecha(data['fecha_proximo_ciclo']);
        final minutosEntre = BioConfig.toInt(data['minutos_entre_ciclos']);
        final proximoVencido =
            proximoCiclo != null && now.difference(proximoCiclo).inMinutes > 5;
        final sinProximoCiclo = proximoCiclo == null && minutosEntre > 0;
        if (tratamientoActivo &&
            tokensPagados &&
            sesionesHoy <= 0 &&
            (proximoVencido || sinProximoCiclo)) {
          atascadas++;
        }
      }
    } catch (e) {
      errores.add('Accesos: ${_mensajeFirestore(e)}');
    }

    try {
      final solicitudesSnap = await FirebaseFirestore.instance
          .collection(BioConfig.colSolicitudesPrescripcion)
          .where('estado', isEqualTo: 'pendiente')
          .limit(350)
          .get();
      solicitudesRevisadas = solicitudesSnap.docs.length;

      for (final doc in solicitudesSnap.docs) {
        final data = doc.data();
        if (_txt(data['medico_id']).isEmpty) sinPs++;
        final fechaSolicitud =
            _fecha(data['fecha_solicitud']) ?? _fecha(data['fecha']);
        if (fechaSolicitud != null &&
            now.difference(fechaSolicitud).inHours >= 48) {
          atascadas++;
        }
      }
    } catch (e) {
      errores.add('Solicitudes: ${_mensajeFirestore(e)}');
    }

    return _ResumenRecetasTecnico(
      vencidas: vencidas,
      atascadas: atascadas,
      sinPs: sinPs,
      accesosRevisados: accesosRevisados,
      solicitudesRevisadas: solicitudesRevisadas,
      error: errores.isEmpty ? null : errores.join(' | '),
    );
  }

  Future<_EventosSeguridadTecnico> _cargarEventosSeguridad() async {
    const colecciones = [
      'eventos_seguridad',
      'security_events',
      'auditoria_seguridad',
      'logs_seguridad',
    ];
    const camposFecha = [
      'creado_en',
      'created_at',
      'fecha',
      'timestamp',
      'createdAt',
    ];
    String? ultimoError;

    for (final coleccion in colecciones) {
      for (final campoFecha in camposFecha) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection(coleccion)
              .orderBy(campoFecha, descending: true)
              .limit(5)
              .get();
          if (snap.docs.isEmpty) continue;
          return _EventosSeguridadTecnico(
            fuente: coleccion,
            error: null,
            items: snap.docs.map((doc) {
              final data = doc.data();
              return _EventoSeguridadTecnico(
                titulo: _primero(
                    data,
                    const [
                      'titulo',
                      'title',
                      'evento',
                      'event',
                      'accion',
                      'action'
                    ],
                    doc.id),
                detalle: _primero(data, const [
                  'detalle',
                  'descripcion',
                  'description',
                  'mensaje',
                  'message',
                  'uid',
                  'usuario_id'
                ]),
                tipo: _primero(data, const ['tipo', 'type', 'nivel', 'level']),
                fecha: _fecha(data[campoFecha]),
              );
            }).toList(),
          );
        } catch (e) {
          ultimoError = _mensajeFirestore(e);
          break;
        }
      }
    }

    return _EventosSeguridadTecnico(
      items: const [],
      fuente: null,
      error: ultimoError,
    );
  }

  static String _txt(dynamic value) => value?.toString().trim() ?? '';

  static String _primero(
    Map<String, dynamic> data,
    List<String> keys, [
    String fallback = '',
  ]) {
    for (final key in keys) {
      final value = _txt(data[key]);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static DateTime? _fecha(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.tryParse(value.toString());
  }

  static String _mensajeFirestore(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'sin permisos para leer esa ruta';
        case 'failed-precondition':
          return 'Firestore requiere un indice para esa consulta';
        case 'unavailable':
          return 'Firestore no esta disponible temporalmente';
        default:
          return '${error.code}: ${error.message ?? error.toString()}';
      }
    }
    return error.toString();
  }

  static String _fechaCorta(DateTime fecha) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${fecha.year}-${two(fecha.month)}-${two(fecha.day)} '
        '${two(fecha.hour)}:${two(fecha.minute)}';
  }

  static String _deltaLabel(VersionDelta delta) {
    switch (delta) {
      case VersionDelta.major:
        return 'Actualización mayor';
      case VersionDelta.minor:
        return 'Actualización disponible';
      case VersionDelta.patch:
        return 'Patch disponible';
      case VersionDelta.upToDate:
        return 'Al día';
    }
  }

  static Color _deltaColor(VersionDelta delta) {
    switch (delta) {
      case VersionDelta.major:
        return Colors.redAccent;
      case VersionDelta.minor:
      case VersionDelta.patch:
        return Colors.orangeAccent;
      case VersionDelta.upToDate:
        return Colors.greenAccent;
    }
  }

  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _kv(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'No configurado' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _notice(IconData icon, String title, String body, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _metricCard({
    required String label,
    required int value,
    required String detail,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            height: 1.3,
          ),
        ),
      ]),
    );
  }

  Widget _metricGrid(_ResumenRecetasTecnico recetas) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720
          ? 3
          : constraints.maxWidth >= 430
              ? 2
              : 1;
      final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: width,
          child: _metricCard(
            label: 'Vencidas',
            value: recetas.vencidas,
            detail: 'Activas fuera de dias_tratamiento.',
            icon: Icons.timer_off_outlined,
            color: Colors.orangeAccent,
          ),
        ),
        SizedBox(
          width: width,
          child: _metricCard(
            label: 'Atascadas',
            value: recetas.atascadas,
            detail: 'Pendientes >48h o ciclo vencido.',
            icon: Icons.report_problem_outlined,
            color: Colors.redAccent,
          ),
        ),
        SizedBox(
          width: width,
          child: _metricCard(
            label: 'Sin PS',
            value: recetas.sinPs,
            detail: 'Solicitudes/accesos sin medico_id.',
            icon: Icons.person_off_outlined,
            color: Colors.lightBlueAccent,
          ),
        ),
      ]);
    });
  }

  Widget _eventosList(_EventosSeguridadTecnico eventos) {
    if (eventos.items.isEmpty) {
      return _notice(
        Icons.verified_user_outlined,
        'Sin eventos visibles',
        eventos.error == null
            ? 'No se encontraron eventos recientes de seguridad.'
            : 'No se pudieron leer eventos: ${eventos.error}',
        eventos.error == null ? Colors.greenAccent : Colors.orangeAccent,
      );
    }

    return Column(
      children: eventos.items.map((event) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined,
                color: Colors.cyanAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event.detalle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.detalle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _PantallaAdminState._chip(
                      event.fecha == null
                          ? 'Sin fecha'
                          : _fechaCorta(event.fecha!),
                      Colors.white10,
                    ),
                    if (event.tipo.isNotEmpty)
                      _PantallaAdminState._chip(
                        event.tipo,
                        Colors.cyanAccent.withValues(alpha: 0.12),
                        textColor: Colors.cyanAccent,
                      ),
                  ]),
                ],
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EstadoTecnicoData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: _notice(
              Icons.error_outline,
              'No se pudo cargar Estado Técnico',
              snap.error.toString(),
              Colors.redAccent,
            ),
          );
        }

        final data = snap.data!;
        final deltaColor = _deltaColor(data.versionDelta);
        return RefreshIndicator(
          color: BioConfig.colorPrimario,
          onRefresh: () async => _recargar(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado Técnico',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Lectura rápida de versión, servicios remotos, seguridad y recetas.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Recargar'),
                ),
              ]),
              const SizedBox(height: 18),
              _sectionCard(
                icon: Icons.memory_outlined,
                color: Colors.cyanAccent,
                title: 'Versión y servicios',
                subtitle:
                    'Configuración remota leída desde Firestore cuando está disponible.',
                child: Column(children: [
                  _kv('Paquete', data.packageName),
                  const SizedBox(height: 8),
                  _kv('Versión local', data.fullVersion,
                      valueColor: Colors.cyanAccent),
                  const SizedBox(height: 8),
                  _kv(
                    'Versión remota',
                    data.remoteVersion?.raw ?? 'No disponible',
                    valueColor: deltaColor,
                  ),
                  const SizedBox(height: 8),
                  _kv('Estado versión', _deltaLabel(data.versionDelta),
                      valueColor: deltaColor),
                  const SizedBox(height: 8),
                  _kv('Updater', data.updaterUrl,
                      valueColor: Colors.orangeAccent),
                  const SizedBox(height: 8),
                  _kv('Origen updater', data.updaterSource),
                  const SizedBox(height: 8),
                  _kv('EdMark', data.edmarkUrl,
                      valueColor: data.edmarkUrl.isEmpty
                          ? Colors.white38
                          : Colors.lightBlueAccent),
                  const SizedBox(height: 8),
                  _kv('Token COP', '${data.valorTokenCop} COP'),
                  if (data.configError != null) ...[
                    const SizedBox(height: 12),
                    _notice(
                      Icons.info_outline,
                      'Configuración parcial',
                      data.configError!,
                      Colors.orangeAccent,
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.medical_information_outlined,
                color: Colors.tealAccent,
                title: 'Recetas',
                subtitle:
                    'Conteo defensivo: revisa hasta 350 accesos y 350 solicitudes pendientes.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _metricGrid(data.recetas),
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _PantallaAdminState._chip(
                        '${data.recetas.accesosRevisados} accesos revisados',
                        Colors.white10,
                      ),
                      _PantallaAdminState._chip(
                        '${data.recetas.solicitudesRevisadas} solicitudes revisadas',
                        Colors.white10,
                      ),
                    ]),
                    if (data.recetas.error != null) ...[
                      const SizedBox(height: 12),
                      _notice(
                        Icons.info_outline,
                        'Lectura parcial',
                        data.recetas.error!,
                        Colors.orangeAccent,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.security_outlined,
                color: Colors.lightBlueAccent,
                title: 'Últimos eventos de seguridad',
                subtitle: data.eventos.fuente == null
                    ? 'Busca colecciones comunes si existen.'
                    : 'Fuente: ${data.eventos.fuente}',
                child: _eventosList(data.eventos),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Admin: Recetas — solicitudes de acceso a sonidos pendientes de aprobación
// ─────────────────────────────────────────────────────────────────────────────
class _TabCodigosMacro extends StatefulWidget {
  const _TabCodigosMacro();

  @override
  State<_TabCodigosMacro> createState() => _TabCodigosMacroState();
}

class _TabCodigosMacroState extends State<_TabCodigosMacro> {
  Future<void> _guardarLista(List<Map<String, dynamic>> segmentos) async {
    await MacroSegmentoConfig.saveAll(segmentos);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuracion macro guardada')),
    );
  }

  Future<void> _editarSegmento({
    Map<String, dynamic>? segmento,
    required List<Map<String, dynamic>> actuales,
  }) async {
    final nombreCtrl =
        TextEditingController(text: (segmento?['nombre'] ?? '').toString());
    final descripcionCtrl = TextEditingController(
      text: (segmento?['descripcion'] ?? '').toString(),
    );
    final prefijoCtrl = TextEditingController(
      text: (segmento?['prefijo_codigo'] ?? '').toString(),
    );
    final valorTokenCtrl = TextEditingController(
      text: BioConfig.toInt(segmento?['valor_token_cop']) > 0
          ? BioConfig.toInt(segmento?['valor_token_cop']).toString()
          : '',
    );
    final maxInvitadosCtrl = TextEditingController(
      text: BioConfig.toInt(segmento?[BioConfig.campoMaxInvitados]) > 0
          ? BioConfig.toInt(segmento?[BioConfig.campoMaxInvitados]).toString()
          : '',
    );

    bool activo = segmento?['activo'] != false;
    bool canInvite = segmento?['can_invite'] == true;
    bool editableValorToken = segmento?['editable_valor_token'] == true;
    bool editableCanInvite = segmento?['editable_can_invite'] == true;
    bool editableMaxInvitados = segmento?['editable_max_invitados'] == true;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            segmento == null ? 'Nuevo codigo macro' : 'Editar codigo macro',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _PantallaAdminState._deco('Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descripcionCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: _PantallaAdminState._deco('Descripcion'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: prefijoCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _PantallaAdminState._deco(
                      'Codigo / prefijo',
                      hint: 'Ej: Roche-',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 460;
                      final tokenField = TextField(
                        controller: valorTokenCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _PantallaAdminState._deco(
                          'Valor token (COP)',
                        ),
                      );
                      final maxField = TextField(
                        controller: maxInvitadosCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _PantallaAdminState._deco(
                          'Numero maximo de invitados',
                          hint: 'Vacio = sin limite',
                        ),
                      );
                      if (compact) {
                        return Column(
                          children: [
                            tokenField,
                            const SizedBox(height: 10),
                            maxField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: tokenField),
                          const SizedBox(width: 10),
                          Expanded(child: maxField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    value: activo,
                    onChanged: (v) => setDialog(() => activo = v),
                    title: const Text(
                      'Segmento activo',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeColor: BioConfig.colorPrimario,
                  ),
                  SwitchListTile.adaptive(
                    value: canInvite,
                    onChanged: (v) => setDialog(() => canInvite = v),
                    title: const Text(
                      'Permitir invitaciones',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeColor: BioConfig.colorPrimario,
                  ),
                  const Divider(color: Colors.white12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Campos que el segmento podra modificar',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: editableValorToken,
                    onChanged: (v) => setDialog(() => editableValorToken = v),
                    title: const Text(
                      'Permitir editar valor del token',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeColor: BioConfig.colorPrimario,
                  ),
                  SwitchListTile.adaptive(
                    value: editableCanInvite,
                    onChanged: (v) => setDialog(() => editableCanInvite = v),
                    title: const Text(
                      'Permitir editar capacidad de invitar',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeColor: BioConfig.colorPrimario,
                  ),
                  SwitchListTile.adaptive(
                    value: editableMaxInvitados,
                    onChanged: (v) => setDialog(() => editableMaxInvitados = v),
                    title: const Text(
                      'Permitir editar el numero maximo de invitados',
                      style: TextStyle(color: Colors.white),
                    ),
                    activeColor: BioConfig.colorPrimario,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BioConfig.colorPrimario,
                foregroundColor: Colors.black,
              ),
              onPressed: guardando
                  ? null
                  : () async {
                      final prefijo = MacroSegmentoConfig.normalizarPrefijo(
                          prefijoCtrl.text);
                      if (prefijo.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Debes indicar un prefijo de codigo valido.',
                            ),
                          ),
                        );
                        return;
                      }

                      final actualId =
                          (segmento?['id'] ?? '').toString().trim();
                      final duplicado = actuales.any((seg) {
                        final id = (seg['id'] ?? '').toString().trim();
                        if (actualId.isNotEmpty && id == actualId) return false;
                        return MacroSegmentoConfig.normalizarPrefijo(
                              (seg['prefijo_codigo'] ?? '').toString(),
                            ) ==
                            prefijo;
                      });
                      if (duplicado) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ya existe otro segmento con ese prefijo.',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialog(() => guardando = true);
                      final nuevo = <String, dynamic>{
                        'id': actualId.isNotEmpty
                            ? actualId
                            : 'seg_${DateTime.now().millisecondsSinceEpoch}',
                        'nombre': nombreCtrl.text.trim(),
                        'descripcion': descripcionCtrl.text.trim(),
                        'prefijo_codigo': prefijo,
                        'activo': activo,
                        'valor_token_cop': BioConfig.toInt(
                          int.tryParse(valorTokenCtrl.text.trim()),
                        ),
                        'can_invite': canInvite,
                        BioConfig.campoMaxInvitados: BioConfig.toInt(
                          int.tryParse(maxInvitadosCtrl.text.trim()),
                        ),
                        'editable_valor_token': editableValorToken,
                        'editable_can_invite': editableCanInvite,
                        'editable_max_invitados': editableMaxInvitados,
                      };
                      final lista = actuales
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                      final index = lista.indexWhere(
                        (e) => (e['id'] ?? '').toString() == nuevo['id'],
                      );
                      if (index >= 0) {
                        lista[index] = nuevo;
                      } else {
                        lista.add(nuevo);
                      }
                      await _guardarLista(lista);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarSegmento(
    Map<String, dynamic> segmento,
    List<Map<String, dynamic>> actuales,
  ) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Eliminar segmento',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Se eliminara ${(segmento["nombre"] ?? segmento["prefijo_codigo"] ?? "este segmento").toString()}.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final id = (segmento['id'] ?? '').toString().trim();
    final nueva = actuales
        .where((seg) => (seg['id'] ?? '').toString().trim() != id)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    await _guardarLista(nueva);
  }

  Widget _chipEstado(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(BioConfig.colConfiguracion)
          .doc(BioConfig.docSegmentosMacro)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error cargando segmentos: ${snap.error}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final raw = (snap.data?.data() ?? <String, dynamic>{});
        final segmentos = ((raw['segmentos'] as List?) ?? const [])
            .map((e) => MacroSegmentoConfig.normalizarSegmento(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList()
          ..sort((a, b) {
            final pa = (a['prefijo_codigo'] ?? '').toString();
            final pb = (b['prefijo_codigo'] ?? '').toString();
            return pa.compareTo(pb);
          });

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final titleBlock = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Codigos Macro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Cada prefijo controla parametros heredados por los usuarios vinculados a ese codigo de referido.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
                final addButton = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BioConfig.colorPrimario,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => _editarSegmento(actuales: segmentos),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Nuevo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: addButton),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    addButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            if (segmentos.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Text(
                  'Todavia no hay segmentos macro. Crea uno con un prefijo como Roche- para aplicar precios o limites especiales.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              )
            else
              ...segmentos.map((segmento) {
                final nombre = (segmento['nombre'] ?? '').toString().trim();
                final descripcion =
                    (segmento['descripcion'] ?? '').toString().trim();
                final prefijo =
                    (segmento['prefijo_codigo'] ?? '').toString().trim();
                final valorToken = BioConfig.toInt(segmento['valor_token_cop']);
                final maxInv =
                    BioConfig.toInt(segmento[BioConfig.campoMaxInvitados]);
                final canInvite = segmento['can_invite'] == true;
                final activo = segmento['activo'] != false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: BioConfig.colorPrimario.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 420;
                          final titleInfo = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre.isEmpty ? prefijo : nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                prefijo,
                                style: TextStyle(
                                  color: BioConfig.colorPrimario,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                          final actions = Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: () => _editarSegmento(
                                  segmento: segmento,
                                  actuales: segmentos,
                                ),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white70,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () =>
                                    _eliminarSegmento(segmento, segmentos),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          );
                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                titleInfo,
                                const SizedBox(height: 8),
                                actions,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: titleInfo),
                              const SizedBox(width: 8),
                              actions,
                            ],
                          );
                        },
                      ),
                      if (descripcion.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          descripcion,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chipEstado(
                            activo ? 'Activo' : 'Inactivo',
                            activo ? Colors.greenAccent : Colors.orangeAccent,
                          ),
                          _chipEstado(
                            'Token: ${valorToken > 0 ? '$valorToken COP' : 'sin override'}',
                            Colors.orangeAccent,
                          ),
                          _chipEstado(
                            canInvite ? 'Invita' : 'No invita',
                            canInvite
                                ? Colors.lightBlueAccent
                                : Colors.redAccent,
                          ),
                          _chipEstado(
                            maxInv > 0
                                ? 'Max invitados: $maxInv'
                                : 'Sin limite',
                            Colors.purpleAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chipEstado(
                            segmento['editable_valor_token'] == true
                                ? 'Edita valor token'
                                : 'Valor token fijo',
                            Colors.cyanAccent,
                          ),
                          _chipEstado(
                            segmento['editable_can_invite'] == true
                                ? 'Edita invitaciones'
                                : 'Invitaciones fijas',
                            Colors.tealAccent,
                          ),
                          _chipEstado(
                            segmento['editable_max_invitados'] == true
                                ? 'Edita max invitados'
                                : 'Max fijo',
                            Colors.amberAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _TabRecetasPendientes extends StatelessWidget {
  const _TabRecetasPendientes();

  Future<void> _aprobar(BuildContext context, DocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    try {
      final medicoId = (d['medico_id'] ?? '').toString().trim().isNotEmpty
          ? d['medico_id']
          : FirebaseAuth.instance.currentUser?.uid;
      // Crear acceso en accesos_sonidos del paciente
      await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(d['paciente_id'] as String)
          .collection(BioConfig.colAccesosSonidos)
          .doc(d['sonido_id'] as String)
          .set({
        'sonido_id': d['sonido_id'],
        'sonido_nombre': d['sonido_nombre'] ?? d['nombre_sonido'],
        'paciente_id': d['paciente_id'],
        'paciente_nombre': d['paciente_nombre'],
        'aprobado': true,
        'tokens_pagados': false,
        'tratamiento_activo': false,
        'sesiones_por_ciclo': 1,
        'sesiones_hoy': 0,
        'sesiones_completadas': 0,
        'sesiones_saltadas': 0,
        'ciclos_aplicados': 0,
        'ciclos_completados': 0,
        'dias_tratamiento': 7,
        'minutos_entre_ciclos': 1440,
        'costo_total_tokens': 0,
        'medico_id': medicoId,
        'fecha_aprobacion': FieldValue.serverTimestamp(),
        'fecha_prescripcion': FieldValue.serverTimestamp(),
        'version_vista': 1,
      }, SetOptions(merge: true));

      // Marcar solicitud como aprobada
      await doc.reference.update({
        'estado': 'aprobado',
        'medico_id': medicoId,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.green,
          content: Text('✅ Acceso aprobado correctamente'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rechazar(BuildContext context, DocumentSnapshot doc) async {
    await doc.reference.update({'estado': 'rechazado'});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text('Solicitud rechazada'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(BioConfig.colSolicitudesPrescripcion)
          .where('estado', isEqualTo: 'pendiente')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent));
        }
        if (snap.data!.docs.isEmpty) {
          return const Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline, color: Colors.white24, size: 64),
              SizedBox(height: 16),
              Text('Sin solicitudes pendientes ✅',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            final doc = snap.data!.docs[i];
            final d = doc.data() as Map<String, dynamic>;
            return Card(
              color: const Color(0xFF1A1A1A),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: Colors.tealAccent.withValues(alpha: 0.3))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Encabezado: "José pidió X sonido al Dr. Pepper" ──
                      Text(
                        '${d['paciente_nombre'] ?? 'Un paciente'} solicita:',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d['sonido_nombre'] ?? d['sonido_id'] ?? '—',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      // PS responsable — nombre desde Firestore
                      FutureBuilder<DocumentSnapshot?>(
                        future: d['medico_id'] == null
                            ? null
                            : FirebaseFirestore.instance
                                .collection(BioConfig.colUsuarios)
                                .doc(d['medico_id'] as String)
                                .get(),
                        builder: (_, psSnap) {
                          final psData = psSnap.hasData && psSnap.data != null
                              ? psSnap.data!.data() as Map<String, dynamic>?
                              : null;
                          final psNombre = psData?['nombre'] ??
                              psData?['email'] ??
                              d['medico_id'] ??
                              '—';
                          return Row(children: [
                            const Icon(Icons.medical_services_outlined,
                                color: Colors.tealAccent, size: 14),
                            const SizedBox(width: 6),
                            Text('Para: $psNombre',
                                style: const TextStyle(
                                    color: Colors.tealAccent, fontSize: 12)),
                          ]);
                        },
                      ),
                      const SizedBox(height: 2),
                      // IDs técnicos en pequeño
                      Text(
                          '${d['paciente_id'] ?? ''} · ${d['sonido_id'] ?? ''}',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 9)),
                      const SizedBox(height: 12),
                      // Botones
                      Row(children: [
                        Expanded(
                            child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Aprobar',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _aprobar(ctx, doc),
                        )),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Rechazar',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () => _rechazar(ctx, doc),
                        )),
                      ]),
                    ]),
              ),
            );
          },
        );
      },
    );
  }
}
