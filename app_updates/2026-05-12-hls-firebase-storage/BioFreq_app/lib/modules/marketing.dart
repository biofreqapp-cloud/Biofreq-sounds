// ======================================================================
// BioFreq - Modulo: marketing
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

const int _kMaxJsonResponseBytesMarketing = 64 * 1024;

Map<String, dynamic> _decodeSmallJsonResponseMarketing(
  http.Response response,
  String label,
) {
  final bytes = response.bodyBytes;
  if (bytes.length > _kMaxJsonResponseBytesMarketing) {
    throw Exception('$label demasiado grande (${bytes.length} bytes)');
  }

  final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
  if (decoded is Map<String, dynamic>) return decoded;

  throw Exception('$label no devolvio un objeto JSON');
}

class _MarketingItemDraft {
  String tipo;
  String clave;
  String nombre;
  int precioPromocional;

  _MarketingItemDraft({
    required this.tipo,
    this.clave = '',
    this.nombre = '',
    this.precioPromocional = 0,
  });

  factory _MarketingItemDraft.empty() => _MarketingItemDraft(
        tipo: BioConfig.tipoCampanaPlan,
      );

  factory _MarketingItemDraft.fromMap(Map<String, dynamic> map) {
    return _MarketingItemDraft(
      tipo: (map['tipo'] ?? BioConfig.tipoCampanaPlan).toString(),
      clave: (map['clave'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      precioPromocional: BioConfig.toInt(map['precio_promocional']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'clave': clave.trim(),
      'nombre': nombre.trim(),
      'precio_promocional': precioPromocional,
    };
  }
}

class _MarketingUserScope {
  final Map<String, dynamic> userData;
  final String rol;
  final Map<String, dynamic>? segmentoMacro;

  const _MarketingUserScope({
    required this.userData,
    required this.rol,
    required this.segmentoMacro,
  });
}

String _marketingTxt(dynamic value) => (value ?? '').toString().trim();

Map<String, dynamic>? _segmentoMacroDesdeCampos(Map<String, dynamic> data) {
  final id = _marketingTxt(data['segmento_macro_id']);
  final nombre = _marketingTxt(data['segmento_macro_nombre']);
  final prefijo = MacroSegmentoConfig.normalizarPrefijo(
    _marketingTxt(data['segmento_macro_prefijo']),
  );
  if (id.isEmpty && nombre.isEmpty && prefijo.isEmpty) {
    return null;
  }
  return {
    'id': id,
    'nombre': nombre,
    'prefijo_codigo': prefijo,
  };
}

bool _campanaCoincideConSegmentoMacro(
  Map<String, dynamic> campanaData,
  Map<String, dynamic>? segmento,
) {
  if (segmento == null) return false;
  final campanaSegmento = _segmentoMacroDesdeCampos(campanaData);
  if (campanaSegmento == null) return false;

  final segmentoId = _marketingTxt(segmento['id']);
  final campanaId = _marketingTxt(campanaSegmento['id']);
  if (segmentoId.isNotEmpty &&
      campanaId.isNotEmpty &&
      segmentoId == campanaId) {
    return true;
  }

  final segmentoPrefijo = MacroSegmentoConfig.normalizarPrefijo(
    _marketingTxt(segmento['prefijo_codigo']),
  );
  final campanaPrefijo = MacroSegmentoConfig.normalizarPrefijo(
    _marketingTxt(campanaSegmento['prefijo_codigo']),
  );
  if (segmentoPrefijo.isNotEmpty &&
      campanaPrefijo.isNotEmpty &&
      segmentoPrefijo == campanaPrefijo) {
    return true;
  }

  final segmentoNombre = _marketingTxt(segmento['nombre']).toLowerCase();
  final campanaNombre = _marketingTxt(campanaSegmento['nombre']).toLowerCase();
  return segmentoNombre.isNotEmpty &&
      campanaNombre.isNotEmpty &&
      segmentoNombre == campanaNombre;
}

Future<_MarketingUserScope> _resolverMarketingUserScope({
  required User? user,
  required bool modoAdmin,
}) async {
  if (user == null) {
    return const _MarketingUserScope(
      userData: <String, dynamic>{},
      rol: BioConfig.rolUser,
      segmentoMacro: null,
    );
  }

  final userDoc = await FirebaseFirestore.instance
      .collection(BioConfig.colUsuarios)
      .doc(user.uid)
      .get();
  final userData = Map<String, dynamic>.from((userDoc.data() as Map?) ?? {});
  final rol = (userData['rol'] ?? BioConfig.rolUser).toString();
  final segmentoMacro = (!modoAdmin && rol != BioConfig.rolAdmin)
      ? await MacroSegmentoConfig.resolveForUserData(userData)
      : null;

  return _MarketingUserScope(
    userData: userData,
    rol: rol,
    segmentoMacro: segmentoMacro,
  );
}

Widget _buildTarjetaSegmentoMacro({
  required Map<String, dynamic> segmento,
  required String titulo,
  required String descripcion,
  EdgeInsetsGeometry margin = EdgeInsets.zero,
}) {
  final nombre = _marketingTxt(segmento['nombre']);
  final prefijo = MacroSegmentoConfig.normalizarPrefijo(
    _marketingTxt(segmento['prefijo_codigo']),
  );
  return Container(
    width: double.infinity,
    margin: margin,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BioConfig.colorPrimario.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: BioConfig.colorPrimario.withValues(alpha: 0.26),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BioConfig.colorPrimario.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.hub_outlined,
            color: BioConfig.colorPrimario,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: BioConfig.colorPrimario,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                nombre.isEmpty ? 'Segmento sin nombre' : nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (prefijo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Prefijo: $prefijo',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                descripcion,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PantallaMarketing extends StatelessWidget {
  final bool modoAdmin;

  const PantallaMarketing({
    super.key,
    this.modoAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      appBar: AppBar(
        backgroundColor: BioConfig.colorFondo,
        title: Text(
          modoAdmin ? 'Marketing Admin' : 'Marketing',
          style: TextStyle(
            color: BioConfig.colorPrimario,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _PanelCampanasMarketing(
        modoAdmin: modoAdmin,
        embebido: false,
      ),
    );
  }
}

class _TabMarketingAdmin extends StatelessWidget {
  const _TabMarketingAdmin();

  @override
  Widget build(BuildContext context) {
    return const _PanelCampanasMarketing(
      modoAdmin: true,
      embebido: true,
    );
  }
}

class _PanelCampanasMarketing extends StatefulWidget {
  final bool modoAdmin;
  final bool embebido;

  const _PanelCampanasMarketing({
    required this.modoAdmin,
    required this.embebido,
  });

  @override
  State<_PanelCampanasMarketing> createState() =>
      _PanelCampanasMarketingState();
}

class _PanelCampanasMarketingState extends State<_PanelCampanasMarketing> {
  Timer? _timer;
  DateTime _ahora = DateTime.now();
  late final Future<_MarketingUserScope> _userScopeFuture;

  @override
  void initState() {
    super.initState();
    _userScopeFuture = _resolverMarketingUserScope(
      user: FirebaseAuth.instance.currentUser,
      modoAdmin: widget.modoAdmin,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _ahora = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _colorEstado(String estado, {required bool vigente}) {
    switch (estado) {
      case BioConfig.estadoCampanaAprobada:
        return vigente ? Colors.greenAccent : Colors.orangeAccent;
      case BioConfig.estadoCampanaPendiente:
        return Colors.amberAccent;
      case BioConfig.estadoCampanaRechazada:
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  String _textoEstado(
    String estado, {
    required bool vigente,
    required bool expirada,
  }) {
    if (estado == BioConfig.estadoCampanaAprobada && expirada) {
      return 'Expirada';
    }
    if (estado == BioConfig.estadoCampanaAprobada && vigente) {
      return 'Activa';
    }
    switch (estado) {
      case BioConfig.estadoCampanaPendiente:
        return 'Pendiente';
      case BioConfig.estadoCampanaAprobada:
        return 'Aprobada';
      case BioConfig.estadoCampanaRechazada:
        return 'Rechazada';
      default:
        return 'Borrador';
    }
  }

  String _duracionCorta(Duration d) {
    final dias = d.inDays;
    final horas = d.inHours.remainder(24).toString().padLeft(2, '0');
    final minutos = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${dias.toString().padLeft(2, '0')}:$horas:$minutos:$segundos';
  }

  String _formatearRestante(DateTime? inicio, DateTime? fin) {
    if (inicio == null || fin == null) return 'Sin duracion definida';
    if (_ahora.isBefore(inicio)) {
      return 'Inicia en ${_duracionCorta(inicio.difference(_ahora))}';
    }
    if (_ahora.isAfter(fin)) return 'Finalizada';
    return _duracionCorta(fin.difference(_ahora));
  }

  Future<void> _abrirEditor({
    required BuildContext context,
    DocumentSnapshot? campana,
    required bool modoAdmin,
    bool soloLectura = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEditorCampanaMarketing(
          campana: campana,
          modoAdmin: modoAdmin,
          soloLectura: soloLectura,
        ),
      ),
    );
  }

  Future<void> _eliminarCampana(DocumentSnapshot campana) async {
    final confirmar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Eliminar campana',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Esta accion elimina la campana del panel. Solo hazlo si estas seguro.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmar) return;

    await FirebaseFirestore.instance
        .collection(BioConfig.colCampanasMarketing)
        .doc(campana.id)
        .delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Campana eliminada')),
    );
  }

  Future<void> _aprobarCampana(DocumentSnapshot campana) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection(BioConfig.colCampanasMarketing)
        .doc(campana.id)
        .set({
      'estado': BioConfig.estadoCampanaAprobada,
      'motivo_rechazo': '',
      'aprobada_en': FieldValue.serverTimestamp(),
      'aprobada_por_uid': user?.uid,
      'aprobada_por_nombre': user?.displayName ?? '',
      'actualizada_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Campana aprobada')),
    );
  }

  Future<void> _rechazarCampana(DocumentSnapshot campana) async {
    final motivoCtrl = TextEditingController();
    final confirmar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Rechazar campana',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: motivoCtrl,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Motivo del rechazo',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Rechazar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmar) return;

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection(BioConfig.colCampanasMarketing)
        .doc(campana.id)
        .set({
      'estado': BioConfig.estadoCampanaRechazada,
      'motivo_rechazo': motivoCtrl.text.trim(),
      'rechazada_en': FieldValue.serverTimestamp(),
      'rechazada_por_uid': user?.uid,
      'rechazada_por_nombre': user?.displayName ?? '',
      'actualizada_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Campana rechazada')),
    );
  }

  Widget _buildCardCampana(
    BuildContext context,
    DocumentSnapshot campana,
    String? uidActual,
  ) {
    final data =
        Map<String, dynamic>.from(campana.data() as Map<String, dynamic>);
    final estado =
        (data['estado'] ?? BioConfig.estadoCampanaBorrador).toString();
    final creadaPor = (data['creada_por_uid'] ?? '').toString();
    final esPropia = uidActual != null && creadaPor == uidActual;
    final inicio = BioConfig.toDateTime(data['fecha_inicio']);
    final fin = BioConfig.toDateTime(data['fecha_fin']);
    final vigente = estado == BioConfig.estadoCampanaAprobada &&
        inicio != null &&
        fin != null &&
        !_ahora.isBefore(inicio) &&
        !_ahora.isAfter(fin);
    final expirada = estado == BioConfig.estadoCampanaAprobada &&
        fin != null &&
        _ahora.isAfter(fin);
    final colorEstado = _colorEstado(estado, vigente: vigente);
    final textoEstado = _textoEstado(
      estado,
      vigente: vigente,
      expirada: expirada,
    );
    final imagenes = (data['imagenes'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        <String>[];
    final items = (data['items'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    final nombresItems = items
        .map((item) => (item['nombre'] ?? item['clave'] ?? '').toString())
        .where((nombre) => nombre.trim().isNotEmpty)
        .join(', ');
    final puedeEditar = widget.modoAdmin ||
        (esPropia && estado != BioConfig.estadoCampanaAprobada);
    final puedeEliminar = widget.modoAdmin ||
        (esPropia && estado != BioConfig.estadoCampanaAprobada);
    final puedeSolicitar = !widget.modoAdmin &&
        esPropia &&
        (estado == BioConfig.estadoCampanaBorrador ||
            estado == BioConfig.estadoCampanaRechazada);
    final puedeAprobar =
        widget.modoAdmin && estado == BioConfig.estadoCampanaPendiente;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorEstado.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['nombre'] ?? 'Campana sin nombre').toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dirigido a: ${(data['dirigido_a'] ?? 'Sin segmentacion').toString()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  textoEstado,
                  style: TextStyle(
                    color: colorEstado,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Duracion: ${_formatearRestante(inicio, fin)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              Text(
                'Impacto: ${BioConfig.toInt(data['impacto_estimado'])} usuarios',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          if (nombresItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Campos impactados: $nombresItems',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
            ),
          ],
          if (imagenes.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imagenes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imagenes[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: () => _abrirEditor(
                  context: context,
                  campana: campana,
                  modoAdmin: widget.modoAdmin,
                  soloLectura: true,
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver'),
              ),
              if (puedeEditar)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                  ),
                  onPressed: () => _abrirEditor(
                    context: context,
                    campana: campana,
                    modoAdmin: widget.modoAdmin,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              if (puedeEliminar)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: () => _eliminarCampana(campana),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                ),
            ],
          ),
          if (puedeSolicitar) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BioConfig.colorPrimario,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => FirebaseFirestore.instance
                    .collection(BioConfig.colCampanasMarketing)
                    .doc(campana.id)
                    .set({
                  'estado': BioConfig.estadoCampanaPendiente,
                  'motivo_rechazo': '',
                  'solicitud_aprobacion_en': FieldValue.serverTimestamp(),
                  'actualizada_en': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true)),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Solicitar aprobacion'),
              ),
            ),
          ],
          if (puedeAprobar) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => _aprobarCampana(campana),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Aprobar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _rechazarCampana(campana),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Rechazar'),
                ),
              ],
            ),
          ],
          if (estado == BioConfig.estadoCampanaRechazada &&
              (data['motivo_rechazo'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A1A),
                  title: const Text(
                    'Motivo del rechazo',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Text(
                    data['motivo_rechazo'].toString(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
              child: const Text(
                'Ver motivo del rechazo',
                style: TextStyle(
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Inicia sesion para administrar marketing.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return FutureBuilder<_MarketingUserScope>(
      future: _userScopeFuture,
      builder: (context, scopeSnap) {
        if (!scopeSnap.hasData) {
          return Center(
            child: CircularProgressIndicator(color: BioConfig.colorPrimario),
          );
        }
        final scope = scopeSnap.data!;
        final rolReal = scope.rol;
        final segmentoMacroActivo = scope.segmentoMacro;
        if (!widget.modoAdmin && !BioConfig.puedeGestionarMarketing(rolReal)) {
          return const Center(
            child: Text(
              'Tu rol actual no tiene acceso al panel de marketing.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(BioConfig.colCampanasMarketing)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Error cargando campanas: ${snap.error}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }
            if (!snap.hasData) {
              return Center(
                child:
                    CircularProgressIndicator(color: BioConfig.colorPrimario),
              );
            }

            final docs = snap.data!.docs.where((doc) {
              if (widget.modoAdmin || rolReal == BioConfig.rolAdmin) {
                return true;
              }
              final data =
                  Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
              final esPropia =
                  (data['creada_por_uid'] ?? '').toString() == user.uid;
              if (esPropia) return true;
              return _campanaCoincideConSegmentoMacro(
                data,
                segmentoMacroActivo,
              );
            }).toList()
              ..sort((a, b) {
                final da =
                    Map<String, dynamic>.from(a.data() as Map<String, dynamic>);
                final db =
                    Map<String, dynamic>.from(b.data() as Map<String, dynamic>);
                final ta = BioConfig.toDateTime(da['actualizada_en']) ??
                    BioConfig.toDateTime(da['creada_en']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final tb = BioConfig.toDateTime(db['actualizada_en']) ??
                    BioConfig.toDateTime(db['creada_en']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return tb.compareTo(ta);
              });

            final contenido = docs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.campaign_outlined,
                            color: Colors.white24,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.modoAdmin
                                ? 'Todavia no hay campanas para revisar.'
                                : segmentoMacroActivo == null
                                    ? 'Todavia no has creado campanas.'
                                    : 'Todavia no hay campanas propias ni de tu segmento.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BioConfig.colorPrimario,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => _abrirEditor(
                              context: context,
                              modoAdmin: widget.modoAdmin,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar campana'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: docs.length,
                    itemBuilder: (_, i) => _buildCardCampana(
                      context,
                      docs[i],
                      user.uid,
                    ),
                  );
            final tarjetaSegmento =
                !widget.modoAdmin && segmentoMacroActivo != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _buildTarjetaSegmentoMacro(
                          segmento: segmentoMacroActivo,
                          titulo: 'Segmento activo',
                          descripcion:
                              'Las campanas visibles y las nuevas se filtran con este macrosegmento.',
                        ),
                      )
                    : const SizedBox.shrink();

            if (widget.embebido) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 520;
                        final headerText = Text(
                          'Campanas en Firebase con aprobacion de Admin.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        );
                        final addButton = ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BioConfig.colorPrimario,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => _abrirEditor(
                            context: context,
                            modoAdmin: widget.modoAdmin,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Nueva'),
                        );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              headerText,
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: addButton,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: headerText),
                            const SizedBox(width: 12),
                            addButton,
                          ],
                        );
                      },
                    ),
                  ),
                  tarjetaSegmento,
                  Expanded(child: contenido),
                ],
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final headerText = Text(
                        widget.modoAdmin
                            ? 'Aprueba o rechaza promociones sin tocar la app en produccion.'
                            : 'Crea promociones, previsualizalas y envialas a aprobacion.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      );
                      final addButton = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BioConfig.colorPrimario,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _abrirEditor(
                          context: context,
                          modoAdmin: widget.modoAdmin,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar campana'),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            headerText,
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: addButton,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: headerText),
                          const SizedBox(width: 12),
                          addButton,
                        ],
                      );
                    },
                  ),
                ),
                tarjetaSegmento,
                Expanded(child: contenido),
              ],
            );
          },
        );
      },
    );
  }
}

class PantallaEditorCampanaMarketing extends StatefulWidget {
  final DocumentSnapshot? campana;
  final bool modoAdmin;
  final bool soloLectura;

  const PantallaEditorCampanaMarketing({
    super.key,
    this.campana,
    required this.modoAdmin,
    this.soloLectura = false,
  });

  @override
  State<PantallaEditorCampanaMarketing> createState() =>
      _PantallaEditorCampanaMarketingState();
}

class _PantallaEditorCampanaMarketingState
    extends State<PantallaEditorCampanaMarketing> {
  final _nombreCtrl = TextEditingController();
  final _dirigidoACtrl = TextEditingController();
  final _impactoCtrl = TextEditingController(text: '0');
  final _notasCtrl = TextEditingController();
  late final List<TextEditingController> _imagenCtrls;
  late final List<bool> _subiendoImagenes;
  final ImagePicker _picker = ImagePicker();

  final List<_MarketingItemDraft> _items = [];

  DateTime? _inicio;
  DateTime? _fin;
  bool _guardando = false;
  Map<String, dynamic>? _segmentoMacroActual;

  String get _estadoActual {
    if (widget.campana == null) return BioConfig.estadoCampanaBorrador;
    final data = Map<String, dynamic>.from(
      widget.campana!.data() as Map<String, dynamic>,
    );
    return (data['estado'] ?? BioConfig.estadoCampanaBorrador).toString();
  }

  bool get _soloLecturaEfectiva => widget.soloLectura;

  Map<String, dynamic> get _campanaDataActual {
    return Map<String, dynamic>.from((widget.campana?.data() as Map?) ?? {});
  }

  Map<String, dynamic>? get _segmentoMacroCampana {
    return _segmentoMacroDesdeCampos(_campanaDataActual);
  }

  @override
  void initState() {
    super.initState();
    _imagenCtrls = List.generate(3, (_) => TextEditingController());
    _subiendoImagenes = List.generate(3, (_) => false);
    _cargarInicial();
    _resolverSegmentoMacroActual();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirigidoACtrl.dispose();
    _impactoCtrl.dispose();
    _notasCtrl.dispose();
    for (final ctrl in _imagenCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _cargarInicial() {
    final data = widget.campana?.data();
    if (data == null) {
      _items.add(_MarketingItemDraft.empty());
      _inicio = DateTime.now();
      _fin = DateTime.now().add(const Duration(days: 7));
      return;
    }

    final map = Map<String, dynamic>.from(data as Map<String, dynamic>);
    _nombreCtrl.text = (map['nombre'] ?? '').toString();
    _dirigidoACtrl.text = (map['dirigido_a'] ?? '').toString();
    _impactoCtrl.text = BioConfig.toInt(map['impacto_estimado']).toString();
    _notasCtrl.text = (map['notas'] ?? '').toString();
    _inicio = BioConfig.toDateTime(map['fecha_inicio']);
    _fin = BioConfig.toDateTime(map['fecha_fin']);
    final imagenes =
        (map['imagenes'] as List?)?.map((e) => e.toString()).toList() ??
            <String>[];
    for (int i = 0; i < _imagenCtrls.length; i++) {
      _imagenCtrls[i].text = i < imagenes.length ? imagenes[i] : '';
    }
    final items = (map['items'] as List?)
            ?.map(
              (e) => _MarketingItemDraft.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        <_MarketingItemDraft>[];
    if (items.isEmpty) {
      _items.add(_MarketingItemDraft.empty());
    } else {
      _items.addAll(items);
    }
  }

  Future<void> _resolverSegmentoMacroActual() async {
    final scope = await _resolverMarketingUserScope(
      user: FirebaseAuth.instance.currentUser,
      modoAdmin: widget.modoAdmin,
    );
    if (!mounted) return;
    setState(() => _segmentoMacroActual = scope.segmentoMacro);
  }

  Future<DateTime?> _seleccionarFechaHora(DateTime? actual) async {
    final base = actual ?? DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: BioConfig.colorPrimario,
            surface: const Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (fecha == null) return null;
    if (!mounted) return null;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: BioConfig.colorPrimario,
            surface: const Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (hora == null) return null;
    return DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora.hour,
      hora.minute,
    );
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return 'Seleccionar';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $hh:$min';
  }

  InputDecoration _deco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white54),
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _nombreArchivoSeguro(XFile file, int index) {
    final candidate = file.name.trim();
    if (candidate.isNotEmpty) return candidate;
    final parts = file.path.split(Platform.pathSeparator);
    if (parts.isNotEmpty && parts.last.trim().isNotEmpty) {
      return parts.last.trim();
    }
    return 'banner_${index + 1}.png';
  }

  Future<void> _subirImagenConEdMark(int index) async {
    if (_soloLecturaEfectiva || index < 0 || index >= _imagenCtrls.length) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Inicia sesion para subir banners.');
      return;
    }

    final uploadUrl = EdMarkConfig.uploadBannerUrl(await EdMarkConfig.load());
    if (uploadUrl == null || uploadUrl.isEmpty) {
      _snack('Configura primero la URL de EdMark en el panel Admin.');
      return;
    }

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (file == null) return;

    if (mounted) {
      setState(() => _subiendoImagenes[index] = true);
    }

    try {
      final token = await user.getIdToken(true);
      final fileName = _nombreArchivoSeguro(file, index);
      final req = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['campaign_name'] = _nombreCtrl.text.trim().isEmpty
            ? 'campana_marketing'
            : _nombreCtrl.text.trim()
        ..fields['display_name'] = fileName
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: fileName,
          ),
        );

      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed);
      final body = response.bodyBytes.isEmpty
          ? <String, dynamic>{}
          : _decodeSmallJsonResponseMarketing(
              response,
              'EdMark upload response',
            );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['error'] ?? 'HTTP ${response.statusCode}');
      }

      final urlDirecta = (body['url_directa'] ?? '').toString().trim();
      if (urlDirecta.isEmpty) {
        throw Exception('EdMark no devolvio una URL directa valida.');
      }

      if (!mounted) return;
      setState(() => _imagenCtrls[index].text = urlDirecta);
      _snack('Banner subido y URL asignada a Imagen ${index + 1}.');
    } catch (e) {
      _snack('No se pudo subir la imagen: $e');
    } finally {
      if (mounted) {
        setState(() => _subiendoImagenes[index] = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _validarYConstruir({
    required String estadoDestino,
  }) async {
    if (_nombreCtrl.text.trim().isEmpty) {
      _snack('Ponle nombre a la campana');
      return null;
    }
    if (_dirigidoACtrl.text.trim().isEmpty) {
      _snack('Describe a quien va dirigida');
      return null;
    }
    if (_inicio == null || _fin == null || !_fin!.isAfter(_inicio!)) {
      _snack('Define una duracion valida para la campana');
      return null;
    }

    final itemsLimpios = _items
        .where((item) =>
            item.clave.trim().isNotEmpty &&
            item.nombre.trim().isNotEmpty &&
            item.precioPromocional > 0)
        .map((item) => item.toMap())
        .toList();
    if (itemsLimpios.isEmpty) {
      _snack('Agrega al menos un sonido o plan con precio promocional');
      return null;
    }

    final user = FirebaseAuth.instance.currentUser;
    final scope = await _resolverMarketingUserScope(
      user: user,
      modoAdmin: widget.modoAdmin,
    );
    final userData = scope.userData;
    final segmentoMacroPayload = scope.segmentoMacro ?? _segmentoMacroCampana;
    final estadoBase = widget.modoAdmin
        ? _estadoActual
        : (estadoDestino == BioConfig.estadoCampanaPendiente
            ? BioConfig.estadoCampanaPendiente
            : BioConfig.estadoCampanaBorrador);

    final payload = {
      'nombre': _nombreCtrl.text.trim(),
      'dirigido_a': _dirigidoACtrl.text.trim(),
      'impacto_estimado': int.tryParse(_impactoCtrl.text.trim()) ?? 0,
      'fecha_inicio': Timestamp.fromDate(_inicio!),
      'fecha_fin': Timestamp.fromDate(_fin!),
      'imagenes': _imagenCtrls
          .map((ctrl) => ctrl.text.trim())
          .where((url) => url.isNotEmpty)
          .toList(),
      'items': itemsLimpios,
      'notas': _notasCtrl.text.trim(),
      'estado': estadoBase,
      'creada_por_uid': widget.campana == null ? user?.uid : null,
      'creada_por_nombre': widget.campana == null
          ? (userData['nombre'] ?? user?.displayName ?? '')
          : null,
      'creada_por_rol': widget.campana == null
          ? (userData['rol'] ?? BioConfig.rolUser)
          : null,
      'creada_en': widget.campana == null ? FieldValue.serverTimestamp() : null,
      'solicitud_aprobacion_en':
          estadoDestino == BioConfig.estadoCampanaPendiente
              ? FieldValue.serverTimestamp()
              : null,
      'motivo_rechazo':
          estadoDestino == BioConfig.estadoCampanaPendiente ? '' : null,
      'actualizada_en': FieldValue.serverTimestamp(),
    };

    if (segmentoMacroPayload != null) {
      final segmentoId = _marketingTxt(segmentoMacroPayload['id']);
      final segmentoNombre = _marketingTxt(segmentoMacroPayload['nombre']);
      final segmentoPrefijo = MacroSegmentoConfig.normalizarPrefijo(
        _marketingTxt(segmentoMacroPayload['prefijo_codigo']),
      );
      if (segmentoId.isNotEmpty) {
        payload['segmento_macro_id'] = segmentoId;
      }
      if (segmentoNombre.isNotEmpty) {
        payload['segmento_macro_nombre'] = segmentoNombre;
      }
      if (segmentoPrefijo.isNotEmpty) {
        payload['segmento_macro_prefijo'] = segmentoPrefijo;
      }
    }

    return payload..removeWhere((_, value) => value == null);
  }

  Future<void> _guardar({required bool solicitarAprobacion}) async {
    if (_soloLecturaEfectiva) return;
    setState(() => _guardando = true);
    final payload = await _validarYConstruir(
      estadoDestino: solicitarAprobacion
          ? BioConfig.estadoCampanaPendiente
          : BioConfig.estadoCampanaBorrador,
    );
    if (payload == null) {
      if (mounted) setState(() => _guardando = false);
      return;
    }
    try {
      final ref = widget.campana == null
          ? FirebaseFirestore.instance
              .collection(BioConfig.colCampanasMarketing)
              .doc()
          : FirebaseFirestore.instance
              .collection(BioConfig.colCampanasMarketing)
              .doc(widget.campana!.id);
      await ref.set(payload, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            solicitarAprobacion
                ? 'Campana enviada a aprobacion'
                : 'Campana guardada',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      _snack('Error guardando campana: $e');
    }
    if (mounted) setState(() => _guardando = false);
  }

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  void _previsualizar() {
    final imagenes = _imagenCtrls
        .map((ctrl) => ctrl.text.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    final items = _items
        .where((item) =>
            item.clave.trim().isNotEmpty &&
            item.nombre.trim().isNotEmpty &&
            item.precioPromocional > 0)
        .toList();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          _nombreCtrl.text.trim().isEmpty
              ? 'Previsualizacion'
              : _nombreCtrl.text.trim(),
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dirigido a: ${_dirigidoACtrl.text.trim()}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  'Duracion: ${_fmtDateTime(_inicio)} -> ${_fmtDateTime(_fin)}',
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 12),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${item.nombre} · ${item.precioPromocional} tokens',
                      style: const TextStyle(color: Colors.amberAccent),
                    ),
                  ),
                ),
                if (imagenes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...imagenes.map(
                    (url) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: Colors.white10,
                            alignment: Alignment.center,
                            child: const Text(
                              'No se pudo cargar la imagen',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.tipo,
                  decoration: _deco('Tipo'),
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: BioConfig.tipoCampanaPlan,
                      child:
                          Text('Plan', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: BioConfig.tipoCampanaSonido,
                      child:
                          Text('Sonido', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: _soloLecturaEfectiva
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => item.tipo = value);
                        },
                ),
              ),
              const SizedBox(width: 10),
              if (!_soloLecturaEfectiva)
                IconButton(
                  onPressed: () => setState(() => _items.removeAt(index)),
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (item.tipo == BioConfig.tipoCampanaPlan)
            DropdownButtonFormField<String>(
              value: item.clave.isEmpty ? null : item.clave,
              decoration: _deco('Plan'),
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              items: BioConfig.planesNombre.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _soloLecturaEfectiva
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        item.clave = value;
                        item.nombre = BioConfig.planesNombre[value] ?? value;
                      });
                    },
            )
          else
            Column(
              children: [
                TextField(
                  enabled: !_soloLecturaEfectiva,
                  controller: TextEditingController(text: item.clave)
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: item.clave.length),
                    ),
                  onChanged: (value) => item.clave = value,
                  style: const TextStyle(color: Colors.white),
                  decoration: _deco(
                    'ID del sonido',
                    hint: 'Documento en Sonidos',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  enabled: !_soloLecturaEfectiva,
                  controller: TextEditingController(text: item.nombre)
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: item.nombre.length),
                    ),
                  onChanged: (value) => item.nombre = value,
                  style: const TextStyle(color: Colors.white),
                  decoration: _deco(
                    'Nombre visible',
                    hint: 'Ej. ADARA',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          TextField(
            enabled: !_soloLecturaEfectiva,
            controller: TextEditingController(
              text: item.precioPromocional == 0
                  ? ''
                  : item.precioPromocional.toString(),
            )..selection = TextSelection.fromPosition(
                TextPosition(
                  offset: item.precioPromocional == 0
                      ? 0
                      : item.precioPromocional.toString().length,
                ),
              ),
            onChanged: (value) =>
                item.precioPromocional = int.tryParse(value) ?? 0,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _deco(
              'Precio promocional',
              hint: 'Tokens',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puedeSolicitar = !widget.modoAdmin && !_soloLecturaEfectiva;
    final segmentoInfo = _segmentoMacroActual ?? _segmentoMacroCampana;
    final tarjetaSegmento = segmentoInfo == null
        ? const SizedBox.shrink()
        : _buildTarjetaSegmentoMacro(
            segmento: segmentoInfo,
            titulo: _segmentoMacroActual != null
                ? 'Segmento activo'
                : 'Segmento de la campana',
            descripcion: _segmentoMacroActual != null
                ? 'Al guardar, esta campana se mantiene asociada a este macrosegmento.'
                : 'Esta campana ya esta asociada a este macrosegmento.',
          );

    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      appBar: AppBar(
        backgroundColor: BioConfig.colorFondo,
        title: Text(
          widget.campana == null ? 'Nueva campana' : 'Editar campana',
          style: TextStyle(
            color: BioConfig.colorPrimario,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_soloLecturaEfectiva)
            IconButton(
              onPressed: _guardando
                  ? null
                  : () => _guardar(solicitarAprobacion: false),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (segmentoInfo != null) ...[
              tarjetaSegmento,
              const SizedBox(height: 12),
            ],
            TextField(
              enabled: !_soloLecturaEfectiva,
              controller: _nombreCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _deco('Nombre de la campana'),
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: !_soloLecturaEfectiva,
              controller: _dirigidoACtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _deco(
                'Dirigido a',
                hint: 'Ej. Usuarios nuevos, VIP, token < 500',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: !_soloLecturaEfectiva,
                    controller: _impactoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _deco('Impacto estimado'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    enabled: !_soloLecturaEfectiva,
                    controller: _notasCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _deco(
                      'Notas',
                      hint: 'Antes 500 / hoy 350',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _soloLecturaEfectiva
                        ? null
                        : () async {
                            final dt = await _seleccionarFechaHora(_inicio);
                            if (dt == null) return;
                            setState(() => _inicio = dt);
                          },
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text('Inicio: ${_fmtDateTime(_inicio)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _soloLecturaEfectiva
                        ? null
                        : () async {
                            final dt = await _seleccionarFechaHora(_fin);
                            if (dt == null) return;
                            setState(() => _fin = dt);
                          },
                    icon: const Icon(Icons.timer_outlined),
                    label: Text('Fin: ${_fmtDateTime(_fin)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Items impactados',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!_soloLecturaEfectiva)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _items.add(_MarketingItemDraft.empty())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_items.length, _buildItemRow),
            const SizedBox(height: 18),
            const Text(
              'Imagenes promocionales',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _soloLecturaEfectiva
                  ? 'Estas URLs ya quedaron asociadas a la campana.'
                  : 'Puedes pegar la URL directa o subir el banner con EdMark para que la app la complete sola.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _imagenCtrls.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      enabled: !_soloLecturaEfectiva,
                      controller: _imagenCtrls[i],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco(
                        'Imagen ${i + 1}',
                        hint: 'https://.../banner.png',
                      ),
                    ),
                  ),
                  if (!_soloLecturaEfectiva) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      onPressed: _subiendoImagenes[i]
                          ? null
                          : () => _subirImagenConEdMark(i),
                      icon: _subiendoImagenes[i]
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(
                        _subiendoImagenes[i] ? 'Subiendo' : 'Subir',
                      ),
                    ),
                  ],
                ],
              ),
              if (_imagenCtrls[i].text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _imagenCtrls[i].text.trim(),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.white10,
                      alignment: Alignment.center,
                      child: const Text(
                        'No se pudo previsualizar la imagen',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 20),
            if (!_soloLecturaEfectiva)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BioConfig.colorPrimario,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _guardando
                        ? null
                        : () => _guardar(solicitarAprobacion: false),
                    child:
                        Text(_guardando ? 'Guardando...' : 'Guardar borrador'),
                  ),
                  if (puedeSolicitar)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _guardando
                          ? null
                          : () => _guardar(solicitarAprobacion: true),
                      child: const Text('Solicitar aprobacion'),
                    ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: _previsualizar,
                    child: const Text('Previsualizar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
