// ======================================================================
// BioFreq — Módulo: clinica
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

class PantallaClinicaDigital extends StatefulWidget {
  final String medicoId;
  final String medicoNombre;
  final bool modoAdmin;
  const PantallaClinicaDigital(
      {super.key,
      required this.medicoId,
      required this.medicoNombre,
      this.modoAdmin = false});
  @override
  State<PantallaClinicaDigital> createState() => _PantallaClinicaDigitalState();
}

class _PantallaClinicaDigitalState extends State<PantallaClinicaDigital>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final TextEditingController _msgCtrl = TextEditingController();
  final TextEditingController _invEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _msgCtrl.dispose();
    _invEmailCtrl.dispose();
    super.dispose();
  }

  // ── Aprobar prescripción ──────────────────────────────────────────────────
  // ── Semáforo de prescripción ─────────────────────────────────────────────
  // modo: 'aprobar' | 'modificar' | 'denegar'
  Future<void> _dialogSemaforoReceta(QueryDocumentSnapshot doc,
      {required String modo}) async {
    final d = doc.data() as Map<String, dynamic>;
    final pacienteId = d['paciente_id'] as String? ?? '';
    final pacienteNombre = d['paciente_nombre'] as String? ?? 'Paciente';
    final sonidoId = d['sonido_id'] as String? ?? '';
    final sonidoNombre = d['sonido_nombre'] as String? ?? '';
    final origen = d['origen'] as String? ?? 'manual';
    final patologia = d['patologia_detectada'] as String? ?? '';
    final motivo = d['motivo_paciente'] as String? ?? '';

    // Cargar historial del paciente para mostrar en ficha
    final histSnap = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(pacienteId)
        .collection(BioConfig.colAccesosSonidos)
        .limit(10)
        .get();
    final historial = histSnap.docs
        .map((doc) => doc.data()['sonido_id'] as String? ?? doc.id)
        .toList();

    if (!mounted) return;

    // Controladores de dosificación
    final sesionesCtrl = TextEditingController(text: '1');
    final horasCtrl = TextEditingController(text: '24');
    final minutosCtrl = TextEditingController(text: '0');
    final diasCtrl = TextEditingController(text: '7');
    final motivoCtrl = TextEditingController();
    // Para modificar: sonido alternativo
    String sonidoAlt = sonidoId;
    String sonidoAltNombre = sonidoNombre;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(
                modo == 'aprobar'
                    ? Icons.check_circle
                    : modo == 'modificar'
                        ? Icons.edit_note
                        : Icons.cancel,
                color: modo == 'aprobar'
                    ? Colors.green
                    : modo == 'modificar'
                        ? Colors.orange
                        : Colors.red,
                size: 22),
            const SizedBox(width: 8),
            Flexible(
                child: Text(
                    modo == 'aprobar'
                        ? 'Aprobar tratamiento'
                        : modo == 'modificar'
                            ? 'Modificar y aprobar'
                            : 'Denegar solicitud',
                    style: const TextStyle(color: Colors.white, fontSize: 14))),
          ]),
          content: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Ficha del paciente (expandible) ───────────────
                  _fichaExpansion(
                      pacienteNombre: pacienteNombre,
                      origen: origen,
                      patologia: patologia,
                      motivo: motivo,
                      historial: historial),
                  const SizedBox(height: 14),

                  if (modo != 'denegar') ...[
                    // ── Sonido ────────────────────────────────────────
                    if (modo == 'modificar') ...[
                      const Text('Sonido a prescribir',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          // Picker de sonido disponible
                          final sel = await _dialogElegirSonido(ctx);
                          if (sel != null) {
                            setDlgState(() {
                              sonidoAlt = sel['id'] as String;
                              sonidoAltNombre = sel['nombre'] as String;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.music_note,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(sonidoAltNombre,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12))),
                            const Icon(Icons.edit,
                                color: Colors.white38, size: 14),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Dosificación ──────────────────────────────────
                    _labelDosis('Sesiones por ciclo'),
                    const SizedBox(height: 6),
                    _inputDosis(sesionesCtrl, 'ej: 2', setDlgState),
                    const SizedBox(height: 10),

                    _labelDosis('Intervalo entre ciclos'),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                          child: _inputDosis(horasCtrl, 'horas', setDlgState,
                              suffix: 'h')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _inputDosis(
                              minutosCtrl, 'minutos', setDlgState,
                              suffix: 'm')),
                    ]),
                    const SizedBox(height: 4),
                    Text(_textoIntervalo(horasCtrl.text, minutosCtrl.text),
                        style: const TextStyle(
                            color: Colors.tealAccent, fontSize: 10)),
                    const SizedBox(height: 10),

                    _labelDosis('Días de tratamiento'),
                    const SizedBox(height: 6),
                    _inputDosis(diasCtrl, 'ej: 7', setDlgState),
                    const SizedBox(height: 4),
                    // Resumen: costo estimado
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection(BioConfig.colSonidos)
                          .doc(modo == 'modificar' ? sonidoAlt : sonidoId)
                          .get(),
                      builder: (_, snapS) {
                        if (!snapS.hasData) return const SizedBox();
                        final sData =
                            snapS.data?.data() as Map<String, dynamic>?;
                        final precio = BioConfig.costoUsoEstimadoSonido(sData);
                        final ses = int.tryParse(sesionesCtrl.text) ?? 1;
                        final dias = int.tryParse(diasCtrl.text) ?? 1;
                        final total = precio * ses * dias;
                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                              'Costo total: ${total > 0 ? total : "—"} tokens '
                              '($ses ses × $dias días)',
                              style: const TextStyle(
                                  color: Colors.tealAccent, fontSize: 11)),
                        );
                      },
                    ),
                  ],

                  if (modo == 'denegar') ...[
                    const Text('Motivo (opcional, visible al paciente)',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: motivoCtrl,
                      maxLines: 3,
                      maxLength: 200,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Ej: Está en tratamiento por otra vía...',
                        hintStyle: const TextStyle(
                            color: Colors.white24, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        counterStyle: const TextStyle(
                            color: Colors.white24, fontSize: 10),
                      ),
                    ),
                  ],
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: modo == 'aprobar'
                      ? Colors.green
                      : modo == 'modificar'
                          ? Colors.orange
                          : Colors.red,
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _ejecutarSemaforo(
                  doc: doc,
                  modo: modo,
                  pacienteId: pacienteId,
                  pacienteNombre: pacienteNombre,
                  sonidoIdFinal: modo == 'modificar' ? sonidoAlt : sonidoId,
                  sonidoNombreFinal:
                      modo == 'modificar' ? sonidoAltNombre : sonidoNombre,
                  sesiones: int.tryParse(sesionesCtrl.text) ?? 1,
                  horas: int.tryParse(horasCtrl.text) ?? 24,
                  minutos: int.tryParse(minutosCtrl.text) ?? 0,
                  dias: int.tryParse(diasCtrl.text) ?? 7,
                  motivo: motivoCtrl.text.trim(),
                );
              },
              child: Text(
                  modo == 'aprobar'
                      ? 'Confirmar aprobación'
                      : modo == 'modificar'
                          ? 'Aprobar modificado'
                          : 'Confirmar denegación',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers visuales para el diálogo ────────────────────────────────────
  static Widget _fichaExpansion({
    required String pacienteNombre,
    required String origen,
    required String patologia,
    required String motivo,
    required List<String> historial,
  }) {
    return Theme(
      data: ThemeData(
        colorScheme: const ColorScheme.dark(),
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(children: [
          const Icon(Icons.person_outline, color: Colors.tealAccent, size: 16),
          const SizedBox(width: 8),
          Text('Ficha: $pacienteNombre',
              style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (origen == 'manual' && motivo.isNotEmpty)
                _fichaFila('💬 Motivo', motivo, Colors.white70),
              if (historial.isNotEmpty)
                _fichaFila('🎵 Sonidos recientes', historial.take(5).join(', '),
                    Colors.white54),
              if (historial.isEmpty)
                _fichaFila(
                    '🎵 Historial', 'Sin sonidos previos', Colors.white38),
            ]),
          ),
        ],
      ),
    );
  }

  static Widget _fichaFila(String label, String valor, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            TextSpan(
                text: valor,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
        ),
      );

  static Widget _labelDosis(String t) =>
      Text(t, style: const TextStyle(color: Colors.white54, fontSize: 11));

  static Widget _inputDosis(
          TextEditingController ctrl, String hint, StateSetter set,
          {String suffix = ''}) =>
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => set(() {}),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  static String _textoIntervalo(String hStr, String mStr) {
    final h = int.tryParse(hStr) ?? 0;
    final m = int.tryParse(mStr) ?? 0;
    if (h == 0 && m == 0) return 'Intervalo: sin restricción de tiempo';
    final partes = <String>[];
    if (h > 0) partes.add('$h hora${h != 1 ? 's' : ''}');
    if (m > 0) partes.add('$m minuto${m != 1 ? 's' : ''}');
    return 'Se bloqueará ${partes.join(' y ')} entre ciclos';
  }

  // Selector de sonido alternativo para modo "modificar"
  Future<Map<String, String>?> _dialogElegirSonido(BuildContext ctx) async {
    final snap = await FirebaseFirestore.instance
        .collection(BioConfig.colSonidos)
        .where('estado', isEqualTo: BioConfig.estadoDisponible)
        .limit(30)
        .get();
    if (!mounted) return null;
    return showDialog<Map<String, String>>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Elegir sonido alternativo',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: snap.docs.map((doc) {
              final nombre = (doc.data()['Nombre'] as String?) ?? doc.id;
              return ListTile(
                dense: true,
                title: Text(nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                onTap: () =>
                    Navigator.pop(context, {'id': doc.id, 'nombre': nombre}),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Ejecutar decisión del semáforo ───────────────────────────────────────
  Future<void> _ejecutarSemaforo({
    required QueryDocumentSnapshot doc,
    required String modo,
    required String pacienteId,
    required String pacienteNombre,
    required String sonidoIdFinal,
    required String sonidoNombreFinal,
    required int sesiones,
    required int horas,
    required int minutos,
    required int dias,
    required String motivo,
  }) async {
    final d = doc.data() as Map<String, dynamic>;
    final sonidoIdOriginal = d['sonido_id'] as String? ?? '';

    // Calcular costo total
    int precioSesion = 0;
    try {
      final sDoc = await FirebaseFirestore.instance
          .collection(BioConfig.colSonidos)
          .doc(sonidoIdFinal)
          .get();
      precioSesion = BioConfig.costoUsoEstimadoSonido(sDoc.data());
    } catch (_) {}
    final costoTotal = precioSesion * sesiones * dias;

    final minutosTotal = horas * 60 + minutos;
    final batch = FirebaseFirestore.instance.batch();

    if (modo == 'denegar') {
      batch.update(doc.reference, {
        'estado': 'denegado',
        'motivo_rechazo': motivo,
        'fecha_resolucion': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await BioNotif.recetaDenegada(pacienteId, sonidoNombreFinal,
          motivo.isNotEmpty ? motivo : 'Sin motivo especificado');
    } else {
      // Aprobar o modificar
      batch.update(doc.reference, {
        'estado': modo == 'modificar' ? 'modificado' : 'aprobado',
        'sonido_id_final': sonidoIdFinal,
        'sonido_nombre_final': sonidoNombreFinal,
        'sesiones_por_ciclo': sesiones,
        'minutos_entre_ciclos': minutosTotal,
        'dias_tratamiento': dias,
        'costo_total': costoTotal,
        'fecha_resolucion': FieldValue.serverTimestamp(),
      });

      // Crear/actualizar acceso — tokens_pagados=false hasta que el user pague
      final accesoRef = FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(pacienteId)
          .collection(BioConfig.colAccesosSonidos)
          .doc(sonidoIdFinal);
      batch.set(
          accesoRef,
          {
            'sonido_id': sonidoIdFinal,
            'aprobado': true,
            'tokens_pagados': false, // user debe pagar antes de iniciar
            'medico_id': widget.medicoId,
            'sesiones_por_ciclo': sesiones,
            'minutos_entre_ciclos': minutosTotal,
            'dias_tratamiento': dias,
            'costo_total_tokens': costoTotal,
            'sesiones_hoy': 0, // se activa al pagar
            'sesiones_completadas': 0,
            'sesiones_saltadas': 0,
            'ciclos_aplicados': 0,
            'tratamiento_activo': false, // se activa al pagar
            'fecha_prescripcion': FieldValue.serverTimestamp(),
            'ciclos_completados': 0,
          },
          SetOptions(merge: true));

      await batch.commit();

      // Si modificó el sonido, también marcar el doc original como modificado
      if (modo == 'modificar' && sonidoIdOriginal != sonidoIdFinal) {
        await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(pacienteId)
            .collection(BioConfig.colAccesosSonidos)
            .doc(sonidoIdOriginal)
            .set({'aprobado': false}, SetOptions(merge: true));
      }

      // Notificar al user
      if (modo == 'modificar') {
        await BioNotif.recetaModificada(
            pacienteId, sonidoNombreFinal, sesiones, dias, costoTotal);
      } else {
        await BioNotif.recetaAprobada(
            pacienteId, sonidoNombreFinal, sesiones, dias, costoTotal);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor:
            modo == 'denegar' ? Colors.red.shade900 : Colors.green.shade900,
        content: Text(
          modo == 'denegar'
              ? '❌ Solicitud de $pacienteNombre denegada'
              : '✅ Tratamiento prescrito a $pacienteNombre',
        ),
      ));
    }
  }

  // ── Toggle acceso manual a un sonido ─────────────────────────────────────
  Future<void> _toggleAccesoSonido(
      String pacienteId, String sonidoId, bool valorActual) async {
    final ref = FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(pacienteId)
        .collection(BioConfig.colAccesosSonidos)
        .doc(sonidoId);
    if (valorActual) {
      await ref.update({'aprobado': false});
    } else {
      await ref.set({
        'sonido_id': sonidoId,
        'aprobado': true,
        'medico_id': widget.medicoId,
        'fecha_prescripcion': FieldValue.serverTimestamp(),
        'ciclos_completados': 0,
      }, SetOptions(merge: true));
    }
  }

  // ── Adjuntar imagen y enviarla como mensaje ─────────────────────────────
  // Usa image_picker para seleccionar de galería o cámara.
  // La imagen se sube a Firebase Storage y luego se manda como mensaje tipo 'imagen'.
  // ⚠️  Solo disponible en chat con Admin (soporte técnico).
  // ── Adjuntar imagen como base64 en el chat PS↔Admin ────────────────────
  // Sin Firebase Storage — la imagen se codifica en base64 (≤300 KB tras
  // compresión) y se guarda directo en Firestore como string data:image.
  // Suficiente para pantallazos de errores (el caso de uso principal).

  // ── Enviar mensaje (canal PS↔User o PS↔Admin) ────────────────────────────

  // ── Enviar invitación ─────────────────────────────────────────────────────
  // ⚠️ SEGURIDAD: PS solo puede invitar 'user' o 'PS'.
  // El rol 'tester' solo lo puede asignar Admin directamente en Firestore.

  // ── Panel detalle de paciente (modal de sonidos) ──────────────────────────
  void _verPaciente(String pacienteId, String nombrePaciente) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: Colors.teal.withValues(alpha: 0.3),
                  child: Text(nombrePaciente.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(nombrePaciente,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const Text('Gestionar acceso a sonidos',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ])),
              // Botón de chat rápido
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline,
                    color: Colors.tealAccent),
                tooltip: 'Chat con paciente',
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _tab.animateTo(0); // ir a tab Comunicación
                  });
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection(BioConfig.colSonidos)
                  .where('estado', isEqualTo: BioConfig.estadoDisponible)
                  .get(),
              builder: (_, sSnap) {
                if (!sSnap.hasData) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: BioConfig.colorPrimario));
                }
                return ListView.builder(
                  controller: ctrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: sSnap.data!.docs.length,
                  itemBuilder: (_, i) {
                    final s = sSnap.data!.docs[i];
                    final sd = s.data() as Map<String, dynamic>;
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(BioConfig.colUsuarios)
                          .doc(pacienteId)
                          .collection(BioConfig.colAccesosSonidos)
                          .doc(s.id)
                          .snapshots(),
                      builder: (_, aSnap) {
                        final bool aprobado = aSnap.hasData &&
                            aSnap.data!.exists &&
                            (aSnap.data!.data()
                                    as Map<String, dynamic>?)?['aprobado'] ==
                                true;
                        return ListTile(
                          leading: Icon(Icons.graphic_eq,
                              color: aprobado
                                  ? Colors.tealAccent
                                  : Colors.white24),
                          title: Text(sd['Nombre'] ?? '—',
                              style: TextStyle(
                                  color:
                                      aprobado ? Colors.white : Colors.white54,
                                  fontWeight: aprobado
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          subtitle: Text(sd['descripcion'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white24, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: Switch(
                            value: aprobado,
                            onChanged: (_) =>
                                _toggleAccesoSonido(pacienteId, s.id, aprobado),
                            activeColor: Colors.tealAccent,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamSolicitudesPendientes() {
    final base = FirebaseFirestore.instance
        .collection(BioConfig.colSolicitudesPrescripcion);
    if (widget.modoAdmin) {
      return base.where('estado', isEqualTo: 'pendiente').snapshots();
    }
    return base
        .where('medico_id', isEqualTo: widget.medicoId)
        .where('estado', isEqualTo: 'pendiente')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamPacientes() {
    final base = FirebaseFirestore.instance.collection(BioConfig.colUsuarios);
    if (widget.modoAdmin) {
      return base.snapshots();
    }
    return base.where('medico_id', isEqualTo: widget.medicoId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamRecetasActivas() {
    final base = FirebaseFirestore.instance.collection(
      BioConfig.colSolicitudesPrescripcion,
    );
    if (widget.modoAdmin) {
      return base.snapshots();
    }
    return base.where('medico_id', isEqualTo: widget.medicoId).snapshots();
  }

  Future<void> _modificarRecetaActiva(
      DocumentSnapshot<Map<String, dynamic>> accesoDoc) async {
    final data = accesoDoc.data() ?? <String, dynamic>{};
    final pacienteId = accesoDoc.reference.parent.parent?.id ?? '';
    if (pacienteId.isEmpty) return;

    final pacienteSnap = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(pacienteId)
        .get();
    final pacienteData = pacienteSnap.data() as Map<String, dynamic>?;
    final pacienteNombre = (pacienteData?['nombre'] ??
            pacienteData?['email'] ??
            data['paciente_nombre'] ??
            'Paciente')
        .toString();

    final sonidoActualId = (data['sonido_id'] ?? accesoDoc.id).toString();
    var sonidoFinalId = sonidoActualId;
    var sonidoFinalNombre = (data['sonido_nombre'] ??
            data['sonido_nombre_final'] ??
            data['nombre_sonido'] ??
            sonidoActualId)
        .toString();

    final sesionesCtrl = TextEditingController(
      text: ((data['sesiones_por_ciclo'] as num?)?.toInt() ?? 1).toString(),
    );
    final minutosTotal =
        ((data['minutos_entre_ciclos'] as num?)?.toInt() ?? 1440);
    final horasCtrl =
        TextEditingController(text: (minutosTotal ~/ 60).toString());
    final minutosCtrl =
        TextEditingController(text: (minutosTotal % 60).toString());
    final diasCtrl = TextEditingController(
      text: ((data['dias_tratamiento'] as num?)?.toInt() ?? 7).toString(),
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Modificar receta de $pacienteNombre',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sonido',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final sel = await _dialogElegirSonido(ctx);
                    if (sel != null) {
                      setDlgState(() {
                        sonidoFinalId = sel['id'] as String;
                        sonidoFinalNombre = sel['nombre'] as String;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.music_note,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sonidoFinalNombre,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const Icon(Icons.edit, color: Colors.white38, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _labelDosis('Sesiones por ciclo'),
                const SizedBox(height: 6),
                _inputDosis(sesionesCtrl, 'ej: 2', setDlgState),
                const SizedBox(height: 10),
                _labelDosis('Intervalo entre ciclos'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _inputDosis(horasCtrl, 'horas', setDlgState,
                          suffix: 'h'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _inputDosis(minutosCtrl, 'min', setDlgState,
                          suffix: 'm'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _textoIntervalo(horasCtrl.text, minutosCtrl.text),
                  style:
                      const TextStyle(color: Colors.tealAccent, fontSize: 10),
                ),
                const SizedBox(height: 10),
                _labelDosis('Dias de tratamiento'),
                const SizedBox(height: 6),
                _inputDosis(diasCtrl, 'ej: 7', setDlgState),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final sesiones = int.tryParse(sesionesCtrl.text) ?? 1;
                final horas = int.tryParse(horasCtrl.text) ?? 24;
                final minutos = int.tryParse(minutosCtrl.text) ?? 0;
                final dias = int.tryParse(diasCtrl.text) ?? 7;
                final minutosEntreCiclos = (horas * 60) + minutos;

                int precioSesion = 0;
                try {
                  final sDoc = await FirebaseFirestore.instance
                      .collection(BioConfig.colSonidos)
                      .doc(sonidoFinalId)
                      .get();
                  precioSesion = BioConfig.costoUsoEstimadoSonido(sDoc.data());
                } catch (_) {}
                final costoTotal = precioSesion * sesiones * dias;

                final medicoResponsable =
                    (data['medico_id'] ?? widget.medicoId).toString();
                final batch = FirebaseFirestore.instance.batch();
                final pacienteAccesos = FirebaseFirestore.instance
                    .collection(BioConfig.colUsuarios)
                    .doc(pacienteId)
                    .collection(BioConfig.colAccesosSonidos);

                if (sonidoFinalId != sonidoActualId) {
                  batch.set(
                    accesoDoc.reference,
                    {
                      'aprobado': false,
                      'tratamiento_activo': false,
                      'fecha_revocacion': FieldValue.serverTimestamp(),
                      'motivo_revocacion': 'Reemplazada por otra receta',
                    },
                    SetOptions(merge: true),
                  );
                }

                final destinoRef = sonidoFinalId == sonidoActualId
                    ? accesoDoc.reference
                    : pacienteAccesos.doc(sonidoFinalId);
                batch.set(
                  destinoRef,
                  {
                    ...data,
                    'sonido_id': sonidoFinalId,
                    'sonido_nombre': sonidoFinalNombre,
                    'aprobado': true,
                    'medico_id': medicoResponsable,
                    'paciente_id': pacienteId,
                    'paciente_nombre': pacienteNombre,
                    'sesiones_por_ciclo': sesiones,
                    'minutos_entre_ciclos': minutosEntreCiclos,
                    'dias_tratamiento': dias,
                    'costo_total_tokens': costoTotal,
                    'fecha_modificacion': FieldValue.serverTimestamp(),
                    'modificada_por_admin': widget.modoAdmin,
                  },
                  SetOptions(merge: true),
                );
                await batch.commit();
                await BioNotif.recetaModificada(
                  pacienteId,
                  sonidoFinalNombre,
                  sesiones,
                  dias,
                  costoTotal,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.orange.shade900,
                    content: Text('Receta actualizada para $pacienteNombre'),
                  ),
                );
              },
              child: const Text(
                'Guardar cambios',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _revocarRecetaActiva(
      DocumentSnapshot<Map<String, dynamic>> accesoDoc) async {
    final data = accesoDoc.data() ?? <String, dynamic>{};
    final pacienteId = accesoDoc.reference.parent.parent?.id ?? '';
    if (pacienteId.isEmpty) return;
    final sonidoId = (data['sonido_id'] ?? accesoDoc.id).toString();
    final sonidoNombre = (data['sonido_nombre'] ??
            data['sonido_nombre_final'] ??
            data['nombre_sonido'] ??
            sonidoId)
        .toString();
    final motivoCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title:
            const Text('Revocar receta', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se revocara el acceso a "$sonidoNombre".',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Motivo de la revocacion',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    final motivo = motivoCtrl.text.trim().isEmpty
        ? 'Revocada por control clinico'
        : motivoCtrl.text.trim();

    await accesoDoc.reference.set(
      {
        'aprobado': false,
        'tratamiento_activo': false,
        'fecha_revocacion': FieldValue.serverTimestamp(),
        'motivo_revocacion': motivo,
        'revocada_por': FirebaseAuth.instance.currentUser?.uid,
      },
      SetOptions(merge: true),
    );

    final solicitudSnap = await FirebaseFirestore.instance
        .collection(BioConfig.colSolicitudesPrescripcion)
        .where('paciente_id', isEqualTo: pacienteId)
        .where('sonido_id', isEqualTo: sonidoId)
        .get();
    for (final solicitud in solicitudSnap.docs) {
      await solicitud.reference.set(
        {
          'estado': 'revocada',
          'motivo_rechazo': motivo,
          'fecha_resolucion': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await BioNotif.recetaRevocada(pacienteId, sonidoNombre, motivo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade900,
        content: Text('Receta revocada: $sonidoNombre'),
      ),
    );
  }

  Widget _buildRecetasActivasTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamRecetasActivas(),
      builder: (_, snap) {
        if (snap.hasError) {
          return _vacio(Icons.error_outline, 'Error al cargar recetas',
              snap.error.toString());
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.tealAccent),
          );
        }
        final recetas = snap.data!.docs.where((doc) {
          final estado = (doc.data()['estado'] ?? '').toString().toLowerCase();
          return estado == 'aprobado' || estado == 'pagado';
        }).toList();
        if (recetas.isEmpty) {
          return _vacio(Icons.menu_book_outlined, 'Sin recetas activas',
              'Aqui podras modificar o revocar tratamientos vigentes.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: recetas.length,
          itemBuilder: (_, i) {
            final solicitudDoc = recetas[i];
            final data = solicitudDoc.data();
            final pacienteId = (data['paciente_id'] ?? '').toString();
            final sonidoId = (data['sonido_id'] ?? '').toString();
            final sonidoNombre = (data['sonido_nombre'] ??
                    data['sonido_nombre_final'] ??
                    data['nombre_sonido'] ??
                    data['sonido_id'] ??
                    solicitudDoc.id)
                .toString();
            final medicoId = (data['medico_id'] ?? '').toString();
            return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
              future: Future.wait([
                FirebaseFirestore.instance
                    .collection(BioConfig.colUsuarios)
                    .doc(pacienteId)
                    .get(),
                FirebaseFirestore.instance
                    .collection(BioConfig.colUsuarios)
                    .doc(pacienteId)
                    .collection(BioConfig.colAccesosSonidos)
                    .doc(sonidoId)
                    .get(),
              ]),
              builder: (_, docsSnap) {
                final pacienteData =
                    docsSnap.data != null ? docsSnap.data![0].data() : null;
                final accesoDoc =
                    docsSnap.data != null ? docsSnap.data![1] : null;
                final accesoData = accesoDoc?.data() ?? data;
                final sesiones =
                    ((accesoData['sesiones_por_ciclo'] as num?)?.toInt() ?? 1);
                final dias =
                    ((accesoData['dias_tratamiento'] as num?)?.toInt() ?? 0);
                final costo =
                    ((accesoData['costo_total_tokens'] as num?)?.toInt() ?? 0);
                final pacienteNombre = (pacienteData?['nombre'] ??
                        pacienteData?['email'] ??
                        data['paciente_nombre'] ??
                        pacienteId)
                    .toString();
                final pacienteCodigo =
                    (pacienteData?[BioConfig.campoCodigoPropio] ?? '')
                        .toString();

                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.orangeAccent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sonidoNombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Paciente: $pacienteNombre'
                          '${pacienteCodigo.isNotEmpty ? ' · $pacienteCodigo' : ''}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        if (widget.modoAdmin)
                          Text(
                            'PS a cargo: ${medicoId.isNotEmpty ? medicoId : 'Sin PS'}',
                            style: const TextStyle(
                                color: Colors.tealAccent, fontSize: 11),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Dosificación: $sesiones ses/ciclo · $dias días · $costo tokens',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orangeAccent,
                                  side: const BorderSide(
                                      color: Colors.orangeAccent),
                                ),
                                onPressed: accesoDoc != null && accesoDoc.exists
                                    ? () => _modificarRecetaActiva(accesoDoc)
                                    : null,
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Modificar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side:
                                      const BorderSide(color: Colors.redAccent),
                                ),
                                onPressed: accesoDoc != null && accesoDoc.exists
                                    ? () => _revocarRecetaActiva(accesoDoc)
                                    : null,
                                icon: const Icon(Icons.block, size: 16),
                                label: const Text('Revocar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      appBar: AppBar(
        backgroundColor: BioConfig.colorFondo,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Consultorio Virtual",
              style: TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(widget.medicoNombre,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),
      body: TabBarView(controller: _tab, children: [
        // ══════════════════════════════════════════════════════════
        // TAB 1: PRESCRIPCIONES
        // ══════════════════════════════════════════════════════════
        DefaultTabController(
          length: 3,
          child: Column(children: [
            Container(
              color: const Color(0xFF111111),
              child: const TabBar(
                indicatorColor: Colors.tealAccent,
                labelColor: Colors.tealAccent,
                unselectedLabelColor: Colors.white38,
                tabs: [
                  Tab(text: "Pendientes"),
                  Tab(text: "Recetas activas"),
                  Tab(text: "Mis Pacientes"),
                ],
              ),
            ),
            Expanded(
                child: TabBarView(children: [
              // Sub-tab: Solicitudes pendientes
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _streamSolicitudesPendientes(),
                builder: (_, snap) {
                  if (snap.hasError) {
                    return _vacio(Icons.error_outline, "Error al cargar",
                        snap.error.toString());
                  }
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.tealAccent));
                  }
                  final pendientes = snap.data!.docs
                      .where((d) => d.data()['estado'] == 'pendiente')
                      .toList();
                  if (pendientes.isEmpty) {
                    return _vacio(
                      Icons.check_circle_outline,
                      'Todo al dia',
                      widget.modoAdmin
                          ? 'No hay solicitudes pendientes para gestionar.'
                          : 'No tienes solicitudes pendientes.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: pendientes.length,
                    itemBuilder: (_, i) {
                      final doc = pendientes[i];
                      final d = doc.data();
                      final psNombre = (d['ps_nombre'] ??
                              d['medico_nombre'] ??
                              d['medico_id'] ??
                              'Sin PS')
                          .toString();
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color:
                                    Colors.tealAccent.withValues(alpha: 0.35))),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${d['paciente_nombre'] ?? d['paciente_id'] ?? 'Un paciente'} solicita:',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                    d['sonido_nombre'] ??
                                        d['sonido_id'] ??
                                        '---',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                if (widget.modoAdmin) ...[
                                  const SizedBox(height: 4),
                                  Text('PS a cargo: $psNombre',
                                      style: const TextStyle(
                                          color: Colors.tealAccent,
                                          fontSize: 11)),
                                ],
                                if (d['nota'] != null &&
                                    (d['nota'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Nota: ${d['nota']}',
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 11)),
                                ],
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      icon: const Icon(Icons.circle,
                                          size: 12, color: Colors.greenAccent),
                                      label: const Text('Aprobar',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11)),
                                      onPressed: () => _dialogSemaforoReceta(
                                          doc,
                                          modo: 'aprobar'),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      icon: const Icon(Icons.circle,
                                          size: 12, color: Colors.yellowAccent),
                                      label: const Text('Modificar',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11)),
                                      onPressed: () => _dialogSemaforoReceta(
                                          doc,
                                          modo: 'modificar'),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      icon: const Icon(Icons.circle,
                                          size: 12, color: Colors.redAccent),
                                      label: const Text('Denegar',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11)),
                                      onPressed: () => _dialogSemaforoReceta(
                                          doc,
                                          modo: 'denegar'),
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

              _buildRecetasActivasTab(),

              // Sub-tab: Mis pacientes
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _streamPacientes(),
                builder: (_, snap) {
                  if (snap.hasError || !snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.tealAccent));
                  }
                  final docs = snap.data!.docs.where((doc) {
                    final data = doc.data();
                    final rol = (data['rol'] ?? '').toString();
                    if (widget.modoAdmin) {
                      return doc.id != widget.medicoId &&
                          rol != BioConfig.rolAdmin;
                    }
                    return true;
                  }).toList();
                  if (docs.isEmpty) {
                    return _vacio(Icons.people_outline, "Sin pacientes aún",
                        "Comparte tu código BIOMED-XXXX para que tus pacientes se registren.");
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      final uid = docs[i].id;
                      final nombre = d['nombre'] ?? d['email'] ?? 'Paciente';
                      final esTester = (d['rol'] ?? '') == BioConfig.rolTester;
                      // Marcar datos efímeros de testers
                      String? testerExpira;
                      if (esTester && d['fecha_registro'] != null) {
                        final reg = (d['fecha_registro'] as Timestamp).toDate();
                        final expira = reg.add(BioConfig.testerDataTTL);
                        if (DateTime.now().isBefore(expira)) {
                          final restante = expira.difference(DateTime.now());
                          testerExpira =
                              '⚡ Tester — expira en ${restante.inHours}h';
                        } else {
                          testerExpira = '⚡ Tester — sesión expirada';
                        }
                      }
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: esTester
                              ? Colors.amber.withValues(alpha: 0.2)
                              : Colors.teal.withValues(alpha: 0.2),
                          child: Text(nombre.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                  color: esTester
                                      ? Colors.amber
                                      : Colors.tealAccent,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(nombre,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                        subtitle: Text(testerExpira ?? (d['email'] ?? ''),
                            style: TextStyle(
                                color: testerExpira != null
                                    ? Colors.amber
                                    : Colors.white38,
                                fontSize: 11)),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.tealAccent),
                        onTap: () => _verPaciente(uid, nombre),
                      );
                    },
                  );
                },
              ),
            ])),
          ]),
        ),
      ]),
    );
  }

  // ── Formulario para aportar hallazgo clínico a sonido en investigación ────

  // ── Chip de selección de rol ──────────────────────────────────────────────

  // ── Mostrar paper completo en dialogo ─────────────────────────────────────

  Widget _vacio(IconData icon, String titulo, String sub) => Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white12, size: 64),
          const SizedBox(height: 16),
          Text(titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white24, fontSize: 13)),
        ]),
      ));

  // ── Tab 5: Alertas Bio-Scanner ─────────────────────────────────────────
}

// ═══════════════════════════════════════════════
// PANTALLA MI CUENTA
// ═══════════════════════════════════════════════
