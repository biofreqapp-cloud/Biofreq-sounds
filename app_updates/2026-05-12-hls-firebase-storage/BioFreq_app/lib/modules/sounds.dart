// ======================================================================
// BioFreq — Módulo: sounds
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

class _CompraPanelData {
  final String nivelActual;
  final int saldoActual;
  final bool planActiva;
  final DateTime? planFin;
  final Map<String, int> preciosPlanes;

  const _CompraPanelData({
    required this.nivelActual,
    required this.saldoActual,
    required this.planActiva,
    required this.planFin,
    required this.preciosPlanes,
  });
}

String _textoCampo(dynamic value) => value?.toString().trim() ?? '';

Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
    _seleccionarPsConMenorCargaRuntime() async {
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> candidatosPorRol(
    String rol,
  ) async {
    final query = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .where('rol', isEqualTo: rol)
        .get();
    return query.docs.where((doc) {
      final data = doc.data();
      final estadoPs = _textoCampo(data['estado_ps']).toLowerCase();
      return rol != BioConfig.rolPS ||
          estadoPs.isEmpty ||
          estadoPs == 'aprobado';
    }).toList();
  }

  var candidatos = await candidatosPorRol(BioConfig.rolPS);
  if (candidatos.isEmpty) {
    candidatos = await candidatosPorRol(BioConfig.rolAdmin);
  }

  candidatos = candidatos.where((doc) {
    final data = doc.data();
    final estadoPs = _textoCampo(data['estado_ps']).toLowerCase();
    return estadoPs.isEmpty || estadoPs == 'aprobado';
  }).toList();

  if (candidatos.isEmpty) return null;

  final cargas = <String, int>{for (final ps in candidatos) ps.id: 0};
  final usuarios =
      await FirebaseFirestore.instance.collection(BioConfig.colUsuarios).get();

  for (final doc in usuarios.docs) {
    final medicoId = _textoCampo(doc.data()['medico_id']);
    if (cargas.containsKey(medicoId)) {
      cargas[medicoId] = (cargas[medicoId] ?? 0) + 1;
    }
  }

  candidatos.sort((a, b) {
    final cmp = (cargas[a.id] ?? 0).compareTo(cargas[b.id] ?? 0);
    if (cmp != 0) return cmp;
    return a.id.compareTo(b.id);
  });
  return candidatos.first;
}

Future<Map<String, String?>> _resolverVinculoPsRuntime(
  Map<String, dynamic> userData,
) async {
  final referidoActual = _textoCampo(userData[BioConfig.campoReferidoPor]);
  final medicoActual = _textoCampo(userData['medico_id']);

  if (medicoActual.isNotEmpty) {
    return {
      BioConfig.campoReferidoPor:
          referidoActual.isNotEmpty ? referidoActual : null,
      'medico_id': medicoActual,
    };
  }

  if (referidoActual.isNotEmpty) {
    final invitadorSnap = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .where(BioConfig.campoCodigoPropio, isEqualTo: referidoActual)
        .limit(1)
        .get();

    if (invitadorSnap.docs.isNotEmpty) {
      final invitador = invitadorSnap.docs.first;
      final invitadorData = invitador.data();
      final rolInvitador = _textoCampo(invitadorData['rol']);

      if (rolInvitador == BioConfig.rolPS ||
          rolInvitador == BioConfig.rolAdmin) {
        return {
          BioConfig.campoReferidoPor: referidoActual,
          'medico_id': invitador.id,
        };
      }

      final medicoHeredado = _textoCampo(invitadorData['medico_id']);
      if (medicoHeredado.isNotEmpty) {
        return {
          BioConfig.campoReferidoPor: referidoActual,
          'medico_id': medicoHeredado,
        };
      }
    }
  }

  final psAleatorio = await _seleccionarPsConMenorCargaRuntime();
  final codigoPs =
      _textoCampo(psAleatorio?.data()[BioConfig.campoCodigoPropio]);

  return {
    BioConfig.campoReferidoPor: referidoActual.isNotEmpty
        ? referidoActual
        : (codigoPs.isNotEmpty ? codigoPs : null),
    'medico_id': psAleatorio?.id,
  };
}

Future<String?> _asegurarPsAsignadoRuntime(
  String userId,
  Map<String, dynamic> userData,
) async {
  final vinculo = await _resolverVinculoPsRuntime(userData);
  final medicoNuevo = _textoCampo(vinculo['medico_id']);
  final referidoNuevo = _textoCampo(vinculo[BioConfig.campoReferidoPor]);
  final medicoActual = _textoCampo(userData['medico_id']);
  final referidoActual = _textoCampo(userData[BioConfig.campoReferidoPor]);

  final updates = <String, dynamic>{};
  if (medicoNuevo.isNotEmpty && medicoNuevo != medicoActual) {
    updates['medico_id'] = medicoNuevo;
  }
  if (referidoNuevo.isNotEmpty && referidoNuevo != referidoActual) {
    updates[BioConfig.campoReferidoPor] = referidoNuevo;
  }

  if (updates.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(userId)
        .set(updates, SetOptions(merge: true));
  }

  return medicoNuevo.isNotEmpty ? medicoNuevo : null;
}

class PantallaListaSonidos extends StatefulWidget {
  // ⚠️  remoteVersion: viene de _BioFreqAppState para mostrarlo en Mi Cuenta.
  //     SIEMPRE pasarlo desde el padre. Sin esto Mi Cuenta muestra versión local.
  final VersionInfo? remoteVersion;
  const PantallaListaSonidos({super.key, this.remoteVersion});
  @override
  State<PantallaListaSonidos> createState() => _PantallaListaSonidosState();
}

class _PantallaListaSonidosState extends State<PantallaListaSonidos> {
  // ── Versión remota — se carga en initState para pasarla a Mi Cuenta ────────
  VersionInfo? _remoteVersionLocal;

  // ── Variables de estado del usuario (accesibles desde AppBar) ─────────────
  Map<String, dynamic> _uData = {};
  int _saldo = 0;
  String _codigo = '---';
  bool _resolviendoPsAutomatico = false;
  bool _resolviendoSegmentoMacro = false;
  Map<String, dynamic>? _macroSegmentoActual;
  double _valorTokenCopLista = 100.0;
  bool _puedeInvitarReferidos = false;
  int? _maxInvitadosReferidos;
  int _referidosDirectosActuales = 0;
  // ── Suscripción activa ────────────────────────────────────────────────────
  bool _tienePlanActivo = false;
  // Future cacheado — se crea UNA vez en initState, no en cada setState
  late Future<List<Map<String, dynamic>>> _sonidosFuture;
  late Future<_CompraPanelData> _compraPanelFuture;

  // ── Badge Consultorio Virtual (solo PS) ───────────────────────────────────
  // ⚠️  Cuenta solicitudes de pacientes pendientes. Se actualiza en tiempo real.
  //     NO mover este listener a otro lugar — el menú popup no acepta StreamBuilder.
  int _pendientesClinica = 0;
  StreamSubscription<QuerySnapshot>? _subSolicitudes;
  StreamSubscription<QuerySnapshot>? _subFavoritos;
  StreamSubscription<QuerySnapshot>? _subRecetados;

  // ── Buscador Inteligente ───────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _filtroActivo = 'todos'; // todos|recetados|favoritos|mas_usados
  Set<String> _favoritosIds = {};
  Set<String> _recetadosIds = {};

  bool _mismosIds(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  bool _tieneVinculoPs(Map<String, dynamic> data) {
    final medicoId = _textoCampo(data['medico_id']);
    final referidoPor = _textoCampo(data[BioConfig.campoReferidoPor]);
    return medicoId.isNotEmpty || referidoPor.isNotEmpty;
  }

  Future<String?> _resolverPsActual() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final medicoActual = _textoCampo(_uData['medico_id']);
    if (medicoActual.isNotEmpty) return medicoActual;
    return _asegurarPsAsignadoRuntime(
        user.uid, Map<String, dynamic>.from(_uData));
  }

  void _sincronizarPsAutomatico(String? uid, Map<String, dynamic> uData) {
    if (_resolviendoPsAutomatico || uid == null || _tieneVinculoPs(uData))
      return;
    _resolviendoPsAutomatico = true;
    unawaited(() async {
      try {
        final medicoId = await _asegurarPsAsignadoRuntime(uid, uData);
        if (!mounted || medicoId == null || medicoId.isEmpty) return;
        setState(() {
          _uData = {..._uData, 'medico_id': medicoId};
        });
      } catch (_) {
      } finally {
        _resolviendoPsAutomatico = false;
      }
    }());
  }

  void _sincronizarSegmentoMacro(String? uid, Map<String, dynamic> uData) {
    if (_resolviendoSegmentoMacro || uid == null) return;
    _resolviendoSegmentoMacro = true;
    unawaited(() async {
      try {
        final segmento = await MacroSegmentoConfig.resolveForUserData(uData);
        final merged = MacroSegmentoConfig.aplicarOverrides(uData, segmento);
        final valorToken =
            await MacroSegmentoConfig.resolveValorTokenCopForUserData(
          uData,
          fallback: 100,
        );
        final puedeInvitar =
            await MacroSegmentoConfig.resolveCanInviteForUserData(uData);
        final maxInvitados =
            await MacroSegmentoConfig.resolveMaxInvitadosForUserData(uData);
        final codigo = _textoCampo(merged[BioConfig.campoCodigoPropio]);
        final referidos = codigo.isNotEmpty
            ? await MacroSegmentoConfig.contarReferidosDirectos(codigo)
            : 0;
        if (!mounted) return;
        setState(() {
          _macroSegmentoActual = segmento;
          _uData = merged;
          _saldo = BioConfig.toInt(merged[BioConfig.campoTokens]);
          _codigo = merged[BioConfig.campoCodigoPropio] ?? '---';
          _valorTokenCopLista = valorToken;
          _puedeInvitarReferidos = puedeInvitar;
          _maxInvitadosReferidos = maxInvitados;
          _referidosDirectosActuales = referidos;
        });
      } catch (e) {
        debugPrint('[Macro] Error sincronizando segmento: $e');
      } finally {
        _resolviendoSegmentoMacro = false;
      }
    }());
  }

  String _formatearCopEntero(int valor) {
    final base = valor.toString();
    return base.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
  }

  Widget _chipFiltro(String key, String label, {int count = -1}) {
    final sel = _filtroActivo == key;
    return GestureDetector(
      onTap: () => setState(() {
        _filtroActivo = key;
        // Recargar lista al cambiar ordenamiento
        if (key == 'mas_usados' || _filtroActivo == 'mas_usados') {
          BioConfig.invalidarCacheSonidos();
          _sonidosFuture = _cargarSonidosConCache();
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: sel
              ? BioConfig.colorPrimario.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: sel ? BioConfig.colorPrimario : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: sel ? BioConfig.colorPrimario : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: BioConfig.colorPrimario.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: TextStyle(
                      color: BioConfig.colorPrimario,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    );
  }

  String _labelFiltroActivo() {
    switch (_filtroActivo) {
      case 'recetados':
        return 'Recetados (${_recetadosIds.length})';
      case 'favoritos':
        return 'Favoritos (${_favoritosIds.length})';
      case 'mas_usados':
        return 'Top 10';
      default:
        return 'Todos';
    }
  }

  IconData _iconoFiltroActivo() {
    switch (_filtroActivo) {
      case 'recetados':
        return Icons.medication_outlined;
      case 'favoritos':
        return Icons.favorite_border;
      case 'mas_usados':
        return Icons.emoji_events_outlined;
      default:
        return Icons.tune;
    }
  }

  void _seleccionarFiltro(String value) {
    setState(() {
      _filtroActivo = value;
      if (value == 'mas_usados') {
        BioConfig.invalidarCacheSonidos();
        _sonidosFuture = _cargarSonidosConCache();
      }
    });
  }

  Widget _buildFiltroCompacto() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: PopupMenuButton<String>(
        onSelected: _seleccionarFiltro,
        color: const Color(0xFF1E1E1E),
        itemBuilder: (_) => [
          const PopupMenuItem<String>(
            value: 'todos',
            child: Row(children: [
              Icon(Icons.graphic_eq, size: 18, color: Colors.white70),
              SizedBox(width: 10),
              Text('Todos', style: TextStyle(color: Colors.white)),
            ]),
          ),
          PopupMenuItem<String>(
            value: 'recetados',
            child: Row(children: [
              Icon(Icons.medication_outlined, size: 18, color: Colors.white70),
              SizedBox(width: 10),
              Text(
                'Recetados (${_recetadosIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ]),
          ),
          PopupMenuItem<String>(
            value: 'favoritos',
            child: Row(children: [
              Icon(Icons.favorite_border, size: 18, color: Colors.white70),
              SizedBox(width: 10),
              Text(
                'Favoritos (${_favoritosIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ]),
          ),
          const PopupMenuItem<String>(
            value: 'mas_usados',
            child: Row(children: [
              Icon(Icons.emoji_events_outlined,
                  size: 18, color: Colors.white70),
              SizedBox(width: 10),
              Text('Top 10', style: TextStyle(color: Colors.white)),
            ]),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_iconoFiltroActivo(), color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              _labelFiltroActivo(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.white54, size: 18),
          ]),
        ),
      ),
    );
  }

  // ── Helper para ítems del menú contextual ─────────────────────────────────
  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color color = Colors.white70, int badge = 0}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Icon(icon, color: color, size: 20),
          // ⚠️  Badge numérico — aparece solo si badge > 0
          if (badge > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontSize: 14)),
      ]),
    );
  }

  // ── Helpers de nivel ──────────────────────────────────────
  // ── Auto-inicializar campos faltantes en sonidos ────────────────────────
  // Solo inicializa campos faltantes — completamente en background, nunca bloquea la UI
  void _inicializarCamposSonido(String sonidoId, Map<String, dynamic> datos) {
    Map<String, dynamic> camposFaltantes = {};
    if (!datos.containsKey('total_usos')) camposFaltantes['total_usos'] = 0;
    if (!datos.containsKey('meta_donacion'))
      camposFaltantes['meta_donacion'] = 0;
    if (!datos.containsKey('donaciones_recibidas'))
      camposFaltantes['donaciones_recibidas'] = 0;
    if (!datos.containsKey('ensayos_abiertos'))
      camposFaltantes['ensayos_abiertos'] = false;
    if (!datos.containsKey('nivel_requerido'))
      camposFaltantes['nivel_requerido'] = '';
    if (camposFaltantes.isNotEmpty) {
      unawaited(FirebaseFirestore.instance
          .collection(BioConfig.colSonidos)
          .doc(sonidoId)
          .update(camposFaltantes)
          .catchError((_) {})); // silencioso — no bloquea la UI
    }
  }

  // ── Top 10 modal ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // ── Versión remota para Mi Cuenta ─────────────────────────────────────
    _remoteVersionLocal = widget.remoteVersion;
    if (_remoteVersionLocal == null) {
      VersionManager.check(BioConfig.version).then((r) {
        if (mounted && r.remote != null) {
          setState(() => _remoteVersionLocal = r.remote);
        }
      });
    }
    _cargarFavoritosYRecetados();
    _iniciarStreamSolicitudes();
    _sonidosFuture = _cargarSonidosConCache();
    _compraPanelFuture = _cargarDatosCompraPanel();
  }

  @override
  void didUpdateWidget(PantallaListaSonidos oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cuando _AppState termina _checkVersion y pasa _remoteVersion nuevo
    if (widget.remoteVersion != null &&
        widget.remoteVersion != _remoteVersionLocal) {
      setState(() => _remoteVersionLocal = widget.remoteVersion);
    }
  }

  // ── Stream de solicitudes pendientes (para badge del menú) ───────────────
  Future<void> _iniciarStreamSolicitudes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .get();
      final rol = (userDoc.data()?['rol'] ?? '').toString();
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection(BioConfig.colSolicitudesPrescripcion);
      if (rol != BioConfig.rolAdmin) {
        query = query.where('medico_id', isEqualTo: user.uid);
      }
      query = query.where('estado', isEqualTo: 'pendiente');
      _subSolicitudes = query.snapshots().listen((snap) {
        if (mounted) setState(() => _pendientesClinica = snap.docs.length);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _subSolicitudes?.cancel();
    _subFavoritos?.cancel();
    _subRecetados?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarFavoritosYRecetados() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _subFavoritos?.cancel();
    _subRecetados?.cancel();

    _subFavoritos = FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(user.uid)
        .collection(BioConfig.colFavoritos)
        .snapshots()
        .listen((favSnap) {
      final nuevosFavoritos = favSnap.docs.map((d) => d.id).toSet();
      if (!mounted || _mismosIds(_favoritosIds, nuevosFavoritos)) return;
      setState(() => _favoritosIds = nuevosFavoritos);
    }, onError: (_) {});

    _subRecetados = FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(user.uid)
        .collection(BioConfig.colAccesosSonidos)
        .where('aprobado', isEqualTo: true)
        .snapshots()
        .listen((recSnap) {
      final nuevosRecetados = recSnap.docs
          .where((d) => (d.data() as Map)['medico_id'] != null)
          .map((d) => d.id)
          .toSet();
      if (!mounted || _mismosIds(_recetadosIds, nuevosRecetados)) return;
      setState(() => _recetadosIds = nuevosRecetados);
    }, onError: (_) {});
  }

  Future<void> _recargarPantallaSonidos() async {
    BioConfig.invalidarCacheSonidos();
    final future = _cargarSonidosConCache();
    if (mounted) {
      setState(() => _sonidosFuture = future);
    }
    await _cargarFavoritosYRecetados();
    await future;
  }

  bool _pasaFiltro(String sonidoId, Map<String, dynamic> sonido) {
    // Filtro de texto
    if (_query.isNotEmpty) {
      final nombre = (sonido['Nombre'] ?? '').toString().toLowerCase();
      if (!nombre.contains(_query)) return false;
    }

    // ⚠️  Si el rol efectivo es 'user', solo puede ver sonidos que:
    //     1. Ya tienen acceso aprobado (recetados), O
    //     2. NO requieren prescripción (disponibles libremente)
    //     Esto evita que el user vea y solicite sonidos sin control del PS.
    final rolEfec =
        ViewAsManager().rolEfectivo(_uData['rol'] ?? BioConfig.rolUser);
    final tieneVinculoPs = _tieneVinculoPs(_uData);
    if (rolEfec == BioConfig.rolUser && tieneVinculoPs) {
      // Si ya tiene acceso aprobado → siempre visible
      if (_recetadosIds.contains(sonidoId)) {
        // continúa a filtros de categoría
      } else {
        // Sin acceso aprobado: solo visible si el sonido NO requiere prescripción
        final requiere = sonido['requiere_prescripcion'] as bool? ?? false;
        if (requiere) {
          // Mostrar de todas formas pero marcado como "solicitable"
          // Ocultarlo solo si el filtro activo es 'recetados'
          if (_filtroActivo == 'recetados') return false;
          // En vista 'todos', lo mostramos para que pueda solicitarlo
        }
      }
    }

    // Filtro por categoría
    switch (_filtroActivo) {
      case 'recetados':
        return _recetadosIds.contains(sonidoId);
      case 'favoritos':
        return _favoritosIds.contains(sonidoId);
      case 'mas_usados':
        return true;
      default:
        return true;
    }
  }

  // ── Carga Sonidos con caché de 5 min ────────────────────────────────────
  // Evita relanzar el stream de Sonidos cada vez que el árbol se reconstruye.
  // El caché se invalida al cambiar filtro 'mas_usados' o manualmente.
  Future<List<Map<String, dynamic>>> _cargarSonidosConCache() async {
    if (BioConfig.cacheSonidosValida) {
      // Reordenar si corresponde
      final cached = List<Map<String, dynamic>>.from(BioConfig.cacheSonidos!);
      if (_filtroActivo == 'mas_usados') {
        cached.sort((a, b) => ((b['total_usos'] as num?) ?? 0)
            .compareTo((a['total_usos'] as num?) ?? 0));
      }
      return cached;
    }
    final snap =
        await FirebaseFirestore.instance.collection(BioConfig.colSonidos).get();
    final datos = snap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['_id'] = d.id; // guardamos el id dentro del map
      return m;
    }).toList();
    BioConfig.guardarCacheSonidos(datos);
    if (_filtroActivo == 'mas_usados') {
      datos.sort((a, b) => ((b['total_usos'] as num?) ?? 0)
          .compareTo((a['total_usos'] as num?) ?? 0));
    }
    return datos;
  }

  // Versión del filtro que trabaja con Map en lugar de QueryDocumentSnapshot
  bool _pasaFiltroMap(String sonidoId, Map<String, dynamic> sonido) =>
      _pasaFiltro(sonidoId, sonido);

  // Badge helper para estado de sonidos
  Widget _badgeEstado(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(texto,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _colorNivel(String nivel) {
    if (nivel == BioConfig.nivelVip) return BioConfig.colorVip;
    if (nivel == BioConfig.nivelPro) return BioConfig.colorPro;
    return BioConfig.colorPrimario;
  }

  IconData _iconoNivel(String nivel) {
    if (nivel == BioConfig.nivelVip) return Icons.workspace_premium;
    if (nivel == BioConfig.nivelPro) return Icons.star;
    return Icons.person;
  }

  // ── Verificación de salto de nivel ───────────────────────
  Future<void> _verificarSaltoDeNivel(
      String uid, int nuevoHistorico, String nivelActual) async {
    String? nuevoNivel;
    int bonusHito = 0;
    if (nivelActual == BioConfig.nivelBasico &&
        nuevoHistorico >= BioConfig.umbralPro) {
      nuevoNivel = BioConfig.nivelPro;
      bonusHito = BioConfig.bonusHitoPro;
    } else if (nivelActual == BioConfig.nivelPro &&
        nuevoHistorico >= BioConfig.umbralVip) {
      nuevoNivel = BioConfig.nivelVip;
      bonusHito = BioConfig.bonusHitoVip;
    }
    if (nuevoNivel != null) {
      await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(uid)
          .update({
        BioConfig.campoNivel: nuevoNivel,
        BioConfig.campoTokens: FieldValue.increment(bonusHito),
        BioConfig.campoHistorico: FieldValue.increment(bonusHito),
      });
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconoNivel(nuevoNivel!),
                    size: 70, color: _colorNivel(nuevoNivel)),
                const SizedBox(height: 16),
                Text("¡SUBISTE A NIVEL $nuevoNivel!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _colorNivel(nuevoNivel),
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("🎁 +$bonusHito tokens de regalo por alcanzar este hito.",
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                if (nuevoNivel == BioConfig.nivelVip) ...[
                  const SizedBox(height: 8),
                  const Text(
                      "🔥 Ahora recibes +25% en TODAS tus compras de por vida.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.amber, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _colorNivel(nuevoNivel),
                      foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("¡GENIAL!",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  // ── Capa de seguridad 13 días ─────────────────────────────

  // ── Comisiones ────────────────────────────────────────────
  Future<void> _repartirComisiones(
      int tokensComprados, String compradorId) async {
    try {
      var docComprador = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(compradorId)
          .get();
      String? idL1 = docComprador.data()?[BioConfig.campoReferidoPor];
      if (idL1 != null && idL1 != BioConfig.codigoMaestro) {
        var qL1 = await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .where(BioConfig.campoCodigoPropio, isEqualTo: idL1)
            .get();
        if (qL1.docs.isNotEmpty) {
          String uidL1 = qL1.docs.first.id;
          int comL1 = (tokensComprados * BioConfig.comisionL1).toInt();
          await FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .doc(uidL1)
              .update({
            BioConfig.campoTokens: FieldValue.increment(comL1),
            BioConfig.campoHistorico: FieldValue.increment(comL1),
          });
          var dL1 = await FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .doc(uidL1)
              .get();
          int hL1 = (dL1.data()?[BioConfig.campoHistorico] ?? 0);
          await _verificarSaltoDeNivel(uidL1, hL1,
              dL1.data()?[BioConfig.campoNivel] ?? BioConfig.nivelBasico);

          String? idL2 = qL1.docs.first.data()[BioConfig.campoReferidoPor];
          if (idL2 != null && idL2 != BioConfig.codigoMaestro) {
            var qL2 = await FirebaseFirestore.instance
                .collection(BioConfig.colUsuarios)
                .where(BioConfig.campoCodigoPropio, isEqualTo: idL2)
                .get();
            if (qL2.docs.isNotEmpty) {
              String uidL2 = qL2.docs.first.id;
              int comL2 =
                  max(1, (tokensComprados * BioConfig.comisionL2).toInt());
              await FirebaseFirestore.instance
                  .collection(BioConfig.colUsuarios)
                  .doc(uidL2)
                  .update({
                BioConfig.campoTokens: FieldValue.increment(comL2),
                BioConfig.campoHistorico: FieldValue.increment(comL2),
              });
              var dL2 = await FirebaseFirestore.instance
                  .collection(BioConfig.colUsuarios)
                  .doc(uidL2)
                  .get();
              int hL2 = (dL2.data()?[BioConfig.campoHistorico] ?? 0);
              await _verificarSaltoDeNivel(uidL2, hL2,
                  dL2.data()?[BioConfig.campoNivel] ?? BioConfig.nivelBasico);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error comisiones: $e");
    }
  }

  // ── Compra con Mercado Pago ───────────────────────────────
  Future<String> _crearPreferenciaMercadoPago({
    required String titulo,
    required int cantidadTokens,
    required int precioCop,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No estas autenticado.");
    final idToken = await user.getIdToken(true);
    final mpResp = await http
        .post(
          Uri.parse(BioConfig.mpPreferenceUrl),
          headers: {
            "Authorization": "Bearer $idToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "titulo": titulo,
            "cantidad": cantidadTokens,
            "precio": precioCop,
            "uid": user.uid,
          }),
        )
        .timeout(const Duration(seconds: 20));
    debugPrint("[MP] Backend ${mpResp.statusCode}: ${mpResp.body}");
    if (mpResp.statusCode != 200 && mpResp.statusCode != 201) {
      throw Exception("MP backend ${mpResp.statusCode}: ${mpResp.body}");
    }
    final mpData = jsonDecode(mpResp.body) as Map<String, dynamic>;
    final urlPago = (mpData['init_point'] ?? mpData['sandbox_init_point'] ?? '')
        .toString()
        .trim();
    if (urlPago.isEmpty) {
      throw Exception("El servidor no devolvio enlace de pago.");
    }
    return urlPago;
  }

  Future<void> _abrirCheckoutMercadoPago(String urlPago) async {
    await custom_tabs.launchUrl(
      Uri.parse(urlPago),
      customTabsOptions: custom_tabs.CustomTabsOptions(
        colorSchemes: custom_tabs.CustomTabsColorSchemes.defaults(
          toolbarColor: BioConfig.colorPrimario,
        ),
        urlBarHidingEnabled: true,
        showTitle: false,
        closeButton: custom_tabs.CustomTabsCloseButton(
          icon: custom_tabs.CustomTabsCloseButtonIcons.back,
        ),
        animations: const custom_tabs.CustomTabsAnimations(
          startEnter: 'slide_up',
          startExit: 'android:anim/fade_out',
          endEnter: 'android:anim/fade_in',
          endExit: 'slide_down',
        ),
      ),
    );
  }

  Future<void> _ejecutarCompra(int cantidadTokens) async {
    try {
      // ⚠️  MP requiere Content-Type explícito y back_urls con HTTPS
      //     Los custom schemes (biofreq://) son rechazados por algunas cuentas MP
      final precioCop = (cantidadTokens * _valorTokenCopLista).round();
      debugPrint("[MP] Enviando request — $cantidadTokens tokens");
      final urlPago = await _crearPreferenciaMercadoPago(
        titulo: "Pack $cantidadTokens Tokens BioFreq",
        cantidadTokens: cantidadTokens,
        precioCop: precioCop,
      );
      // Abrir con Custom Tabs (integrado en la app, no sale al navegador)
      await custom_tabs.launchUrl(
        Uri.parse(urlPago),
        customTabsOptions: custom_tabs.CustomTabsOptions(
          colorSchemes: custom_tabs.CustomTabsColorSchemes.defaults(
            toolbarColor: BioConfig.colorPrimario,
          ),
          urlBarHidingEnabled: true,
          showTitle: false,
          closeButton: custom_tabs.CustomTabsCloseButton(
            icon: custom_tabs.CustomTabsCloseButtonIcons.back,
          ),
          animations: const custom_tabs.CustomTabsAnimations(
            startEnter: 'slide_up',
            startExit: 'android:anim/fade_out',
            endEnter: 'android:anim/fade_in',
            endExit: 'slide_down',
          ),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 6),
          content: Text(
              "Pago iniciado. Los tokens se acreditan cuando MercadoPago confirme el pago."),
        ));
      }
      _refrescarPanelCompra();
    } catch (e) {
      debugPrint("[MP Error] $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 8),
            content: Text("Error MP: $e")));
      }
    }
  }

  Future<void> _comprarPlanConTokens(String planKey, int precioTokens,
      {bool cerrarAlFinal = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dias = BioConfig.planesDias[planKey] ?? 0;
    if (dias <= 0) return;

    final userRef = FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(user.uid);

    try {
      final nuevoFin =
          await FirebaseFirestore.instance.runTransaction<DateTime>((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data() ?? <String, dynamic>{};
        final saldoActual = BioConfig.toInt(data[BioConfig.campoTokens]);
        if (saldoActual < precioTokens) {
          throw StateError('Saldo insuficiente');
        }

        final Timestamp? finTs =
            data[BioConfig.campoSuscripcionFin] as Timestamp?;
        final ahora = DateTime.now();
        final base = finTs != null && finTs.toDate().isAfter(ahora)
            ? finTs.toDate()
            : ahora;
        final nuevoFin = base.add(Duration(days: dias));

        tx.update(userRef, {
          BioConfig.campoTokens: FieldValue.increment(-precioTokens),
          BioConfig.campoSuscripcionActiva: true,
          BioConfig.campoSuscripcionFin: Timestamp.fromDate(nuevoFin),
          BioConfig.campoSuscripcionPlan: planKey,
        });

        return nuevoFin;
      });

      if (!mounted) return;
      if (cerrarAlFinal) {
        Navigator.pop(context);
      }
      _refrescarPanelCompra();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.teal,
        content: Text(
          'Plan ${BioConfig.planesNombre[planKey]} activo hasta ${_formatearFecha(nuevoFin)}',
        ),
      ));
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Saldo insuficiente para activar este plan'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error activando el plan: $e'),
      ));
    }
  }

  void _refrescarPanelCompra() {
    _compraPanelFuture = _cargarDatosCompraPanel();
    if (mounted) {
      setState(() {});
    }
  }

  Future<_CompraPanelData> _cargarDatosCompraPanel() async {
    final user = FirebaseAuth.instance.currentUser;
    String nivelActual = BioConfig.nivelBasico;
    int saldoActual = _saldo;
    bool planActiva = false;
    DateTime? planFin;
    Map<String, int> preciosPlanes = Map.from(BioConfig.planesDefecto);

    if (user != null) {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .get(),
        FirebaseFirestore.instance
            .collection(BioConfig.colConfiguracion)
            .doc(BioConfig.docPlanesSuscripcion)
            .get(),
      ]);
      final userDoc = results[0] as DocumentSnapshot;
      final planesDoc = results[1] as DocumentSnapshot;
      nivelActual = userDoc.data() != null
          ? (userDoc.data() as Map)['nivel'] ?? BioConfig.nivelBasico
          : BioConfig.nivelBasico;
      if (userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        saldoActual = BioConfig.toInt(data[BioConfig.campoTokens]);
        final finTs = data[BioConfig.campoSuscripcionFin] as Timestamp?;
        planFin = finTs?.toDate();
        planActiva =
            (data[BioConfig.campoSuscripcionActiva] as bool? ?? false) &&
                (planFin?.isAfter(DateTime.now()) ?? false);
      }
      if (planesDoc.exists && planesDoc.data() != null) {
        final data = planesDoc.data() as Map<String, dynamic>;
        preciosPlanes = {
          '15d': BioConfig.toInt(
              data['plan_15d'], BioConfig.planesDefecto['15d']!),
          '1m':
              BioConfig.toInt(data['plan_1m'], BioConfig.planesDefecto['1m']!),
          '6m':
              BioConfig.toInt(data['plan_6m'], BioConfig.planesDefecto['6m']!),
          '1a':
              BioConfig.toInt(data['plan_1a'], BioConfig.planesDefecto['1a']!),
        };
      }
    }

    return _CompraPanelData(
      nivelActual: nivelActual,
      saldoActual: saldoActual,
      planActiva: planActiva,
      planFin: planFin,
      preciosPlanes: preciosPlanes,
    );
  }

  Widget _buildComprasCoreTab() {
    return FutureBuilder<_CompraPanelData>(
      future: _compraPanelFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: CircularProgressIndicator(color: BioConfig.colorPrimario),
          );
        }
        final data = snap.data!;
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.tealAccent,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.white54,
                  labelStyle:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(text: 'Tokens'),
                    Tab(text: 'Planes'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(children: [
                        if (data.nivelActual == BioConfig.nivelPro)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Nivel PRO: compra 1.000 y recibe +200 tokens',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF7C3AED), fontSize: 11),
                            ),
                          )
                        else if (data.nivelActual == BioConfig.nivelVip)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Nivel VIP: +25% en toda compra',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFFD97706), fontSize: 11),
                            ),
                          ),
                        _btnPack(500, data.nivelActual, cerrarAntes: false),
                        _btnPack(1000, data.nivelActual, cerrarAntes: false),
                        _btnPack(5000, data.nivelActual, cerrarAntes: false),
                      ]),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.planActiva && data.planFin != null
                                    ? 'Plan activo hasta ${_formatearFecha(data.planFin!)}'
                                    : 'Activa acceso ilimitado por tiempo',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Saldo actual: ${data.saldoActual} tokens',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ...BioConfig.planesNombre.entries.map((entry) {
                          final key = entry.key;
                          final precio = data.preciosPlanes[key] ??
                              BioConfig.planesDefecto[key]!;
                          final dias = BioConfig.planesDias[key] ?? 0;
                          return ListTile(
                            leading: const Icon(Icons.all_inclusive,
                                color: Colors.tealAccent),
                            title: Text(entry.value,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              '$dias dias · $precio tokens',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                size: 15, color: Colors.tealAccent),
                            onTap: () => _comprarPlanConTokens(
                              key,
                              precio,
                              cerrarAlFinal: false,
                            ),
                          );
                        }),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirModalCompra() async {
    final data = await _cargarDatosCompraPanel();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10)),
              child: const TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                    color: Colors.tealAccent,
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white54,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'Tokens'),
                  Tab(text: 'Planes'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 420,
              child: TabBarView(children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(children: [
                    if (data.nivelActual == BioConfig.nivelPro)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                            'Nivel PRO: compra 1.000 y recibe +200 tokens',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF7C3AED), fontSize: 11)),
                      )
                    else if (data.nivelActual == BioConfig.nivelVip)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFFD97706).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('Nivel VIP: +25% en toda compra',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFFD97706), fontSize: 11)),
                      ),
                    _btnPack(500, data.nivelActual, cerrarAntes: false),
                    _btnPack(1000, data.nivelActual, cerrarAntes: false),
                    _btnPack(5000, data.nivelActual, cerrarAntes: false),
                  ]),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.planActiva && data.planFin != null
                                ? 'Plan activo hasta ${_formatearFecha(data.planFin!)}'
                                : 'Activa acceso ilimitado por tiempo',
                            style: const TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saldo actual: ${data.saldoActual} tokens',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ...BioConfig.planesNombre.entries.map((entry) {
                      final key = entry.key;
                      final precio = data.preciosPlanes[key] ??
                          BioConfig.planesDefecto[key]!;
                      final dias = BioConfig.planesDias[key] ?? 0;
                      return ListTile(
                        leading: const Icon(Icons.all_inclusive,
                            color: Colors.tealAccent),
                        title: Text(entry.value,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          '$dias dias · $precio tokens',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 15, color: Colors.tealAccent),
                        onTap: () => _comprarPlanConTokens(
                          key,
                          precio,
                          cerrarAlFinal: false,
                        ),
                      );
                    }),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _abrirModalCompraLegacy() async {
    final user = FirebaseAuth.instance.currentUser;
    String nivelActual = BioConfig.nivelBasico;

    if (user != null) {
      // Cargar nivel del usuario y precios de planes en paralelo
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .get(),
      ]);
      final userDoc = results[0] as DocumentSnapshot;
      nivelActual = userDoc.data() != null
          ? (userDoc.data() as Map)['nivel'] ?? BioConfig.nivelBasico
          : BioConfig.nivelBasico;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DefaultTabController(
        length: 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10)),
              child: const TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                    color: Colors.tealAccent,
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white54,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: '💰 Tokens'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 320,
              child: TabBarView(children: [
                // ── Tab 1: Paquetes de tokens ─────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(children: [
                    if (nivelActual == BioConfig.nivelPro)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                            '⭐ Nivel PRO: compra 1.000 y recibe +200 tokens',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF7C3AED), fontSize: 11)),
                      )
                    else if (nivelActual == BioConfig.nivelVip)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFFD97706).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('👑 Nivel VIP: +25% en toda compra',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFFD97706), fontSize: 11)),
                      ),
                    _btnPack(500, nivelActual),
                    _btnPack(1000, nivelActual),
                    _btnPack(5000, nivelActual),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _btnPack(int tokens, String nivel, {bool cerrarAntes = true}) {
    int totalReal = tokens;
    String? bonusLabel;
    final int precioCop = (tokens * _valorTokenCopLista).round();
    if (nivel == BioConfig.nivelPro && tokens == 1000) {
      totalReal += BioConfig.bonusCompraPro;
      bonusLabel = "+${BioConfig.bonusCompraPro} bonus PRO";
    } else if (nivel == BioConfig.nivelVip) {
      int bonusPct = (tokens * BioConfig.bonusPorcentajeVip).toInt();
      totalReal += bonusPct;
      bonusLabel = "+$bonusPct (25%)";
      if (tokens == 5000) {
        totalReal += BioConfig.bonusCompraVip;
        bonusLabel = "+$bonusPct (25%) +${BioConfig.bonusCompraVip} VIP";
      }
    }
    return ListTile(
      leading: const Icon(Icons.token, color: Colors.amber),
      title: Row(children: [
        Text("$tokens TOKENS", style: const TextStyle(color: Colors.white)),
        if (bonusLabel != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8)),
            child: Text("= $totalReal ✨",
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
      subtitle: Text(
          "${_formatearCopEntero(precioCop)} COP${bonusLabel != null ? ' · $bonusLabel' : ''}",
          style: const TextStyle(fontSize: 11)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 15, color: Colors.cyan),
      onTap: () {
        if (cerrarAntes) {
          Navigator.pop(context);
        }
        _ejecutarCompra(tokens);
      },
    );
  }

  // ── Formateador de fecha/hora sin paquetes externos ──────
  String _formatearFecha(DateTime dt) {
    final mes = dt.month.toString().padLeft(2, '0');
    final dia = dt.day.toString().padLeft(2, '0');
    final anio = dt.year.toString();
    return "$mes/$dia/$anio";
  }

  String _formatearHora(DateTime dt) {
    int h = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return "${h.toString().padLeft(2, '0')}:$min $ampm";
  }

  // ── Panel de referidos con 2 tabs ────────────────────────
  // ── Abrir panel de transferencia (solo PS) ──────────────────────────────
  void _abrirTransferencia(String emisorUid) {
    final rolReal = _uData['rol'] ?? BioConfig.rolUser;
    final rol = ViewAsManager().rolEfectivo(rolReal);
    if (rol != BioConfig.rolPS && rol != BioConfig.rolAdmin) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => TransferenciaPSModal(
        emisorUid: emisorUid,
        emisorNombre: _uData['nombre'] ?? '',
        saldoActual: _saldo,
        onTransferida: () => setState(() {}),
      ),
    );
  }

  void _mostrarPanelReferidos(
    String miCodigo,
    String miUid, {
    String miRol = BioConfig.rolUser,
    bool puedeCompartir = false,
    int? maxInvitados,
    int invitadosActuales = 0,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final esCompartible = puedeCompartir;
        return DefaultTabController(
          length: esCompartible ? 3 : 2,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.80,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              // ── Código compartible ───────────────────────────────
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: BioConfig.colorPrimario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BioConfig.colorPrimario)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Comparte este código con tus amigos 👇",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(miCodigo,
                              style: const TextStyle(
                                  color: Colors.cyan,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                        ]),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.cyan),
                      tooltip: "Copiar código",
                      onPressed: () async {
                        // Copiar al portapapeles de verdad
                        await Clipboard.setData(ClipboardData(text: miCodigo));
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Código $miCodigo copiado 📋"),
                            action: SnackBarAction(
                                label: "OK",
                                textColor: Colors.cyan,
                                onPressed: () {}),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (esCompartible)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups_2_outlined,
                        color: BioConfig.colorPrimario,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          maxInvitados == null
                              ? 'Invitaciones activas sin limite configurado.'
                              : 'Referidos usados: $invitadosActuales / $maxInvitados',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              // ── Tabs ─────────────────────────────────────────────
              TabBar(
                tabs: [
                  const Tab(text: "MI CÓDIGO"),
                  const Tab(text: "AMIGOS REFERIDOS"),
                  if (esCompartible)
                    Tab(icon: Icon(Icons.qr_code_2, size: 16), text: "MI QR"),
                ],
                indicatorColor: BioConfig.colorPrimario,
                labelColor: BioConfig.colorPrimario,
                unselectedLabelColor: Colors.grey,
              ),
              Expanded(
                child: TabBarView(children: [
                  // ── TAB 1: Info del código ───────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("¿Cómo funciona?",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 12),
                        _infoReferido(Icons.person_add, "Comparte tu código",
                            "Cuando alguien se registra con tu código, queda vinculado a ti."),
                        _infoReferido(Icons.monetization_on, "Ganas comisiones",
                            "Recibes el 10% de los tokens que compren tus referidos directos."),
                        _infoReferido(Icons.account_tree, "Red de 2 niveles",
                            "También recibes el 1% de los tokens que compren los referidos de tus referidos."),
                        _infoReferido(Icons.workspace_premium, "Sube de nivel",
                            "Entre más tokens acumules, subes de BÁSICO → PRO → VIP con beneficios mayores."),
                      ],
                    ),
                  ),
                  // ── TAB 2: Amigos referidos ──────────────────────
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection(BioConfig.colUsuarios)
                        .where(BioConfig.campoReferidoPor, isEqualTo: miCodigo)
                        .get(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(30),
                            child: Text(
                              "Aún no tienes amigos referidos.\n\nComparte tu código para ganar comisiones 🚀",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                        );
                      }
                      final amigos = snap.data!.docs;
                      // Calculamos totales
                      int totalAmigos = amigos.length;
                      int totalTokensGenerados = 0;
                      for (var a in amigos) {
                        var d = a.data() as Map<String, dynamic>;
                        int hist = d[BioConfig.campoHistorico] ?? 0;
                        totalTokensGenerados +=
                            (hist * BioConfig.comisionL1).toInt();
                      }
                      return Column(children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: amigos.length,
                            itemBuilder: (_, i) {
                              var d = amigos[i].data() as Map<String, dynamic>;
                              String nombreAmigo = d['nombre'] ?? "Usuario";
                              String codAmigo =
                                  d[BioConfig.campoCodigoPropio] ?? "---";
                              int histAmigo = d[BioConfig.campoHistorico] ?? 0;
                              int tokensGenerados =
                                  (histAmigo * BioConfig.comisionL1).toInt();
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: BioConfig.colorPrimario
                                      .withValues(alpha: 0.2),
                                  child: Text(
                                      nombreAmigo.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                          color: BioConfig.colorPrimario,
                                          fontWeight: FontWeight.bold)),
                                ),
                                title: Text(nombreAmigo,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)),
                                subtitle: Text("Cód: $codAmigo",
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("+$tokensGenerados",
                                        style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const Text("tokens",
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 10)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // ── Totalizador ──────────────────────────────
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.4))),
                          child: Column(children: [
                            Text(
                              "Tienes $totalAmigos ${totalAmigos == 1 ? 'amigo' : 'amigos'} que usan BioFreq",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "y te han representado $totalTokensGenerados Tokens en total 🏆",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ]),
                        ),
                      ]);
                    },
                  ),

                  // ── TAB 3: QR de invitación ──────────────────────────────
                  if (esCompartible)
                    Builder(builder: (ctx) {
                      const String apkBase =
                          'https://drive.google.com/uc?export=download&id=1D11vGNw4fFdcdee9Sy6cPjdhtnx5y22u';
                      final String linkConCodigo = '$apkBase&ref=$miCodigo';
                      final String mensajeCompartir =
                          '🎵 Te invito a BioFreq — terapias bioacústicas\n\n'
                          '👉 Descarga aquí:\n$linkConCodigo\n\n'
                          '📋 Código de acceso: $miCodigo';
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          const Text('Comparte tu QR de invitación',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 6),
                          const Text('Escanear abre la descarga directamente',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          const SizedBox(height: 20),
                          // QR
                          Center(
                              child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme().qrBackground,
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                          )),
                          const SizedBox(height: 16),
                          // Código texto
                          GestureDetector(
                            onTap: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: miCodigo));
                              if (ctx.mounted)
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Código copiado 📋')));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.cyan.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(miCodigo,
                                        style: const TextStyle(
                                            color: Colors.cyan,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            letterSpacing: 3)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.copy,
                                        color: Colors.cyan, size: 14),
                                  ]),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Link copiable
                          GestureDetector(
                            onTap: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: linkConCodigo));
                              if (ctx.mounted)
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Link copiado 🔗')));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(children: [
                                const Icon(Icons.link,
                                    color: Colors.white38, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(linkConCodigo,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10))),
                                const Icon(Icons.copy,
                                    color: Colors.white24, size: 12),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Botón compartir
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: BioConfig.colorPrimario,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14)),
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: const Text('Compartir invitación',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => Share.share(mensajeCompartir,
                                  subject: 'Te invito a BioFreq 🎵'),
                            ),
                          ),
                        ]),
                      );
                    }),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _infoReferido(IconData icono, String titulo, String desc) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, color: BioConfig.colorPrimario, size: 20),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
      ]),
    );
  }

  // ── Historial de reproducciones ───────────────────────────
  // ── Navegar a un sonido desde historial/favoritos ─────────────────────────
  Future<void> _navegarASonido(String sonidoId) async {
    final saldoLocal = _saldo; // capturar antes del gap async
    final nivelLocal = _uData[BioConfig.campoNivel] ?? BioConfig.nivelBasico;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(BioConfig.colSonidos)
          .doc(sonidoId)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>;
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaSonidoDetalle(
                sonidoId: sonidoId,
                sonidoData: data,
                saldoActual: saldoLocal,
                nivelUsuario: nivelLocal,
                rolUsuario: _uData['rol'] ?? BioConfig.rolUser,
                suscripcionActiva: _tienePlanActivo),
          ));
    } catch (e) {
      debugPrint("Error navegando a sonido: $e");
    }
  }

  // ── Solicitar prescripción al médico ─────────────────────────────────────────
  // origen: 'manual'
  void _mostrarSolicitudPrescripcion(
      String sonidoId, String nombreSonido, String medicoId, String pacienteId,
      {String origen = 'manual', String alertaId = ''}) async {
    // Verificar si ya existe solicitud pendiente
    final q = await FirebaseFirestore.instance
        .collection(BioConfig.colSolicitudesPrescripcion)
        .where('paciente_id', isEqualTo: pacienteId)
        .where('sonido_id', isEqualTo: sonidoId)
        .where('estado', isEqualTo: 'pendiente')
        .get();
    if (q.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                '⏳ Ya enviaste esta solicitud. Espera la aprobación de tu médico.')));
      }
      return;
    }
    // Verificar si ya tiene aprobación
    final acceso = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(pacienteId)
        .collection(BioConfig.colAccesosSonidos)
        .doc(sonidoId)
        .get();
    if (acceso.exists && acceso.data()?['aprobado'] == true) {
      // Ya tiene acceso, ir al sonido
      _navegarASonido(sonidoId);
      return;
    }
    // Obtener nombre del médico
    String nombreMedico = 'tu médico';
    try {
      final mDoc = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(medicoId)
          .get();
      nombreMedico = mDoc.data()?['nombre'] ?? 'tu médico';
    } catch (_) {}

    if (!mounted) return;
    // Controller para el motivo (solo en solicitudes manuales)
    final motivoCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx2, setModalState) => Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(sheetCtx2).viewInsets.bottom + 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabecera ──────────────────────────────────────────
                Row(children: [
                  Icon(Icons.medical_services_outlined,
                      color: Colors.tealAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('Solicitar: "$nombreSonido"',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 6),
                Text('Tu solicitud será revisada por $nombreMedico.',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 16),

                // ── Si es manual: campo de síntoma ──────────────────
                if (origen == 'manual') ...[
                  const Text('Describe brevemente tu motivo',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: motivoCtrl,
                    maxLength: 120,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ej: me duele la cabeza, tengo migraña...',
                      hintStyle:
                          const TextStyle(color: Colors.white24, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      counterStyle:
                          const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Enviar solicitud',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      try {
                        await FirebaseFirestore.instance
                            .collection(BioConfig.colSolicitudesPrescripcion)
                            .add({
                          'paciente_id': pacienteId,
                          'medico_id': medicoId,
                          'sonido_id': sonidoId,
                          'sonido_nombre': nombreSonido,
                          'paciente_nombre': _uData['nombre'] ?? '',
                          'estado': 'pendiente',
                          'fecha': FieldValue.serverTimestamp(),
                          'origen': origen,
                          if (alertaId.isNotEmpty) 'alerta_id': alertaId,
                          if (origen == 'manual' &&
                              motivoCtrl.text.trim().isNotEmpty)
                            'motivo_paciente': motivoCtrl.text.trim(),
                        });
                        // Notificar al PS
                        await BioNotif.solicitudRecibidaPS(
                            medicoId,
                            _uData['nombre'] ?? 'Un paciente',
                            nombreSonido,
                            origen);
                        await BioNotif.adminSolicitudReceta(
                          paciente: _uData['nombre'] ?? 'Un paciente',
                          sonido: nombreSonido,
                          psNombre: nombreMedico,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('✅ Solicitud enviada. '
                                '$nombreMedico la revisará pronto.'),
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  // ── Toggle favorito ─────────────────────────────────────────────────────────
  Future<void> _toggleFavorito(String uid, String sonidoId) async {
    final ref = FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .doc(uid)
        .collection(BioConfig.colFavoritos)
        .doc(sonidoId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref
          .set({'fecha': FieldValue.serverTimestamp(), 'sonido_id': sonidoId});
    }
  }

  // ── Historial + Favoritos ───────────────────────────────────────────────────
  void _mostrarHistorial(String uid) {
    final rol = _uData['rol'] ?? BioConfig.rolUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DefaultTabController(
        length: 3,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.97,
          builder: (_, ctrl) => Column(children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            const Text('MI HISTORIAL',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              // ⚠️  Badge en "Solicitudes": cuenta solo las pendientes del PS.
              //     Se actualiza en tiempo real sin recargar la pantalla.
              stream: FirebaseFirestore.instance
                  .collection(BioConfig.colSolicitudesPrescripcion)
                  .where('medico_id', isEqualTo: uid)
                  .where('estado', isEqualTo: 'pendiente')
                  .snapshots(),
              builder: (_, snapSol) {
                final nSolicitudes = snapSol.data?.docs.length ?? 0;
                Widget tabSolicitudes = Tab(
                  child: Stack(clipBehavior: Clip.none, children: [
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.assignment, size: 18),
                      const SizedBox(height: 2),
                      const Text('Solicitudes', style: TextStyle(fontSize: 10)),
                    ]),
                    if (nSolicitudes > 0)
                      Positioned(
                        right: -12,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$nSolicitudes',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ]),
                );
                return TabBar(
                  indicatorColor: BioConfig.colorPrimario,
                  labelColor: BioConfig.colorPrimario,
                  unselectedLabelColor: Colors.white38,
                  tabs: [
                    const Tab(
                        icon: Icon(Icons.graphic_eq, size: 18),
                        text: 'Sonidos'),
                    const Tab(
                        icon: Icon(Icons.swap_horiz, size: 18),
                        text: 'Finanzas'),
                    tabSolicitudes,
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(children: [
                // ── Tab 1: Historial de Sonidos ───────────────────────────
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(BioConfig.colUsuarios)
                      .doc(uid)
                      .collection(BioConfig.colAccesosSonidos)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData)
                      return Center(
                          child: CircularProgressIndicator(
                              color: BioConfig.colorPrimario));
                    if (snap.data!.docs.isEmpty)
                      return const Center(
                          child: Text(
                              'Aún no has reproducido ninguna frecuencia.',
                              style: TextStyle(color: Colors.white38)));
                    return ListView.builder(
                      controller: ctrl,
                      itemCount: snap.data!.docs.length,
                      itemBuilder: (_, i) {
                        var d =
                            snap.data!.docs[i].data() as Map<String, dynamic>;
                        String sonidoId = snap.data!.docs[i].id;
                        int ciclos = BioConfig.toInt(d['ciclos_completados']);
                        DateTime? fecha = d['ultimo_uso'] != null
                            ? (d['ultimo_uso'] as Timestamp).toDate()
                            : null;
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection(BioConfig.colSonidos)
                              .doc(sonidoId)
                              .get(),
                          builder: (_, sSnap) {
                            String nombre = sonidoId;
                            if (sSnap.hasData && sSnap.data!.exists) {
                              nombre = (sSnap.data!.data() as Map)['Nombre'] ??
                                  sonidoId;
                            }
                            return ListTile(
                              leading: Icon(Icons.history,
                                  color: BioConfig.colorPrimario),
                              title: Text(nombre,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  fecha != null
                                      ? 'Último uso: ${_formatearFecha(fecha)}  •  Ciclos: $ciclos'
                                      : 'Ciclos: $ciclos',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                              trailing: StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection(BioConfig.colUsuarios)
                                    .doc(uid)
                                    .collection(BioConfig.colFavoritos)
                                    .doc(sonidoId)
                                    .snapshots(),
                                builder: (_, favSnap) {
                                  bool esFav =
                                      favSnap.hasData && favSnap.data!.exists;
                                  return GestureDetector(
                                    onTap: () => _toggleFavorito(uid, sonidoId),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                          esFav
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: esFav
                                              ? Colors.amber
                                              : Colors.white38,
                                          size: 24),
                                    ),
                                  );
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _navegarASonido(sonidoId);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                // ── Tab 2: Finanzas / Transferencias ─────────────────────
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(BioConfig.colTransacciones)
                      .where('participantes', arrayContains: uid)
                      .orderBy('fecha', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData)
                      return Center(
                          child: CircularProgressIndicator(
                              color: BioConfig.colorPrimario));
                    if (snap.data!.docs.isEmpty)
                      return Center(
                          child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.swap_horiz,
                                  color: Colors.white12, size: 56),
                              const SizedBox(height: 16),
                              const Text('Sin movimientos financieros',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              if (rol == BioConfig.rolPS) ...[
                                SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: BioConfig.colorPrimario,
                                      foregroundColor: Colors.black),
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Transferir tokens'),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _abrirTransferencia(uid);
                                  },
                                ),
                              ],
                            ]),
                      ));
                    return Column(children: [
                      if (rol == BioConfig.rolPS)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: BioConfig.colorPrimario,
                                  foregroundColor: Colors.black),
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Nueva transferencia'),
                              onPressed: () {
                                Navigator.pop(context);
                                _abrirTransferencia(uid);
                              },
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          controller: ctrl,
                          itemCount: snap.data!.docs.length,
                          itemBuilder: (_, i) {
                            final d = snap.data!.docs[i].data()
                                as Map<String, dynamic>;
                            final esEmisor = d['emisor_id'] == uid;
                            final monto = d['monto'] as int;
                            final recargo = d['recargo'] as int? ?? 0;
                            final fecha = d['fecha'] != null
                                ? (d['fecha'] as Timestamp).toDate()
                                : null;
                            final estado = d['estado'] ?? 'completada';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    (esEmisor ? Colors.red : Colors.green)
                                        .withValues(alpha: 0.15),
                                child: Icon(
                                    esEmisor
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: esEmisor
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                    size: 20),
                              ),
                              title: Text(
                                  esEmisor
                                      ? 'Enviado a ${d['receptor_nombre'] ?? '?'}'
                                      : 'Recibido de ${d['emisor_nombre'] ?? '?'}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  fecha != null ? _formatearFecha(fecha) : '',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${esEmisor ? "-" : "+"}$monto',
                                      style: TextStyle(
                                          color: esEmisor
                                              ? Colors.redAccent
                                              : Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  if (esEmisor && recargo > 0)
                                    Text('recargo: $recargo',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10)),
                                  Text(estado,
                                      style: TextStyle(
                                          color: estado == 'completada'
                                              ? Colors.green
                                              : Colors.orange,
                                          fontSize: 9)),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (_) => ReciboDigital(transaccion: d),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ]);
                  },
                ),

                // ── Tab 3: Solicitudes de Pacientes ──────────────────────
                StreamBuilder<QuerySnapshot>(
                  stream: rol == BioConfig.rolPS
                      ? FirebaseFirestore.instance
                          .collection(BioConfig.colSolicitudesPrescripcion)
                          .where('medico_id', isEqualTo: uid)
                          .orderBy('fecha', descending: true)
                          .limit(30)
                          .snapshots()
                      : FirebaseFirestore.instance
                          .collection(BioConfig.colSolicitudesPrescripcion)
                          .where('paciente_id', isEqualTo: uid)
                          .orderBy('fecha', descending: true)
                          .limit(30)
                          .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData)
                      return Center(
                          child: CircularProgressIndicator(
                              color: BioConfig.colorPrimario));
                    if (snap.data!.docs.isEmpty)
                      return Center(
                          child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(children: [
                          const Icon(Icons.assignment,
                              color: Colors.white12, size: 56),
                          const SizedBox(height: 16),
                          Text(
                              rol == BioConfig.rolPS
                                  ? 'Tus pacientes aún no han enviado solicitudes.'
                                  : 'No has enviado solicitudes a tu médico.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 14)),
                        ]),
                      ));
                    return ListView.builder(
                      controller: ctrl,
                      itemCount: snap.data!.docs.length,
                      itemBuilder: (_, i) {
                        final d =
                            snap.data!.docs[i].data() as Map<String, dynamic>;
                        final estado = d['estado'] ?? 'pendiente';
                        final Color estadoColor = estado == 'aprobada'
                            ? Colors.green
                            : estado == 'rechazada'
                                ? Colors.red
                                : Colors.orange;
                        final fecha = d['fecha'] != null
                            ? (d['fecha'] as Timestamp).toDate()
                            : null;
                        return ListTile(
                          leading: Icon(Icons.assignment,
                              color: estadoColor, size: 22),
                          title: Text(
                              rol == BioConfig.rolPS
                                  ? (d['paciente_nombre'] ?? 'Paciente')
                                  : (d['nombre_sonido'] ?? 'Solicitud'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${d['nombre_sonido'] ?? ''}'
                              '${fecha != null ? '  •  ${_formatearFecha(fecha)}' : ''}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: estadoColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: estadoColor.withValues(alpha: 0.4))),
                            child: Text(estado.toUpperCase(),
                                style: TextStyle(
                                    color: estadoColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ListenableBuilder(
        listenable: Listenable.merge([AppTheme(), ViewAsManager()]),
        builder: (context, _) {
          final ahora =
              DateTime.now(); // dentro del builder para rebuild correcto
          final theme = AppTheme();
          final viewAs = ViewAsManager();
          final tieneImagen = theme.imagenFondo.isNotEmpty;
          // Rol efectivo: simulado si ViewAs activo, real si no
          final rolReal = _uData['rol'] ?? BioConfig.rolUser;
          final rolEfectivo = viewAs.rolEfectivo(rolReal);

          return Scaffold(
            backgroundColor: theme.colorFondo,
            appBar: AppBar(
              backgroundColor: viewAs.estaActivo
                  ? Colors.deepOrange.shade900
                  : theme.colorFondo,
              title: viewAs.estaActivo
                  ? Row(children: [
                      const Icon(Icons.visibility,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 6),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "Viendo como ${viewAs.rolSimulado!.toUpperCase()}",
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Text("Rol real: ${rolReal.toUpperCase()}",
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 10)),
                          ]),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => viewAs.desactivar(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.5)),
                          ),
                          child: const Text("✕ Salir",
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ])
                  : Text("BIOFREQ v${BioConfig.versionDisplay}",
                      style: TextStyle(
                          color: BioConfig.colorPrimario,
                          fontWeight: FontWeight.bold)),
              actions: [
                // ── Menú contextual ────────────────────────────────────
                StreamBuilder<QuerySnapshot>(
                  stream: (rolEfectivo == BioConfig.rolPS ||
                          rolReal == BioConfig.rolAdmin)
                      ? (rolReal == BioConfig.rolAdmin
                          ? FirebaseFirestore.instance
                              .collection(BioConfig.colSolicitudesPrescripcion)
                              .where('estado', isEqualTo: 'pendiente')
                              .snapshots()
                          : FirebaseFirestore.instance
                              .collection(BioConfig.colSolicitudesPrescripcion)
                              .where('medico_id',
                                  isEqualTo:
                                      FirebaseAuth.instance.currentUser?.uid)
                              .where('estado', isEqualTo: 'pendiente')
                              .snapshots())
                      : const Stream.empty(),
                  builder: (_, badgeSnap) {
                    final int pendientes =
                        badgeSnap.hasData ? badgeSnap.data!.docs.length : 0;
                    final bool puedeCompartirCodigoMenu =
                        _puedeInvitarReferidos ||
                            rolEfectivo != BioConfig.rolUser;
                    return Stack(children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.menu, color: Colors.white70),
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        onSelected: (value) async {
                          switch (value) {
                            case 'cuenta':
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PantallaMiCuenta(
                                          uid: user!.uid,
                                          uData: _uData,
                                          remoteVersion: _remoteVersionLocal)));
                              break;
                            case 'historial':
                              _mostrarHistorial(user!.uid);
                              break;
                            case 'cobrar':
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const Scaffold(
                                          body: Center(
                                              child: Text(
                                                  'Retiros próximamente')))));
                              break;
                            case 'tokens':
                              _abrirModalCompra();
                              break;
                            case 'referidos':
                              _mostrarPanelReferidos(
                                _codigo,
                                user!.uid,
                                miRol: rolEfectivo,
                                puedeCompartir: puedeCompartirCodigoMenu,
                                maxInvitados: _maxInvitadosReferidos,
                                invitadosActuales: _referidosDirectosActuales,
                              );
                              break;
                            case 'correo':
                              final uri = Uri.parse(
                                  'mailto:biofreq.app@gmail.com?subject=Contacto%20BioFreq');
                              bool abierto = false;
                              try {
                                abierto = await canLaunchUrl(uri) &&
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                              } catch (_) {}
                              if (!abierto && mounted) {
                                // Fallback: copiar dirección al portapapeles
                                await Clipboard.setData(const ClipboardData(
                                    text: 'biofreq.app@gmail.com'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "No se encontró app de correo. "
                                        "📋 biofreq.app@gmail.com copiado al portapapeles."),
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                              break;
                            case 'clinica':
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PantallaClinicaDigital(
                                          medicoId: user!.uid,
                                          medicoNombre: user.displayName ?? '',
                                          modoAdmin:
                                              rolReal == BioConfig.rolAdmin)));
                              break;
                            case 'admin':
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const PantallaAdmin()));
                              break;
                            case 'marketing':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PantallaMarketing(
                                    modoAdmin: rolReal == BioConfig.rolAdmin,
                                  ),
                                ),
                              );
                              break;
                            case 'salir':
                              try {
                                // Limpiar caches estáticos antes de cerrar sesión
                                _PantallaSonidoDetalleState._accesoCache
                                    .clear();
                                _PantallaSonidoDetalleState
                                    ._valorTokenCacheByUid
                                    .clear();
                                BioConfig.invalidarCacheSonidos();
                                // GoogleSignIn puede fallar si no se autenticó por Google
                                await GoogleSignIn()
                                    .signOut()
                                    .catchError((_) => null);
                                await FirebaseAuth.instance.signOut();
                              } catch (e) {
                                debugPrint('[Logout] Error: $e');
                                try {
                                  await FirebaseAuth.instance.signOut();
                                } catch (_) {}
                              }
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          _menuItem(
                              'cuenta', Icons.person_outline, 'Mi Cuenta'),
                          _menuItem(
                              'historial', Icons.history, 'Historial de uso'),
                          if (BioConfig.puedeVerMenuClinica(rolEfectivo) ||
                              rolReal == BioConfig.rolAdmin)
                            _menuItem('clinica', Icons.local_hospital,
                                'Consultorio Virtual',
                                color: Colors.tealAccent,
                                badge: _pendientesClinica),
                          if (rolEfectivo == BioConfig.rolPS ||
                              rolEfectivo == BioConfig.rolAdmin ||
                              rolEfectivo == BioConfig.rolTester ||
                              rolReal == BioConfig.rolAdmin)
                            _menuItem('cobrar', Icons.account_balance_wallet,
                                'Cobrar'),
                          _menuItem(
                              'referidos', Icons.qr_code, 'Mi código referido'),
                          if (BioConfig.puedeVerMenuMarketing(rolEfectivo) ||
                              rolReal == BioConfig.rolAdmin)
                            _menuItem('marketing', Icons.campaign_outlined,
                                'Marketing',
                                color: Colors.orangeAccent),
                          _menuItem('tokens', Icons.toll, 'Comprar tokens'),
                          const PopupMenuDivider(),
                          _menuItem('correo', Icons.email_outlined,
                              'Contactar a BioFreq',
                              color: Colors.white54),
                          // Panel Admin: solo visible con rol REAL admin (no simulado)
                          if (rolReal == BioConfig.rolAdmin) ...[
                            const PopupMenuDivider(),
                            _menuItem('admin', Icons.admin_panel_settings,
                                'Panel Admin',
                                color: Colors.purpleAccent),
                          ],
                          _menuItem('salir', Icons.logout, 'Cerrar sesión',
                              color: Colors.redAccent),
                          // ── Info tokens (solo lectura, no es acción) ──────
                          PopupMenuItem<String>(
                            enabled: false,
                            height: 36,
                            child: Builder(builder: (_) {
                              final String nv = _uData[BioConfig.campoNivel] ??
                                  BioConfig.nivelBasico;
                              final Color cv = _colorNivel(nv);
                              return Row(children: [
                                Icon(Icons.toll, color: cv, size: 14),
                                const SizedBox(width: 8),
                                Text('$_saldo tokens',
                                    style: TextStyle(
                                        color: cv,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                Icon(_iconoNivel(nv), size: 12, color: cv),
                                const SizedBox(width: 3),
                                Text(nv,
                                    style: TextStyle(
                                        color: cv.withValues(alpha: 0.7),
                                        fontSize: 11)),
                              ]);
                            }),
                          ),
                        ],
                      ),
                      // Badge rojo si hay solicitudes pendientes (solo PS)
                      if (pendientes > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle),
                          ),
                        ),
                    ]);
                  },
                ),
              ],
            ),
            body: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(BioConfig.colUsuarios)
                  .doc(user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var uData = snapshot.data!.data() as Map<String, dynamic>;
                if (BioConfig.cuentaBaneada(uData)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Tu cuenta fue suspendida. Contacta a BioFreq.'),
                      ),
                    );
                    await FirebaseAuth.instance.signOut();
                  });
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Cuenta suspendida. Contacta a BioFreq para mas informacion.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  );
                }
                _sincronizarPsAutomatico(user?.uid, uData);
                _sincronizarSegmentoMacro(user?.uid, uData);
                uData = MacroSegmentoConfig.aplicarOverrides(
                    uData, _macroSegmentoActual);
                // Sincronizar con variables de estado para acceso desde AppBar
                if (_uData != uData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _uData = uData;
                        _saldo = BioConfig.toInt(uData[BioConfig.campoTokens]);
                        _codigo = uData[BioConfig.campoCodigoPropio] ?? '---';
                        // ── Plan activo ───────────────────────────────────────────
                        final planActiva =
                            uData[BioConfig.campoSuscripcionActiva] as bool? ??
                                false;
                        final planFinTs =
                            uData[BioConfig.campoSuscripcionFin] as Timestamp?;
                        if (planActiva && planFinTs != null) {
                          final fin = planFinTs.toDate();
                          _tienePlanActivo = fin.isAfter(DateTime.now());
                        } else {
                          _tienePlanActivo = false;
                        }
                      });
                    }
                  });
                }
                int saldo = BioConfig.toInt(uData[BioConfig.campoTokens]);
                String nivel =
                    uData[BioConfig.campoNivel] ?? BioConfig.nivelBasico;
                // Obtener nombre: Google displayName → Firestore → parte del email → "Usuario"
                String nombre = user?.displayName ?? uData['nombre'] ?? "";
                if (nombre.isEmpty && (user?.email ?? '').isNotEmpty) {
                  // Extraer nombre del email: "alberto.garcia@gmail.com" → "Alberto"
                  nombre = user!.email!.split('@').first.split('.').first;
                  nombre = nombre[0].toUpperCase() + nombre.substring(1);
                }
                if (nombre.isEmpty) nombre = "Usuario";
                // Solo primer nombre para el saludo
                nombre = nombre.split(' ').first;
                String codigo = uData[BioConfig.campoCodigoPropio] ?? "---";
                final bool puedeCompartirCodigo =
                    _puedeInvitarReferidos || rolEfectivo != BioConfig.rolUser;
                // (también en _codigo para acceso desde AppBar)

                Color colorNivelActual = _colorNivel(nivel);

                final Widget contenido = DefaultTabController(
                  length: 2,
                  child: Column(children: [
                    // ── CABECERA: Saludo + nivel + código + fecha/hora ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: Colors.white.withValues(alpha: 0.04),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // "Hola, Albert ⭐ VIP"
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text("Hola, $nombre  ",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                  Icon(_iconoNivel(nivel),
                                      size: 14, color: colorNivelActual),
                                  const SizedBox(width: 3),
                                  Text(nivel,
                                      style: TextStyle(
                                          color: colorNivelActual,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  // Badge ViewAs si está activo
                                  if (viewAs.estaActivo) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.orange
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.visibility,
                                                color: Colors.orange, size: 9),
                                            const SizedBox(width: 3),
                                            Text(
                                                viewAs.rolSimulado!
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                    color: Colors.orange,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ]),
                                    ),
                                  ],
                                  // Badge Plan activo
                                  if (_tienePlanActivo) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.tealAccent
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.tealAccent
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.all_inclusive,
                                                color: Colors.tealAccent,
                                                size: 9),
                                            SizedBox(width: 3),
                                            Text('PLAN',
                                                style: TextStyle(
                                                    color: Colors.tealAccent,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ]),
                                    ),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                // PS/Admin: código referido clicable
                                if (puedeCompartirCodigo)
                                  GestureDetector(
                                    onTap: () => _mostrarPanelReferidos(
                                      codigo,
                                      user!.uid,
                                      miRol: rolEfectivo,
                                      puedeCompartir: puedeCompartirCodigo,
                                      maxInvitados: _maxInvitadosReferidos,
                                      invitadosActuales:
                                          _referidosDirectosActuales,
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.qr_code,
                                          size: 12, color: Colors.cyan),
                                      const SizedBox(width: 4),
                                      Text('Cód. $codigo',
                                          style: const TextStyle(
                                              color: Colors.cyan,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: Colors.cyan)),
                                      const SizedBox(width: 3),
                                      const Icon(Icons.touch_app,
                                          size: 11, color: Colors.cyan),
                                    ]),
                                  ),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_formatearFecha(ahora),
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                                Text(_formatearHora(ahora),
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                              ]),
                        ],
                      ),
                    ),

                    // ── TAB: Sonidos ─────────────────────────────────────
                    TabBar(
                      indicatorColor: BioConfig.colorPrimario,
                      labelColor: BioConfig.colorPrimario,
                      unselectedLabelColor: Colors.white38,
                      indicatorWeight: 2.5,
                      tabs: const [
                        Tab(
                            icon: Icon(Icons.graphic_eq, size: 16),
                            text: 'SONIDOS'),
                        Tab(
                            icon: Icon(Icons.shopping_cart_outlined, size: 16),
                            text: 'COMPRAS'),
                      ],
                    ),

                    // ── TAB CONTENT ───────────────────────────────────────
                    Expanded(
                      child: TabBarView(children: [
                        // ══ TAB 1: Sonidos ════════════════════════════════
                        Column(children: [
                          // ── LISTA DE SONIDOS ─────────────────────────────────
                          // Botón Top 10
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: GestureDetector(
                              onTap: null,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.blue.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.emoji_events,
                                        color: Colors.amber, size: 18),
                                    SizedBox(width: 8),
                                    Text("TOP 10 — Sonidos más usados",
                                        style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    SizedBox(width: 8),
                                    Icon(Icons.chevron_right,
                                        color: Colors.blue, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: _sonidosFuture,
                              builder: (context, sSnap) {
                                if (!sSnap.hasData)
                                  return const Center(
                                      child: CircularProgressIndicator());
                                // Filtrar lista según búsqueda y filtro activo
                                final docs2 = sSnap.data!.where((d) {
                                  final docId = d['_id'] as String? ?? '';
                                  return _pasaFiltroMap(docId, d);
                                }).toList();
                                return Column(children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 12, 12, 0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchCtrl,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            onChanged: (v) => setState(
                                                () => _query = v.toLowerCase()),
                                            decoration: InputDecoration(
                                              hintText: 'Buscar sonidos...',
                                              hintStyle: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 13),
                                              prefixIcon: const Icon(
                                                  Icons.search,
                                                  color: Colors.white38,
                                                  size: 20),
                                              suffixIcon: _query.isNotEmpty
                                                  ? GestureDetector(
                                                      onTap: () {
                                                        _searchCtrl.clear();
                                                        setState(
                                                            () => _query = '');
                                                      },
                                                      child: const Icon(
                                                          Icons.close,
                                                          color: Colors.white38,
                                                          size: 18),
                                                    )
                                                  : null,
                                              filled: true,
                                              fillColor: Colors.white
                                                  .withValues(alpha: 0.07),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        _buildFiltroCompacto(),
                                      ],
                                    ),
                                  ),

                                  if (docs2.isEmpty &&
                                      (_query.isNotEmpty ||
                                          _filtroActivo != 'todos'))
                                    Expanded(
                                        child: Center(
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.search_off,
                                                color: Colors.white24,
                                                size: 48),
                                            const SizedBox(height: 12),
                                            Text(
                                                _filtroActivo == 'recetados'
                                                    ? 'Ningún sonido recetado aún'
                                                    : _filtroActivo ==
                                                            'favoritos'
                                                        ? 'No tienes favoritos aún'
                                                        : 'Sin resultados para "$_query"',
                                                style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 14)),
                                          ]),
                                    ))
                                  else
                                    Expanded(
                                        child: RefreshIndicator(
                                            color: BioConfig.colorPrimario,
                                            backgroundColor:
                                                const Color(0xFF1E1E1E),
                                            onRefresh: _recargarPantallaSonidos,
                                            child: ListView.builder(
                                              physics:
                                                  const AlwaysScrollableScrollPhysics(),
                                              itemCount: docs2.length,
                                              itemBuilder: (context, i) {
                                                try {
                                                  var sonido = docs2[i];
                                                  String sonidoId = docs2[i]
                                                          ['_id'] as String? ??
                                                      '';
                                                  // Fallback: if cache is missing _id, skip to avoid bugs
                                                  if (sonidoId.isEmpty)
                                                    return const SizedBox
                                                        .shrink();
                                                  // Auto-inicializar campos faltantes sin bloquear UI
                                                  _inicializarCamposSonido(
                                                      sonidoId, sonido);
                                                  String descripcion = sonido[
                                                          'descripcion'] ??
                                                      "Frecuencia Bioacústica";

                                                  // Estado del sonido
                                                  final String estado =
                                                      sonido['estado'] ??
                                                          BioConfig
                                                              .estadoDisponible;
                                                  final int metaDonacion =
                                                      BioConfig.toInt(sonido[
                                                          'meta_donacion']);
                                                  final int donaciones =
                                                      BioConfig.toInt(sonido[
                                                          'donaciones_recibidas']);
                                                  final String faseSonido =
                                                      (sonido['fase'] ?? '')
                                                          .toString()
                                                          .trim();
                                                  final String textoEstado =
                                                      BioConfig
                                                          .etiquetaEstadoSonido(
                                                              estado);
                                                  final Color colorEstado =
                                                      BioConfig
                                                          .colorEstadoSonido(
                                                              estado);
                                                  final String mensajeEstado =
                                                      BioConfig
                                                          .mensajeEstadoSonido(
                                                    estado,
                                                    descripcion: descripcion,
                                                    fase: faseSonido,
                                                    donaciones: donaciones,
                                                    metaDonacion: metaDonacion,
                                                  );

                                                  // Candados PRO/VIP
                                                  bool esPro = sonido[
                                                          'nivel_requerido'] ==
                                                      'PRO';
                                                  bool esVipReq = sonido[
                                                          'nivel_requerido'] ==
                                                      'VIP';
                                                  bool bloqueadoPorNivel = ((esPro &&
                                                          nivel ==
                                                              BioConfig
                                                                  .nivelBasico) ||
                                                      (esVipReq &&
                                                          nivel !=
                                                              BioConfig
                                                                  .nivelVip));

                                                  // Color del borde según estado
                                                  Color borderColor =
                                                      bloqueadoPorNivel
                                                          ? (esPro
                                                                  ? BioConfig
                                                                      .colorPro
                                                                  : BioConfig
                                                                      .colorVip)
                                                              .withValues(
                                                                  alpha: 0.4)
                                                          : Colors.white12;

                                                  // Ícono según estado
                                                  IconData icono =
                                                      bloqueadoPorNivel
                                                          ? Icons.lock
                                                          : Icons.graphic_eq;
                                                  Color iconColor =
                                                      bloqueadoPorNivel
                                                          ? (esPro
                                                              ? BioConfig
                                                                  .colorPro
                                                              : BioConfig
                                                                  .colorVip)
                                                          : BioConfig
                                                              .colorPrimario;

                                                  // Progreso donación

                                                  return Card(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.04),
                                                    margin: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        side: BorderSide(
                                                            color:
                                                                borderColor)),
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      onTap: () async {
                                                        // Si el user tiene PS y aún no tiene aprobación,
                                                        // el botón "Solicitar" maneja la acción — no mostrar modal de compra
                                                        final _rolTap =
                                                            ViewAsManager()
                                                                .rolEfectivo(uData[
                                                                        'rol'] ??
                                                                    BioConfig
                                                                        .rolUser);
                                                        final _medicoTap =
                                                            _textoCampo(uData[
                                                                'medico_id']);
                                                        final _referidoTap =
                                                            _textoCampo(uData[
                                                                BioConfig
                                                                    .campoReferidoPor]);
                                                        final _tieneVinculoTap =
                                                            _medicoTap
                                                                    .isNotEmpty ||
                                                                _referidoTap
                                                                    .isNotEmpty;
                                                        final _yaAprobTap =
                                                            _recetadosIds
                                                                .contains(
                                                                    sonidoId);
                                                        if (bloqueadoPorNivel &&
                                                            !(_rolTap ==
                                                                    BioConfig
                                                                        .rolUser &&
                                                                _tieneVinculoTap &&
                                                                !_yaAprobTap)) {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                                  SnackBar(
                                                            content: Text(
                                                                "🔒 Necesitas nivel ${sonido['nivel_requerido']} para acceder."),
                                                            action: SnackBarAction(
                                                                label:
                                                                    "COMPRAR",
                                                                textColor:
                                                                    Colors.cyan,
                                                                onPressed:
                                                                    _abrirModalCompra),
                                                          ));
                                                          return;
                                                        }
                                                        if (bloqueadoPorNivel &&
                                                            _rolTap ==
                                                                BioConfig
                                                                    .rolUser &&
                                                            _tieneVinculoTap &&
                                                            !_yaAprobTap) {
                                                          // Solicitar button handles this — do nothing on card tap
                                                          return;
                                                        }
                                                        if (estado ==
                                                            BioConfig
                                                                .estadoInvestigacion) {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  PantallaInvestigacion(
                                                                sonidoId:
                                                                    sonidoId,
                                                                sonidoData:
                                                                    sonido,
                                                                saldoActual:
                                                                    saldo,
                                                                nivelUsuario:
                                                                    nivel,
                                                              ),
                                                            ),
                                                          );
                                                          return;
                                                        }
                                                        if (estado == BioConfig.estadoEnProceso &&
                                                            _rolTap ==
                                                                BioConfig
                                                                    .rolUser &&
                                                            !_recetadosIds
                                                                .contains(
                                                                    sonidoId)) {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                                content: Text(
                                                                    mensajeEstado)),
                                                          );
                                                          return;
                                                        }
                                                        // Paciente con médico asignado: verificar prescripción
                                                        final rolActual =
                                                            ViewAsManager()
                                                                .rolEfectivo(uData[
                                                                        'rol'] ??
                                                                    BioConfig
                                                                        .rolUser);
                                                        final medicoId =
                                                            await _resolverPsActual();
                                                        if (rolActual ==
                                                                BioConfig
                                                                    .rolUser &&
                                                            medicoId != null &&
                                                            sonido['requiere_prescripcion'] ==
                                                                true) {
                                                          _mostrarSolicitudPrescripcion(
                                                              sonidoId,
                                                              sonido['Nombre'] ??
                                                                  sonidoId,
                                                              medicoId,
                                                              FirebaseAuth
                                                                  .instance
                                                                  .currentUser!
                                                                  .uid);
                                                          return;
                                                        }
                                                        Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  PantallaSonidoDetalle(
                                                                sonidoId:
                                                                    sonidoId,
                                                                sonidoData:
                                                                    sonido,
                                                                saldoActual:
                                                                    saldo,
                                                                nivelUsuario:
                                                                    nivel,
                                                                rolUsuario: _uData[
                                                                        'rol'] ??
                                                                    BioConfig
                                                                        .rolUser,
                                                                suscripcionActiva:
                                                                    _tienePlanActivo,
                                                              ),
                                                            ));
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(14),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(children: [
                                                              Icon(icono,
                                                                  color:
                                                                      iconColor,
                                                                  size: 36),
                                                              const SizedBox(
                                                                  width: 12),
                                                              Expanded(
                                                                  child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                      sonido['Nombre'] ??
                                                                          'Sin Nombre',
                                                                      style: const TextStyle(
                                                                          color: Colors
                                                                              .white,
                                                                          fontWeight: FontWeight
                                                                              .w600,
                                                                          fontSize:
                                                                              15)),
                                                                  Text(
                                                                      descripcion,
                                                                      style: const TextStyle(
                                                                          color: Colors
                                                                              .grey,
                                                                          fontSize:
                                                                              12),
                                                                      maxLines:
                                                                          2,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis),
                                                                ],
                                                              )),
                                                              // ── Botón "Solicitar" para users con PS ────
                                                              Builder(
                                                                  builder: (_) {
                                                                final rolEfec = ViewAsManager()
                                                                    .rolEfectivo(_uData[
                                                                            'rol'] ??
                                                                        BioConfig
                                                                            .rolUser);
                                                                final medicoId =
                                                                    _textoCampo(
                                                                        _uData[
                                                                            'medico_id']);
                                                                final tieneVinculoPs = medicoId
                                                                        .isNotEmpty ||
                                                                    _textoCampo(
                                                                            _uData[BioConfig.campoReferidoPor])
                                                                        .isNotEmpty;
                                                                final yaAprobado =
                                                                    _recetadosIds
                                                                        .contains(
                                                                            sonidoId);
                                                                // Mostrar si: es user + tiene PS + no está aprobado aún
                                                                if (rolEfec ==
                                                                        BioConfig
                                                                            .rolUser &&
                                                                    tieneVinculoPs &&
                                                                    !yaAprobado &&
                                                                    estado ==
                                                                        BioConfig
                                                                            .estadoDisponible) {
                                                                  return GestureDetector(
                                                                    // ⚠️  behavior absorbs tap — evita que burbujee
                                                                    //     al InkWell del padre (que abriría modal de compra)
                                                                    behavior:
                                                                        HitTestBehavior
                                                                            .opaque,
                                                                    onTap:
                                                                        () async {
                                                                      final medicoResuelto = medicoId
                                                                              .isNotEmpty
                                                                          ? medicoId
                                                                          : await _resolverPsActual();
                                                                      if (medicoResuelto ==
                                                                              null ||
                                                                          medicoResuelto
                                                                              .isEmpty) {
                                                                        if (!context
                                                                            .mounted)
                                                                          return;
                                                                        ScaffoldMessenger.of(context)
                                                                            .showSnackBar(
                                                                          const SnackBar(
                                                                            content:
                                                                                Text(
                                                                              'No se pudo resolver tu PS. Intenta de nuevo en unos segundos.',
                                                                            ),
                                                                          ),
                                                                        );
                                                                        return;
                                                                      }
                                                                      _mostrarSolicitudPrescripcion(
                                                                          sonidoId,
                                                                          sonido['Nombre'] ??
                                                                              sonidoId,
                                                                          medicoResuelto,
                                                                          user!
                                                                              .uid);
                                                                    },
                                                                    child:
                                                                        Container(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              8,
                                                                          vertical:
                                                                              4),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: Colors
                                                                            .tealAccent
                                                                            .withValues(alpha: 0.12),
                                                                        borderRadius:
                                                                            BorderRadius.circular(20),
                                                                        border: Border.all(
                                                                            color:
                                                                                Colors.tealAccent.withValues(alpha: 0.4)),
                                                                      ),
                                                                      child: const Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            Icon(Icons.add_circle_outline,
                                                                                color: Colors.tealAccent,
                                                                                size: 13),
                                                                            SizedBox(width: 3),
                                                                            Text('Solicitar',
                                                                                style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                                                          ]),
                                                                    ),
                                                                  );
                                                                }
                                                                return const SizedBox
                                                                    .shrink();
                                                              }),
                                                              // ★ Favorito — siempre visible
                                                              StreamBuilder<
                                                                  DocumentSnapshot>(
                                                                stream: FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        BioConfig
                                                                            .colUsuarios)
                                                                    .doc(user!
                                                                        .uid)
                                                                    .collection(
                                                                        BioConfig
                                                                            .colFavoritos)
                                                                    .doc(
                                                                        sonidoId)
                                                                    .snapshots(),
                                                                builder: (_,
                                                                    favSnap) {
                                                                  bool esFav = favSnap
                                                                          .hasData &&
                                                                      favSnap
                                                                          .data!
                                                                          .exists;
                                                                  return IconButton(
                                                                    icon: Icon(
                                                                        esFav
                                                                            ? Icons
                                                                                .star
                                                                            : Icons
                                                                                .star_border,
                                                                        color: esFav
                                                                            ? Colors
                                                                                .amber
                                                                            : Colors
                                                                                .white24,
                                                                        size:
                                                                            22),
                                                                    tooltip: esFav
                                                                        ? "Quitar de favoritos"
                                                                        : "Agregar a favoritos",
                                                                    onPressed: () =>
                                                                        _toggleFavorito(
                                                                            user.uid,
                                                                            sonidoId),
                                                                  );
                                                                },
                                                              ),
                                                            ]),
                                                            const SizedBox(
                                                                height: 10),
                                                            Wrap(
                                                              spacing: 8,
                                                              runSpacing: 8,
                                                              children: [
                                                                _badgeEstado(
                                                                    textoEstado,
                                                                    colorEstado),
                                                                if (bloqueadoPorNivel)
                                                                  _badgeEstado(
                                                                    "Nivel ${sonido['nivel_requerido']}",
                                                                    esPro
                                                                        ? BioConfig
                                                                            .colorPro
                                                                        : BioConfig
                                                                            .colorVip,
                                                                  ),
                                                                if (_recetadosIds
                                                                    .contains(
                                                                        sonidoId))
                                                                  _badgeEstado(
                                                                    'Aprobado',
                                                                    Colors
                                                                        .greenAccent,
                                                                  ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                                height: 8),
                                                            Text(
                                                              mensajeEstado,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white60,
                                                                fontSize: 11.5,
                                                                height: 1.35,
                                                              ),
                                                            ),
                                                            if (estado ==
                                                                BioConfig
                                                                    .estadoInvestigacion) ...[
                                                              const SizedBox(
                                                                  height: 10),
                                                              SizedBox(
                                                                height: 38,
                                                                child:
                                                                    OutlinedButton
                                                                        .icon(
                                                                  onPressed:
                                                                      () {
                                                                    Navigator
                                                                        .push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (_) =>
                                                                                PantallaInvestigacion(
                                                                          sonidoId:
                                                                              sonidoId,
                                                                          sonidoData:
                                                                              sonido,
                                                                          saldoActual:
                                                                              saldo,
                                                                          nivelUsuario:
                                                                              nivel,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  style: OutlinedButton
                                                                      .styleFrom(
                                                                    foregroundColor:
                                                                        Colors
                                                                            .lightBlueAccent,
                                                                    side:
                                                                        BorderSide(
                                                                      color: Colors
                                                                          .lightBlueAccent
                                                                          .withValues(
                                                                        alpha:
                                                                            0.45,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .volunteer_activism_outlined,
                                                                      size: 16),
                                                                  label:
                                                                      const Text(
                                                                    'Donar',
                                                                    style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                            // Usos por la comunidad
                                                            const SizedBox(
                                                                height: 6),
                                                            Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .end,
                                                                children: [
                                                                  const Icon(
                                                                      Icons
                                                                          .people_outline,
                                                                      size: 11,
                                                                      color: Colors
                                                                          .white24),
                                                                  const SizedBox(
                                                                      width: 3),
                                                                  Text(
                                                                      '${BioConfig.toInt(sonido['total_usos'])} usos',
                                                                      style: const TextStyle(
                                                                          color: Colors
                                                                              .white24,
                                                                          fontSize:
                                                                              10)),
                                                                ]),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  debugPrint(
                                                      "Error renderizando sonido $i: $e");
                                                  return const SizedBox
                                                      .shrink(); // skip broken card silently
                                                }
                                              },
                                            ))), // fin Expanded ListView
                                ]); // fin Column (search + chips + list)
                              },
                            ),
                          ),
                        ]), // fin Column Tab 1
                        _buildComprasCoreTab(),

                        // ══ TAB 2: Bio-Scanner ════════════════════════════
                      ]), // fin TabBarView
                    ), // fin Expanded
                  ]), // fin Column DefaultTabController
                ); // fin DefaultTabController

                // ── Imagen de fondo si el usuario configuró una ────────
                if (!tieneImagen) return contenido;
                return Stack(children: [
                  Positioned.fill(
                    child: theme.imagenFondo.startsWith('http')
                        ? Image.network(theme.imagenFondo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink())
                        : Image.file(File(theme.imagenFondo),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                  ),
                  Positioned.fill(
                    child:
                        Container(color: Colors.black.withValues(alpha: 0.55)),
                  ),
                  contenido,
                ]);
              },
            ),
          );
        }); // fin ListenableBuilder
  }
}

// ═════════════════════════════════════════════════════════════════════════════

// ── Input formatters de seguridad ───────────────────────────────────────────
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA DETALLE DEL SONIDO — "La Carpeta"
// ═════════════════════════════════════════════════════════════════════════════
// ── Estado del sistema de recetas en el player ───────────────────────────
enum _EstadoReceta {
  libre, // sonido sin prescripción — flujo normal
  sinPS, // user sin PS asignado — no puede solicitar
  pendienteSolicitud, // user solicitó al PS — esperando aprobación
  pendientePago, // PS aprobó pero el user no ha pagado aún
  activo, // pagado, sesiones disponibles
  bloqueadoCiclo, // sesiones de hoy usadas, esperando próximo ciclo
  completado, // tratamiento terminado
}

class PantallaSonidoDetalle extends StatefulWidget {
  final String sonidoId;
  final Map<String, dynamic> sonidoData;
  final int saldoActual;
  final String nivelUsuario;
  final String rolUsuario; // rol real: 'user','PS','admin','tester'
  final bool suscripcionActiva;

  const PantallaSonidoDetalle({
    super.key,
    required this.sonidoId,
    required this.sonidoData,
    required this.saldoActual,
    required this.nivelUsuario,
    this.rolUsuario = 'user',
    this.suscripcionActiva = false,
  });

  @override
  State<PantallaSonidoDetalle> createState() => _PantallaSonidoDetalleState();
}

class _PantallaSonidoDetalleState extends State<PantallaSonidoDetalle> {
  final ja.AudioPlayer _player = ja.AudioPlayer();
  final ScrollController _scrollCtrl = ScrollController();
  bool _audioBuffereado =
      false; // true solo cuando setSource completó exitosamente
  bool _fuenteAudioLista = false;
  String? _urlAudioPreferidaActual;
  String? _urlAudioResuelta;

  // Cache estática de acceso — evita releer Firestore al reabrir la misma tarjeta
  static final Map<String, Map<String, dynamic>> _accesoCache = {};

  // Estado del sonido
  bool _cargandoAcceso = true;
  bool _sonidoBloqueado = true; // true = requiere ver video
  bool _reproduciendo = false;
  int _duracionSeg = 0; // duración REAL del audio (para timer/loop)

  // ── MEJORA 1: Sistema de Cobro Híbrido ───────────────────────────────────
  // _precioFijoTokens usa el campo costo_uso de Firestore como precio manual.
  //   > 0 → precio fijo (override manual), ej: 70000 tokens por reproducción
  //   == 0 → calcular automáticamente: duraciónReal × _tarifaBasePorSeg
  // Legacy: si un sonido viejo aún trae duracion_seg, se interpreta como alias
  // de precio fijo solo como compatibilidad de lectura.
  int _precioFijoTokens = 0;
  static const double _tarifaBasePorSeg = 1.0; // 1 segundo = 1 token
  // Getter centralizado — único punto de verdad para el precio de una sesión.
  // Todos los cálculos de cobro (modal, _reproducir, display) deben usar esto.
  int get _precioUnitario => _precioFijoTokens > 0
      ? _precioFijoTokens
      : (_duracionSeg > 0 ? (_duracionSeg * _tarifaBasePorSeg).round() : 0);
// ─────────────────────────────────────────────────────────────────────────

  bool get _requiereValidacionServidor {
    final d = widget.sonidoData;
    return _estadoReceta == _EstadoReceta.activo ||
        d['requiere_prescripcion'] == true ||
        d['requiere_receta'] == true ||
        d['requiere_acceso'] == true ||
        d['sensible'] == true ||
        d['uso_sensible'] == true;
  }

  int _saldoActual = 0;

  // Bucle de repeticiones
  int _repeticiones = 1; // total pedido por el usuario
  bool _repetirIndefinido = false; // true = loop hasta que el usuario pare
  int? _ciclosIndefinido; // contador de ciclos en modo indefinido
  int _repeticionesRestantes = 0; // cuántas faltan
  bool _procesandoBucle = false; // flag anti-doble-disparo
  Timer? _bucleTimer; // respaldo si onPlayerComplete no dispara

  // Estado del video / texto / quiz
  // Sistema de desbloqueo: aprobación directa por PS
  DateTime? _fechaExpiracion; // cuando se vence el acceso
  String _contadorTexto = ""; // DD:HH:MM:SS actualizado cada segundo
  Timer? _contadorTimer; // timer del contador visible

  // Valor del token desde Firestore
  double _valorTokenCop = 100.0;

  // Modo tester
  bool _esTester = false;

  // ── Estado de receta prescrita ───────────────────────────────────────────
  _EstadoReceta _estadoReceta = _EstadoReceta.libre;
  String?
      _medicoIdAsignado; // UID del PS asignado a este user (null si no tiene)
  Map<String, dynamic> _datosAcceso = {};

  Future<String?> _resolverPsAsignadoDetalle(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    final medicoActual = _textoCampo(userData['medico_id']);
    if (medicoActual.isNotEmpty) {
      _medicoIdAsignado = medicoActual;
      return medicoActual;
    }

    final medicoResuelto = await _asegurarPsAsignadoRuntime(uid, userData);
    if (medicoResuelto != null && medicoResuelto.isNotEmpty) {
      _medicoIdAsignado = medicoResuelto;
      return medicoResuelto;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _saldoActual = widget.saldoActual;
    _activarFlagSeguro();
    // MEJORA 4 — Buffer agresivo:
    // stayAwake: true evita que el CPU entre en deep-sleep durante la descarga
    // del stream, lo que causa pausas de buffer en archivos de 10+ minutos.
    // El audio inicia en cuanto los primeros segundos están listos — no espera
    // la descarga completa — gracias al patrón setSource() + resume().
    _configurarSesionAudio();
    _cargarValorToken();
    _cargarRolUsuario();
    _verificarAccesoYDuracion();
    // Timer del contador — se inicia al final de _verificarAccesoYDuracion
    // cuando ya tenemos _fechaExpiracion definida
    // ── MEJORA 2: Vibración Sincronizada ─────────────────────────────────
    // Escuchar el estado del player para sincronizar la vibración.
    // - playing  → activar loop de vibración
    // - paused / stopped / completed → cancelar vibración inmediatamente
    // Esto garantiza que el motor háptico nunca quede activo sin audio.
    _player.playerStateStream.listen((state) {
      final modo = ReproduccionConfig().modo;
      if (state.playing) {
        if (modo == ModoReproduccion.dual ||
            modo == ModoReproduccion.vibracion) {
          final hex =
              widget.sonidoData['scanner_color_hex'] as String? ?? '#00CCFF';
          HapticHelper.vibrarConHex(hex);
        }
      } else {
        // Cancelar en cualquier otro estado (paused, stopped, completed)
        HapticHelper.detener();
      }

      if (state.processingState == ja.ProcessingState.completed) {
        unawaited(_manejarAudioCompletado());
      }
    });
  }

  Future<void> _configurarSesionAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('[Audio] No se pudo configurar audio_session: $e');
    }
  }

  Future<void> _manejarAudioCompletado() async {
    if (!mounted || _procesandoBucle) return;
    _procesandoBucle = true;
    await _siguienteRepeticion();
    _procesandoBucle = false;
  }

  // ── Pantalla de estado de receta (pago/bloqueo/completado) ───────────────
  Widget _pantallaReceta() {
    final sonido = widget.sonidoData['Nombre'] as String? ?? 'este sonido';
    final costo = _datosAcceso['costo_total_tokens'] as int? ?? 0;
    final sesiones = _datosAcceso['sesiones_por_ciclo'] as int? ?? 1;
    final dias = _datosAcceso['dias_tratamiento'] as int? ?? 1;
    final minutos = _datosAcceso['minutos_entre_ciclos'] as int? ?? 0;

    if (_estadoReceta == _EstadoReceta.pendientePago) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            child: Center(
                child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.payment, color: Colors.tealAccent, size: 64),
            const SizedBox(height: 20),
            Text('Tratamiento aprobado',
                style: TextStyle(
                    color: BioConfig.colorPrimario,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('"$sonido"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            // Resumen de la dosis
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(children: [
                _filaPago('Sesiones por ciclo', '$sesiones'),
                _filaPago('Intervalo entre ciclos', _minutosATexto(minutos)),
                _filaPago('Días de tratamiento', '$dias'),
                const Divider(color: Colors.white10),
                _filaPago('Costo total', '$costo tokens', destacar: true),
                _filaPago('Tu saldo', '$_saldoActual tokens',
                    destacar: true,
                    color: _saldoActual >= costo
                        ? Colors.greenAccent
                        : Colors.redAccent),
              ]),
            ),
            const SizedBox(height: 24),
            if (_saldoActual >= costo)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: BioConfig.colorPrimario,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.play_circle, size: 22),
                  label: Text('Pagar $costo tokens e iniciar',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () => _pagarTratamiento(costo, sesiones),
                ),
              )
            else
              Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      'Te faltan ${costo - _saldoActual} tokens para iniciar '
                      'el tratamiento.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                  label: Text(
                      'Pagar ${(costo - _saldoActual)} tokens '
                      '(${((costo - _saldoActual) * _valorTokenCop).toStringAsFixed(0)} COP)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () {
                    Navigator.pop(context);
                    // Lanzar MercadoPago con el monto exacto faltante
                    final tokensNecesarios = costo - _saldoActual;
                    if (tokensNecesarios > 0) {
                      _comprarTokensTratamiento(tokensNecesarios);
                    }
                  },
                ),
              ]),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver',
                    style: TextStyle(color: Colors.white38))),
          ]),
        ))),
      );
    }

    if (_estadoReceta == _EstadoReceta.bloqueadoCiclo) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            child: Center(
                child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 64),
            const SizedBox(height: 20),
            const Text('Ciclo completado',
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('"$sonido"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            if (_contadorTexto.isNotEmpty) ...[
              const Text('Próxima sesión en:',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Text(_contadorTexto,
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
            ],
            const SizedBox(height: 24),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver',
                    style: TextStyle(color: Colors.white38))),
          ]),
        ))),
      );
    }

    if (_estadoReceta == _EstadoReceta.completado) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            child: Center(
                child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.verified, color: Colors.greenAccent, size: 64),
            const SizedBox(height: 20),
            const Text('Tratamiento completado',
                style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('"$sonido"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            const Text(
                'Has completado todas las sesiones recetadas. '
                'Consulta con tu médico para una evaluación.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white54, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver',
                    style: TextStyle(color: Colors.white38))),
          ]),
        ))),
      );
    }

    return const SizedBox();
  }

  static Widget _filaPago(String label, String valor,
          {bool destacar = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(valor,
              style: TextStyle(
                  color: color ?? (destacar ? Colors.white : Colors.white70),
                  fontSize: destacar ? 14 : 12,
                  fontWeight: destacar ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  static String _minutosATexto(int m) {
    if (m == 0) return 'Sin restricción';
    final h = m ~/ 60;
    final min = m % 60;
    final partes = <String>[];
    if (h > 0) partes.add('$h h');
    if (min > 0) partes.add('$min min');
    return 'cada ${partes.join(' ')}';
  }

  Future<String> _crearPreferenciaMercadoPago({
    required String titulo,
    required int cantidadTokens,
    required int precioCop,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No estas autenticado.");
    final idToken = await user.getIdToken(true);
    final mpResp = await http
        .post(
          Uri.parse(BioConfig.mpPreferenceUrl),
          headers: {
            "Authorization": "Bearer $idToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "titulo": titulo,
            "cantidad": cantidadTokens,
            "precio": precioCop,
            "uid": user.uid,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (mpResp.statusCode != 200 && mpResp.statusCode != 201) {
      throw Exception("MP backend ${mpResp.statusCode}: ${mpResp.body}");
    }
    final mpData = jsonDecode(mpResp.body) as Map<String, dynamic>;
    final urlPago = (mpData['init_point'] ?? mpData['sandbox_init_point'] ?? '')
        .toString()
        .trim();
    if (urlPago.isEmpty) {
      throw Exception("El servidor no devolvio enlace de pago.");
    }
    return urlPago;
  }

  // ── Comprar tokens faltantes para el tratamiento vía MercadoPago ──────────
  // Lanza checkout con el monto exacto que le falta al user para iniciar.
  // Tras el pago exitoso, MercadoPago redirige a biofreq://pago-exitoso y el
  // servidor local acredita los tokens. El user vuelve a la app y ya puede pagar.
  Future<void> _comprarTokensTratamiento(int tokensNecesarios) async {
    if (FirebaseAuth.instance.currentUser == null) return;

    final valorCOP = (tokensNecesarios * _valorTokenCop).round();
    try {
      debugPrint(
          "[MP] Enviando request tratamiento — $tokensNecesarios tokens");
      final urlPago = await _crearPreferenciaMercadoPago(
        titulo: "Tokens para tratamiento BioFreq",
        cantidadTokens: tokensNecesarios,
        precioCop: valorCOP,
      );
      await custom_tabs.launchUrl(
        Uri.parse(urlPago),
        customTabsOptions: custom_tabs.CustomTabsOptions(
          colorSchemes: custom_tabs.CustomTabsColorSchemes.defaults(
            toolbarColor: BioConfig.colorPrimario,
          ),
          urlBarHidingEnabled: true,
          showTitle: false,
          closeButton: custom_tabs.CustomTabsCloseButton(
            icon: custom_tabs.CustomTabsCloseButtonIcons.back,
          ),
          animations: const custom_tabs.CustomTabsAnimations(
            startEnter: 'slide_up',
            startExit: 'android:anim/fade_out',
            endEnter: 'android:anim/fade_in',
            endExit: 'slide_down',
          ),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: Duration(seconds: 6),
          content: Text(
              'Pago iniciado. El saldo se actualiza cuando MercadoPago confirme.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al iniciar el pago: $e')));
      }
    }
  }

  // ── Pagar tratamiento completo de una sola vez ────────────────────────────
  Future<void> _pagarTratamiento(int costo, int sesiones) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final accesoRef = FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .collection(BioConfig.colAccesosSonidos)
          .doc(widget.sonidoId);
      final userRef = FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid);

      batch.update(userRef, {
        BioConfig.campoTokens: FieldValue.increment(-costo),
      });
      batch.update(accesoRef, {
        'tokens_pagados': true,
        'tratamiento_activo': true,
        'sesiones_hoy': sesiones,
        'fecha_inicio': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      if (mounted) {
        setState(() {
          _saldoActual -= costo;
          _estadoReceta = _EstadoReceta.activo;
          _datosAcceso['tokens_pagados'] = true;
          _datosAcceso['tratamiento_activo'] = true;
          _datosAcceso['sesiones_hoy'] = sesiones;
          _sonidoBloqueado = false;
          _repeticiones = sesiones;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar pago: $e')));
      }
    }
  }

  // ── FLAG_SECURE: bloquea capturas y grabación de pantalla ────────────────
  void _activarFlagSeguro() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle());
    // Bloquear grabación — pantalla negra si graban
    const channel = MethodChannel('biofreq/security');
    channel.invokeMethod('setSecureFlag', true).catchError((_) => null);
  }

  void _desactivarFlagSeguro() {
    const channel = MethodChannel('biofreq/security');
    channel.invokeMethod('setSecureFlag', false).catchError((_) => null);
  }

  // ── Leer valor del token desde Firestore ─────────────────────────────────
  // Cache de valor_token por usuario para respetar overrides por segmento macro
  static final Map<String, double> _valorTokenCacheByUid = {};

  Future<void> _cargarValorToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    final cached = _valorTokenCacheByUid[uid];
    if (cached != null) {
      if (mounted) setState(() => _valorTokenCop = cached);
      return;
    }
    try {
      final valor = await MacroSegmentoConfig.resolveValorTokenCopForUid(uid,
          fallback: 100);
      _valorTokenCacheByUid[uid] = valor;
      if (mounted) setState(() => _valorTokenCop = valor);
    } catch (_) {}
  }

  // ── Contador regresivo DD:HH:MM:SS ──────────────────────────────────────
  void _actualizarContador() {
    if (_fechaExpiracion == null) {
      // No hacer setState innecesario si ya está vacío
      if (_contadorTexto.isNotEmpty) setState(() => _contadorTexto = "");
      return;
    }
    final restante = _fechaExpiracion!.difference(DateTime.now());
    if (restante.isNegative) {
      // Venció — bloquear sonido
      if (!_sonidoBloqueado) {
        setState(() {
          _sonidoBloqueado = true;
          _contadorTexto = "";
        });
      }
      return;
    }
    final dias = restante.inDays;
    final horas = restante.inHours % 24;
    final minutos = restante.inMinutes % 60;
    final segs = restante.inSeconds % 60;
    setState(() => _contadorTexto = "${dias.toString().padLeft(2, '0')}:"
        "${horas.toString().padLeft(2, '0')}:"
        "${minutos.toString().padLeft(2, '0')}:"
        "${segs.toString().padLeft(2, '0')}");
  }

  // ── Verificar rol del usuario (tester = acceso gratuito) ─────────────────
  // El rol ya viene como widget.rolUsuario — no hace falta leer Firestore de nuevo
  Future<void> _cargarRolUsuario() async {
    final rolEfectivo = ViewAsManager().rolEfectivo(widget.rolUsuario);
    if (mounted)
      setState(() => _esTester = (rolEfectivo == BioConfig.rolTester));
  }

  // ── Verificar si el sonido está desbloqueado para este usuario ────────────
  Future<void> _verificarAccesoYDuracion() async {
    // Usar caché si ya verificamos este sonido en esta sesión
    final cacheKey =
        '${FirebaseAuth.instance.currentUser?.uid}_${widget.sonidoId}';
    if (_accesoCache.containsKey(cacheKey)) {
      final cached = _accesoCache[cacheKey]!;
      if (mounted) {
        setState(() {
          _sonidoBloqueado = cached['bloqueado'] as bool;
          _cargandoAcceso = false;
          if (cached['expiracion'] != null)
            _fechaExpiracion = cached['expiracion'] as DateTime;
        });
      }
      _cargarDuracionAudio();
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _cargandoAcceso = false);
        return;
      }

      // PS, Admin y Tester: acceso siempre libre — sin verificar Firestore
      final rolEfec = ViewAsManager().rolEfectivo(widget.rolUsuario);
      if (rolEfec == BioConfig.rolPS ||
          rolEfec == BioConfig.rolAdmin ||
          rolEfec == BioConfig.rolTester) {
        _accesoCache[cacheKey] = {'bloqueado': false, 'expiracion': null};
        if (mounted)
          setState(() {
            _sonidoBloqueado = false;
            _cargandoAcceso = false;
          });
        _cargarDuracionAudio();
        return;
      }

      // Cargar duración del audio en paralelo
      _cargarDuracionAudio();

      var accesoRef = FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .collection(BioConfig.colAccesosSonidos)
          .doc(widget.sonidoId);

      var accesoDoc = await accesoRef.get();

      // El desbloqueo es siempre por texto + quiz (video queda como tutorial opcional)
      // Si el usuario NO tiene acceso válido → mostrar pantalla de lectura
      // (continúa con la lógica de acceso existente más abajo)

      if (!accesoDoc.exists) {
        // Verificar si hay solicitud pendiente en colSolicitudesPrescripcion
        final solSnap = await FirebaseFirestore.instance
            .collection(BioConfig.colSolicitudesPrescripcion)
            .where('paciente_id', isEqualTo: user.uid)
            .where('sonido_id', isEqualTo: widget.sonidoId)
            .where('estado', isEqualTo: 'pendiente')
            .limit(1)
            .get();

        final tieneSolicitudPendiente = solSnap.docs.isNotEmpty;

        // Leer medicoId del perfil del user
        final userDoc = await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .get();
        final userData = userDoc.data() ?? <String, dynamic>{};
        var medicoId = await _resolverPsAsignadoDetalle(user.uid, userData);

        // Si no tiene PS y está en modo ViewAs → el Admin es su PS
        if (medicoId == null && ViewAsManager().estaActivo) {
          medicoId = user.uid; // uid del admin que está haciendo el mimic
        }

        _accesoCache[cacheKey] = {'bloqueado': true, 'expiracion': null};
        if (mounted) {
          setState(() {
            _sonidoBloqueado = true;
            _cargandoAcceso = false;
            _medicoIdAsignado = medicoId;
            _estadoReceta = tieneSolicitudPendiente
                ? _EstadoReceta.pendienteSolicitud
                : (medicoId == null
                    ? _EstadoReceta.sinPS
                    : _EstadoReceta.libre);
          });
        }
        return;
      }

      var data = accesoDoc.data()!;

      // ── SISTEMA DE RECETAS: verificar si es un acceso prescrito ──────────
      final bool esPrescrito =
          data['aprobado'] == true && data.containsKey('sesiones_por_ciclo');
      final bool tokensPagados = data['tokens_pagados'] as bool? ?? false;

      if (esPrescrito) {
        if (!tokensPagados) {
          // Pendiente de pago — mostrar pantalla de pago
          if (mounted) {
            setState(() {
              _sonidoBloqueado = true;
              _cargandoAcceso = false;
              _estadoReceta = _EstadoReceta.pendientePago;
              _datosAcceso = data;
            });
          }
          return;
        }

        final bool tratamientoActivo =
            data['tratamiento_activo'] as bool? ?? false;
        if (!tratamientoActivo) {
          if (mounted) {
            setState(() {
              _sonidoBloqueado = true;
              _cargandoAcceso = false;
              _estadoReceta = _EstadoReceta.completado;
              _datosAcceso = data;
            });
          }
          return;
        }

        // Verificar ciclo actual
        final int sesionesHoy = data['sesiones_hoy'] as int? ?? 0;
        final Timestamp? proximoCiclo =
            data['fecha_proximo_ciclo'] as Timestamp?;

        if (sesionesHoy <= 0 && proximoCiclo != null) {
          final DateTime proximaFecha = proximoCiclo.toDate();
          final bool cicloListo = DateTime.now().isAfter(proximaFecha);

          if (cicloListo) {
            // El ciclo ya pasó — restablecer sesiones_hoy automáticamente
            final int sesPerCiclo = data['sesiones_por_ciclo'] as int? ?? 1;
            await accesoDoc.reference.update({
              'sesiones_hoy': sesPerCiclo,
              'fecha_proximo_ciclo': null,
            });
            data['sesiones_hoy'] = sesPerCiclo;
          } else {
            // Ciclo bloqueado hasta proximaFecha
            if (mounted) {
              setState(() {
                _sonidoBloqueado = true;
                _cargandoAcceso = false;
                _estadoReceta = _EstadoReceta.bloqueadoCiclo;
                _datosAcceso = data;
                _fechaExpiracion = proximaFecha;
              });
              _contadorTimer?.cancel();
              _contadorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                if (mounted) _actualizarContador();
              });
              _actualizarContador();
            }
            return;
          }
        }

        // Sesiones disponibles — puede reproducir (N veces bloqueado al PS)
        final int sesDisp = data['sesiones_hoy'] as int? ?? 1;
        if (mounted) {
          setState(() {
            _sonidoBloqueado = false;
            _cargandoAcceso = false;
            _estadoReceta = _EstadoReceta.activo;
            _datosAcceso = data;
            // Forzar repeticiones = sesiones disponibles (no puede cambiar)
            _repeticiones = sesDisp;
          });
        }
        return;
      }

      // ── Flujo normal (sin prescripción) ──────────────────────────────────
      int versionVista =
          int.tryParse(data['version_vista']?.toString() ?? '0') ?? 0;
      int versionActual =
          int.tryParse(widget.sonidoData['version_video']?.toString() ?? '1') ??
              1;

      if (versionVista < versionActual) {
        if (mounted) {
          setState(() {
            _sonidoBloqueado = true;
            _cargandoAcceso = false;
          });
        }
        return;
      }

      Timestamp? ultimoUso = data['ultimo_uso'] as Timestamp?;
      if (ultimoUso == null) {
        if (mounted) {
          setState(() {
            _sonidoBloqueado = true;
            _cargandoAcceso = false;
          });
        }
        return;
      }

      DateTime fechaUltimo = ultimoUso.toDate();
      DateTime fechaExpiracion =
          fechaUltimo.add(const Duration(days: BioConfig.diasPorCiclo));
      bool yaVencio = DateTime.now().isAfter(fechaExpiracion);

      if (yaVencio) {
        if (mounted) {
          setState(() {
            _sonidoBloqueado = true;
            _cargandoAcceso = false;
          });
        }
        return;
      }

      // Guardar en caché para evitar releer Firestore
      _accesoCache[cacheKey] = {
        'bloqueado': false,
        'expiracion': fechaExpiracion,
      };
      if (mounted) {
        setState(() {
          _sonidoBloqueado = false;
          _fechaExpiracion = fechaExpiracion;
          _cargandoAcceso = false;
        });
      }
      // Iniciar timer del contador ahora que tenemos _fechaExpiracion
      _contadorTimer?.cancel();
      _contadorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _actualizarContador();
      });
      _actualizarContador();
    } catch (e) {
      debugPrint("Error verificando acceso: $e");
      // Si hay cualquier error, mostrar pantalla en lugar de quedarse gris
      if (mounted) {
        setState(() {
          _sonidoBloqueado = true;
          _cargandoAcceso = false;
        });
      }
    }
  }

  // ── Cargar duración real del audio y precio de la sesión ─────────────────
  // COBRO HÍBRIDO (Taxímetro):
  //   duracion_seg en Firestore actúa como ALIAS de precio manual.
  //   > 0 → precio fijo override (ej: 70000 = $70.000 COP por sesión).
  //   == 0 → precio automático: duración real × _tarifaBasePorSeg.
  //
  // SEPARACIÓN DE RESPONSABILIDADES:
  //   _precioFijoTokens → precio de cobro (viene de duracion_seg Firestore)
  //   _duracionSeg      → duración real del audio (para el timer de respaldo)
  //
  // ⚠️ NUNCA llamar _player.resume() aquí — causaría reproducción ANTES
  //    de que el usuario confirme el pago en el modal de configuración.
  String _urlPreferidaAudio() {
    final hls = (widget.sonidoData['hls_manifest_url'] ??
            widget.sonidoData['url_hls'] ??
            widget.sonidoData['stream_url'])
        ?.toString()
        .trim();
    if (hls != null && hls.isNotEmpty) return hls;
    return _urlMp3Fallback();
  }

  String _urlMp3Fallback() {
    return (widget.sonidoData['url_sonido'] as String? ?? '').trim();
  }

  String _resolverUrlAudio(String url) {
    var urlResolved = url.trim();
    if (urlResolved.contains('github.com') && urlResolved.contains('/raw/')) {
      urlResolved = urlResolved
          .replaceFirst('https://github.com/', 'https://raw.githubusercontent.com/')
          .replaceFirst('/raw/', '/');
    }
    return urlResolved;
  }

  Future<bool> _prepararFuenteAudio({bool forzar = false}) async {
    final url = _urlPreferidaAudio();
    if (url.isEmpty) return false;

    final urlPreferidaResolved = _resolverUrlAudio(url);
    if (!forzar &&
        _fuenteAudioLista &&
        _urlAudioPreferidaActual == urlPreferidaResolved) {
      return true;
    }

    _urlAudioPreferidaActual = urlPreferidaResolved;
    var urlResolved = urlPreferidaResolved;
    try {
      _urlAudioResuelta = urlResolved;
      await _player.setAudioSource(
        ja.AudioSource.uri(Uri.parse(urlResolved)),
        preload: true,
      );
      _fuenteAudioLista = true;
      if (mounted) setState(() => _audioBuffereado = true);
      return true;
    } catch (e) {
      final fallback = _urlMp3Fallback();
      if (fallback.isEmpty || fallback == url) rethrow;
      urlResolved = _resolverUrlAudio(fallback);
      _urlAudioResuelta = urlResolved;
      debugPrint('[Audio] HLS no cargo; usando MP3 fallback: $e');
      await _player.setAudioSource(
        ja.AudioSource.uri(Uri.parse(urlResolved)),
        preload: true,
      );
      _fuenteAudioLista = true;
      if (mounted) setState(() => _audioBuffereado = true);
      return true;
    }
  }

  Future<void> _reproducirAudioPreparado() async {
    final listo = await _prepararFuenteAudio();
    if (!listo) {
      throw StateError('Este sonido no tiene archivo de audio configurado');
    }
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> _cargarDuracionAudio() async {
    // 1. Leer costo_uso como precio fijo; soportar duracion_seg solo por legado.
    final int costoUsoFirestore =
        int.tryParse(widget.sonidoData['costo_uso']?.toString() ?? '0') ?? 0;
    final int precioLegacyFirestore =
        int.tryParse(widget.sonidoData['duracion_seg']?.toString() ?? '0') ?? 0;
    final int precioFirestore =
        costoUsoFirestore > 0 ? costoUsoFirestore : precioLegacyFirestore;
    if (precioFirestore > 0 && mounted) {
      setState(() => _precioFijoTokens = precioFirestore);
    }

    final double duracionFirestore = double.tryParse(
            widget.sonidoData['duracion_segundos']?.toString() ?? '0') ??
        0;
    if (duracionFirestore > 0 && mounted) {
      setState(() => _duracionSeg = duracionFirestore.ceil());
    }

    // 2. Precargar audio + obtener duracion real (SIN play — solo buffer)
    final String url = _urlPreferidaAudio();
    if (url.isEmpty) {
      if (mounted) setState(() => _audioBuffereado = true);
      return;
    }

    try {
      // Obtener duracion con timeout sin bloquear el hilo principal.
      final preparado = await _prepararFuenteAudio();
      if (!preparado) return;

      // Esperar duracion max 8s.
      final duracion = _player.duration ??
          await _player.durationStream
              .firstWhere((d) => d != null && d.inSeconds > 0)
              .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (mounted && duracion != null && duracion.inSeconds > 0) {
        setState(() => _duracionSeg = duracion.inSeconds);
      }
      if (mounted) setState(() => _audioBuffereado = true);

      if (_duracionSeg == 0) {
        debugPrint(
            '[Audio] Duracion no reportada ? esperando medicion real o sincronizacion desde Firestore');
      }
    } on PlatformException catch (e) {
      debugPrint('[Audio] PlatformException: code=${e.code} msg=${e.message}');
      if (mounted) {
        setState(() {
          _audioBuffereado = true; // desbloquear UI aunque no tengamos duracion
        });
      }
    } catch (e) {
      debugPrint('[Audio] ERROR cargando fuente: ${e.runtimeType}: $e');
      if (mounted) {
        setState(() {
          _audioBuffereado = true;
        });
      }
    }
  }

  Widget _widgetAccesoBloqueado() {
    switch (_estadoReceta) {
      case _EstadoReceta.sinPS:
        // User sin PS asignado — no puede solicitar
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            const Expanded(
                child: Text(
              'Necesitas un Profesional de Salud (PS) asignado para acceder a este sonido. Contacta a BioFreq para que te asignen uno.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            )),
          ]),
        );

      case _EstadoReceta.pendienteSolicitud:
        // Ya solicitó — esperando respuesta del PS
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.tealAccent)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text(
              'Solicitud enviada — esperando aprobación de tu PS. Te notificaremos cuando esté listo.',
              style: TextStyle(
                  color: Colors.tealAccent, fontSize: 13, height: 1.4),
            )),
          ]),
        );

      default:
        // User con PS asignado — puede solicitar
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _solicitarAcceso,
            style: ElevatedButton.styleFrom(
              backgroundColor: BioConfig.colorPrimario.withValues(alpha: 0.15),
              foregroundColor: BioConfig.colorPrimario,
              side: BorderSide(
                  color: BioConfig.colorPrimario.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Solicitar este sonido a mi PS',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
    }
  }

  // ── Enviar solicitud al PS ────────────────────────────────────────────────
  Future<void> _solicitarAcceso() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_medicoIdAsignado == null || _medicoIdAsignado!.trim().isEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      _medicoIdAsignado = await _resolverPsAsignadoDetalle(user.uid, userData);
      if (_medicoIdAsignado == null || _medicoIdAsignado!.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo resolver tu PS asignado. Intenta nuevamente en unos segundos.',
              ),
            ),
          );
        }
        return;
      }
    }

    try {
      final nombreSonido = widget.sonidoData['Nombre'] ?? widget.sonidoId;
      final nombrePaciente = user.displayName ?? user.email ?? user.uid;
      String psNombre = 'PS asignado';
      if (_medicoIdAsignado != null && _medicoIdAsignado!.trim().isNotEmpty) {
        try {
          final psDoc = await FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .doc(_medicoIdAsignado!.trim())
              .get();
          psNombre = _textoCampo(psDoc.data()?['nombre']).isNotEmpty
              ? _textoCampo(psDoc.data()?['nombre'])
              : _textoCampo(psDoc.data()?['email']).isNotEmpty
                  ? _textoCampo(psDoc.data()?['email'])
                  : psNombre;
        } catch (_) {}
      }
      // Crear solicitud en Firestore
      await FirebaseFirestore.instance
          .collection(BioConfig.colSolicitudesPrescripcion)
          .add({
        'paciente_id': user.uid,
        'paciente_nombre': nombrePaciente,
        'medico_id': _medicoIdAsignado,
        'sonido_id': widget.sonidoId,
        'sonido_nombre': nombreSonido,
        'nombre_sonido': nombreSonido,
        'estado': 'pendiente',
        'fecha': FieldValue.serverTimestamp(),
        'fecha_solicitud': FieldValue.serverTimestamp(),
      });

      if (_medicoIdAsignado != null && _medicoIdAsignado!.trim().isNotEmpty) {
        await BioNotif.solicitudRecibidaPS(
          _medicoIdAsignado!.trim(),
          nombrePaciente,
          nombreSonido.toString(),
          'detalle_sonido',
        );
      }
      await BioNotif.adminSolicitudReceta(
        paciente: nombrePaciente,
        sonido: nombreSonido.toString(),
        psNombre: psNombre,
      );

      // Invalidar caché para que recargue el estado
      final cacheKey = '${user.uid}_${widget.sonidoId}';
      _accesoCache.remove(cacheKey);

      if (mounted) {
        setState(() => _estadoReceta = _EstadoReceta.pendienteSolicitud);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF0D3D2A),
          content: Text(
              '✅ Solicitud enviada a tu PS — te avisaremos cuando la apruebe'),
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error enviando solicitud: $e')));
      }
    }
  }

  // ── Registrar uso del sonido sin crear documentos nuevos ──────────────────
  // Actualiza solo 2 campos en el doc del sonido:
  //   total_usos: contador incremental
  //   ultimos_usos: array con los últimos 10 usos (rota automáticamente)
  Future<void> _registrarUsoSonido(
      String sId, String sNombre, String uid, String uNombre) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection(BioConfig.colSonidos).doc(sId);

      // Leer ultimos_usos actual para rotar (mantener solo últimos 10)
      final snap = await ref.get();
      final actual = List<dynamic>.from(snap.data()?['ultimos_usos'] ?? []);

      // Insertar nuevo uso al inicio
      actual.insert(0, {
        'uid': uid,
        'nombre': uNombre,
        'fecha': Timestamp.now(),
      });

      // Mantener solo los últimos 10
      final rotado = actual.take(10).toList();

      await ref.update({
        'total_usos': FieldValue.increment(1),
        'ultimos_usos': rotado,
      });
    } catch (e) {
      debugPrint('[Uso] Error registrando: $e');
    }
  }

  // ── Reproducir sonido ─────────────────────────────────────────────────────
  Future<({bool ok, int? totalTokens})> _validarUsoServidor(
    User user,
    int ciclos,
  ) async {
    final requiereServidor = _requiereValidacionServidor;
    try {
      final idToken = await user.getIdToken();
      final resp = await http
          .post(
            Uri.parse(BioConfig.validarUsoSonidoSensibleUrl),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'sonido_id': widget.sonidoId,
              'ciclos': ciclos,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final raw =
          resp.body.isEmpty ? <String, dynamic>{} : jsonDecode(resp.body);
      final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      final permitido = data['permitido'] == true || data['ok'] == true;

      if (resp.statusCode >= 200 && resp.statusCode < 300 && permitido) {
        final costo = data['costo_estimado'];
        final total = costo is Map
            ? BioConfig.toInt(costo['total_tokens'])
            : BioConfig.toInt(data['total_tokens']);
        return (ok: true, totalTokens: total > 0 ? total : null);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_mensajeValidacionUso(data['motivo'] ?? data['error'])),
        ));
      }
      return (ok: false, totalTokens: null);
    } catch (e, stackTrace) {
      await Sentry.captureException(
        e,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('flow', 'sound_use_validation');
          scope.setContexts('sound_use_validation', {
            'sonido_id': widget.sonidoId,
            'ciclos': ciclos,
            'requiere_servidor': requiereServidor,
          });
        },
      );

      if (requiereServidor) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
              'No se pudo validar la receta. Revisa tu conexion e intenta de nuevo.',
            ),
          ));
        }
        return (ok: false, totalTokens: null);
      }

      return (ok: true, totalTokens: null);
    }
  }

  String _mensajeValidacionUso(dynamic motivoRaw) {
    final motivo = motivoRaw?.toString() ?? '';
    switch (motivo) {
      case 'usuario_suspendido':
        return 'Tu cuenta esta suspendida. Contacta al administrador.';
      case 'sonido_no_disponible':
        return 'Este sonido aun no esta disponible.';
      case 'nivel_insuficiente':
        return 'Tu nivel actual no permite usar este sonido.';
      case 'sin_acceso_o_receta':
      case 'acceso_no_aprobado':
        return 'Este sonido requiere autorizacion de tu PS.';
      case 'receta_pendiente_pago':
        return 'La receta esta aprobada, pero falta completar el pago.';
      case 'receta_inactiva':
      case 'ciclo_bloqueado':
        return 'Tu receta no esta activa para este ciclo.';
      case 'ciclos_no_autorizados':
      case 'sesiones_insuficientes':
        return 'La receta no tiene sesiones suficientes para esos ciclos.';
      default:
        return 'No se pudo autorizar el uso de este sonido.';
    }
  }

  Future<void> _reproducir() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_duracionSeg == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("⏳ Cargando audio, espera un momento...")));
      return;
    }
    // Validar repeticiones: mínimo 1, máximo 100
    if (_repeticiones < 1 || _repeticiones > 100) {
      setState(() => _repeticiones = 1);
    }

    // Variables para cobro post-play (solo aplica si no es PS/tester)
    int _tokensACobrar = 0;
    int _saldoAntes = 0;

    // ── Modo tester o PS con plan activo: sin cobro de tokens ─────────────
    // Rol viene del parámetro widget.rolUsuario — sin llamadas Firestore
    final rolActualRep = ViewAsManager().rolEfectivo(widget.rolUsuario);
    final esPS =
        rolActualRep == BioConfig.rolPS || rolActualRep == BioConfig.rolAdmin;
    int? totalTokensServidor;

    if (_esTester || esPS) {
      debugPrint("âš¡ Acceso gratuito: tester=$_esTester esPS=$esPS");
      setState(() {
        _reproduciendo = true;
        _repeticionesRestantes = _repeticiones;
      });
    } else {
      // ── Usuario normal: verificar saldo fresco de Firestore (evita race condition) ──
      if (_requiereValidacionServidor) {
        final validacion = await _validarUsoServidor(user, _repeticiones);
        if (!validacion.ok) return;
        totalTokensServidor = validacion.totalTokens;
      }

      final uid2 = FirebaseAuth.instance.currentUser?.uid;
      int saldoActual = _saldoActual;
      if (uid2 != null) {
        try {
          final doc2 = await FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .doc(uid2)
              .get();
          saldoActual = BioConfig.toInt(doc2.data()?[BioConfig.campoTokens]);
          if (mounted) setState(() => _saldoActual = saldoActual);
        } catch (_) {/* usar valor en memoria si falla */}
      }

      // ── COBRO HÍBRIDO: usar getter centralizado _precioUnitario ─────────
      final int precioUnitario = _precioUnitario;
      if (_precioFijoTokens == 0 && precioUnitario <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Midiendo duracion real del audio. Intenta de nuevo en unos segundos.'),
        ));
        return;
      }

      final int precioEfectivo = precioUnitario;
      int totalTokens = totalTokensServidor ?? (precioEfectivo * _repeticiones);

      if (saldoActual < totalTokens) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Saldo insuficiente. Necesitas $totalTokens tokens."),
          action: SnackBarAction(
              label: "COMPRAR",
              textColor: Colors.cyan,
              onPressed: () => Navigator.pop(context)),
        ));
        return;
      }

      setState(() {
        _reproduciendo = true;
        _repeticionesRestantes = _repeticiones;
      });
      // ⚠️  Cobro se hace DESPUÉS de confirmar reproducción exitosa (ver abajo)
      // Variables capturadas para cobrar tras el play
      _tokensACobrar = totalTokens;
      _saldoAntes = saldoActual;

      if (mounted) {
        final totalCop = (_tokensACobrar * _valorTokenCop).toStringAsFixed(0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "▶️ $_repeticiones reproduccion${_repeticiones == 1 ? '' : 'es'} "
                "— -$_tokensACobrar tokens ($totalCop COP)")));
      }
    }

    // Registrar uso — sin crear documentos nuevos
    if (!_esTester) {
      final String uidSafe = user.uid;
      final String sId = widget.sonidoId;
      final String sNombre = widget.sonidoData['Nombre'] as String? ?? sId;
      final String uNombre = user.displayName ?? user.email ?? uidSafe;
      // 1. Sonido: +1 al contador + mantener últimos 10 usos (array rotativo)
      unawaited(_registrarUsoSonido(sId, sNombre, uidSafe, uNombre));
      // 2. Usuario: +1 al contador de ese sonido en su historial
      unawaited(FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(uidSafe)
          .update({
        'historico_sonidos.$sId': FieldValue.increment(1)
      }).catchError((_) {}));
    }

    // play() garantiza inicio limpio desde el principio
    final _modo = ReproduccionConfig().modo;
    if (_modo != ModoReproduccion.vibracion) {
      final _url = _urlPreferidaAudio();
      debugPrint('[Audio] Reproduciendo stream preparado: ${_urlAudioResuelta ?? _resolverUrlAudio(_url)}');
      if (_url.isEmpty) {
        debugPrint(
            '[Audio] ⚠️  url_sonido está vacío — no se puede reproducir');
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  '⚠️ Este sonido no tiene archivo de audio configurado')));
        return;
      }
      try {
        // Usa la fuente precargada: seek(0) + play() evita reabrir si ya esta lista.
        await _reproducirAudioPreparado();
        if (mounted) setState(() => _audioBuffereado = true);
        debugPrint('[Audio] ✅ play() llamado sobre fuente preparada');
        // Escrituras Firestore en background — no bloquean el hilo de audio
        if (_tokensACobrar > 0) {
          unawaited(FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .doc(user.uid)
              .update({
            BioConfig.campoTokens: FieldValue.increment(-_tokensACobrar)
          }));
        }
        unawaited(FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .collection(BioConfig.colAccesosSonidos)
            .doc(widget.sonidoId)
            .update({'ultimo_uso': FieldValue.serverTimestamp()}));
        if (mounted)
          setState(() => _saldoActual = _saldoAntes - _tokensACobrar);
      } catch (e) {
        debugPrint('[Audio] ❌ Error en setSource/resume: $e');
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error reproduciendo audio: $e')));
    }
  } else {
    await _player.stop(); // silencio total (modo solo vibración)
    _fuenteAudioLista = false;
    // En modo vibración puro, disparar vibración directamente
      // (el listener de onPlayerStateChanged no llega a PlayerState.playing)
      final _hexSonido =
          widget.sonidoData['scanner_color_hex'] as String? ?? '#00CCFF';
      HapticHelper.vibrarConHex(_hexSonido);
    }
    // La vibración en modo dual/audio la maneja onPlayerStateChanged
    // Arrancar timer de respaldo para la primera repetición
    _iniciarTimerRespaldo();
  }

  // ── Pausar ────────────────────────────────────────────────────────────────
  Future<void> _pausar() async {
    _bucleTimer?.cancel();
  try {
    await _player.stop();
    _fuenteAudioLista = false;
  } catch (e) {
      debugPrint('[Audio] stop() falló al pausar: $e');
    }
    await HapticHelper.detener();
    if (!mounted) return;
    setState(() {
      _reproduciendo = false;
      _repeticionesRestantes = 0;
      _procesandoBucle = false;
    });
  }

  // ── Lógica central del bucle ──────────────────────────────────────────────
  Future<void> _siguienteRepeticion() async {
    if (!mounted) return;
    _bucleTimer?.cancel();

    // En modo indefinido: cobrar 1 reproducción y reiniciar
    if (_repetirIndefinido) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && !_esTester) {
        final rolEfec2 = ViewAsManager().rolEfectivo(widget.rolUsuario);
        final esLibre =
            rolEfec2 == BioConfig.rolPS || rolEfec2 == BioConfig.rolAdmin;
        if (!esLibre) {
          // Usar saldo en memoria (sincronizado por StreamBuilder)
          // Cada 10 ciclos re-leer Firestore para evitar drift acumulado
          _ciclosIndefinido = (_ciclosIndefinido ?? 0) + 1;
          if (_ciclosIndefinido! % 10 == 0) {
            try {
              final docF = await FirebaseFirestore.instance
                  .collection(BioConfig.colUsuarios)
                  .doc(uid)
                  .get();
              if (mounted)
                setState(() => _saldoActual =
                    BioConfig.toInt(docF.data()?[BioConfig.campoTokens]));
            } catch (_) {}
          }
          final saldo = _saldoActual;
          if (saldo < _precioUnitario) {
            if (mounted) {
              setState(() {
                _reproduciendo = false;
                _repetirIndefinido = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('⏸ Reproducción pausada: saldo insuficiente')));
            }
            return;
          }
          unawaited(FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .doc(uid)
              .update({
            BioConfig.campoTokens: FieldValue.increment(-_precioUnitario)
          }).catchError((_) {}));
          if (mounted) setState(() => _saldoActual -= _precioUnitario);
        }
      }
      // Reiniciar el sonido
      await _reproducirAudioPreparado();
      return;
    }

    if (_repeticionesRestantes > 1) {
      setState(() => _repeticionesRestantes--);
      await _player.stop();
      _fuenteAudioLista = false;
      await Future.delayed(const Duration(milliseconds: 200));
      final _modoLoop = ReproduccionConfig().modo;
      if (_modoLoop != ModoReproduccion.vibracion) {
        await _reproducirAudioPreparado();
        // La vibración la activa onPlayerStateChanged cuando PlayerState.playing
      }
      if (_modoLoop == ModoReproduccion.vibracion) {
        // Modo vibración puro: re-disparar directamente (no hay evento playing)
        final _hexLoop =
            widget.sonidoData['scanner_color_hex'] as String? ?? '#00CCFF';
        HapticHelper.vibrarConHex(_hexLoop);
      }
      // Timer de respaldo: si onPlayerComplete no dispara, este sí lo hace
      _iniciarTimerRespaldo();
    } else {
      // ── Ciclo(s) completado(s) — registrar en Firestore ──────────────────
    await _registrarCicloCompletado();
    await _player.stop();
    _fuenteAudioLista = false;
      if (mounted)
        setState(() {
          _reproduciendo = false;
          _repeticionesRestantes = 0;
        });
    }
  }

  // ── Registrar uso completado + gestión de ciclo recetado ─────────────────
  Future<void> _registrarCicloCompletado() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String uid = user.uid;
    final String sonidoId = widget.sonidoId;
    final int ciclos = _repeticiones;

    try {
      final accesoRef = FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(uid)
          .collection(BioConfig.colAccesosSonidos)
          .doc(sonidoId);

      final batch = FirebaseFirestore.instance.batch();

      // Métricas base
      batch.set(
          accesoRef,
          {
            'sonido_id': sonidoId,
            'ultimo_uso': FieldValue.serverTimestamp(),
            'ciclos_completados': FieldValue.increment(ciclos),
          },
          SetOptions(merge: true));

      // Contar uso en el doc del sonido (sin crear documentos nuevos)
      batch.update(
          FirebaseFirestore.instance
              .collection(BioConfig.colSonidos)
              .doc(sonidoId),
          {'total_usos': FieldValue.increment(1)});

      await batch.commit();

      // ── Lógica de ciclo para sonidos recetados ──────────────────────────
      if (_estadoReceta == _EstadoReceta.activo && _datosAcceso.isNotEmpty) {
        final int sesPerCiclo = _datosAcceso['sesiones_por_ciclo'] as int? ?? 0;
        final int minutosEntre =
            _datosAcceso['minutos_entre_ciclos'] as int? ?? 0;
        final int diasTotal = _datosAcceso['dias_tratamiento'] as int? ?? 1;

        if (sesPerCiclo > 0) {
          // Decrementar sesiones_hoy atomicamente
          await accesoRef.update({
            'sesiones_hoy': FieldValue.increment(-ciclos),
            'sesiones_completadas': FieldValue.increment(ciclos),
            'ciclos_aplicados': FieldValue.increment(1),
          });

          // Releer para saber cuántas quedan
          final fresh = await accesoRef.get();
          final int sesHoyNow = fresh.data()?['sesiones_hoy'] as int? ?? 0;
          final int sesCompletadas =
              fresh.data()?['sesiones_completadas'] as int? ?? 0;
          final int sesionesTotales = sesPerCiclo * diasTotal;

          if (sesCompletadas >= sesionesTotales) {
            // ✅ Tratamiento completo
            await accesoRef.update({'tratamiento_activo': false});
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: Colors.green,
                content:
                    Text('🎉 ¡Tratamiento completado! Consulta con tu médico.'),
                duration: Duration(seconds: 4),
              ));
            }
          } else if (sesHoyNow <= 0 && minutosEntre > 0) {
            // Bloquear ciclo hasta próxima apertura
            final proximaApertura =
                DateTime.now().add(Duration(minutes: minutosEntre));
            await accesoRef.update({
              'sesiones_hoy': 0,
              'fecha_proximo_ciclo': Timestamp.fromDate(proximaApertura),
            });
            // Notificar al PS si saltó sesiones dentro del ciclo
            final String? medicoId = _datosAcceso['medico_id'] as String?;
            if (medicoId != null && sesHoyNow < 0) {
              await BioNotif.sesionSaltadaPS(
                  medicoId,
                  user.displayName ?? user.email ?? uid,
                  widget.sonidoData['Nombre'] as String? ?? sonidoId);
              await accesoRef.update({
                'sesiones_saltadas': FieldValue.increment(sesHoyNow.abs()),
              });
            }
          }
        }
      }

      // fecha_primer_uso solo la primera vez
      final accesoSnap = await accesoRef.get();
      if (!accesoSnap.exists ||
          accesoSnap.data()?['fecha_primer_uso'] == null) {
        await accesoRef
            .update({'fecha_primer_uso': FieldValue.serverTimestamp()});
      }
      debugPrint('✅ Ciclo registrado: $ciclos rep de $sonidoId');
    } catch (e) {
      debugPrint('⚠️  Error registrando ciclo: $e');
    }
  }

  // Timer que dispara la siguiente repetición basado en duración real
  void _iniciarTimerRespaldo() {
    _bucleTimer?.cancel();
    if (_duracionSeg <= 0) return;
    // Espera la duración del sonido + 500ms de margen
    _bucleTimer = Timer(
      Duration(milliseconds: (_duracionSeg * 1000) + 500),
      () async {
        if (!mounted || !_reproduciendo) return;
        // Solo actuar si onPlayerComplete NO lo manejó ya
        if (_repeticionesRestantes > 0 && !_procesandoBucle) {
          _procesandoBucle = true;
          await _siguienteRepeticion();
          _procesandoBucle = false;
        }
      },
    );
  }

  // ── Modal de bucle — pregunta cuántas veces reproducir ───────────────────
  Future<void> _mostrarModalBucle() async {
    // Leer saldo fresco de Firestore antes de abrir el modal
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(uid)
            .get();
        final saldoFresco = BioConfig.toInt(doc.data()?[BioConfig.campoTokens]);
        if (mounted) setState(() => _saldoActual = saldoFresco);
      } catch (_) {}
    }

    bool repetirIndefinido = false;
    final TextEditingController ctrl =
        TextEditingController(text: _repeticiones.toString());

    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        isScrollControlled: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              int reps = repetirIndefinido ? 1 : (int.tryParse(ctrl.text) ?? 1);
              if (reps < 1) reps = 1;
              final int precioUnit = _precioUnitario;
              // En modo indefinido: costo = 1 reproducción (se cobra por cada una)
              int totalTokens =
                  repetirIndefinido ? precioUnit : reps * precioUnit;
              double totalCop = totalTokens * _valorTokenCop;
              final rolEfec = ViewAsManager().rolEfectivo(widget.rolUsuario);
              bool alcanzaSaldo = _esTester ||
                      (rolEfec == BioConfig.rolPS ||
                          rolEfec == BioConfig.rolAdmin)
                  ? true
                  : _saldoActual >=
                      precioUnit; // alcanza al menos 1 reproducción

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
                    const Text("🔁 Configurar reproducción",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text("¿Cuántas veces quieres reproducir el sonido?",
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 20),

                    // Campo numérico
                    TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        hintText: "1",
                        hintStyle: const TextStyle(color: Colors.white24),
                      ),
                      onChanged: (v) => setModalState(() {}),
                    ),
                    const SizedBox(height: 8),

                    // Botones rápidos
                    // Toggle ∞ repetición indefinida
                    GestureDetector(
                      onTap: () => setModalState(
                          () => repetirIndefinido = !repetirIndefinido),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: repetirIndefinido
                              ? BioConfig.colorPrimario.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: repetirIndefinido
                                  ? BioConfig.colorPrimario
                                  : Colors.white12),
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.all_inclusive_rounded,
                                  color: repetirIndefinido
                                      ? BioConfig.colorPrimario
                                      : Colors.white38,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text('Repetir indefinidamente',
                                  style: TextStyle(
                                      color: repetirIndefinido
                                          ? BioConfig.colorPrimario
                                          : Colors.white38,
                                      fontWeight: FontWeight.w600)),
                              if (repetirIndefinido) ...[
                                const SizedBox(width: 6),
                                Text('(cobro por cada reproducción)',
                                    style: TextStyle(
                                        color: BioConfig.colorPrimario
                                            .withValues(alpha: 0.6),
                                        fontSize: 11)),
                              ],
                            ]),
                      ),
                    ),

                    // Cantidades rápidas (deshabilitadas en modo ∞)
                    if (!repetirIndefinido)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [3, 7, 14, 27, 40]
                            .map(
                              (n) => GestureDetector(
                                onTap: () {
                                  ctrl.text = n.toString();
                                  setModalState(() {});
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: BioConfig.colorPrimario
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: BioConfig.colorPrimario
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text("×$n",
                                      style: TextStyle(
                                          color: BioConfig.colorPrimario,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 20),

                    // Tabla de costo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: alcanzaSaldo
                                ? Colors.white12
                                : Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Column(children: [
                        // Mostrar modo de cobro activo
                        if (_precioFijoTokens > 0)
                          _filaCosto("Precio por sesión (fijo):",
                              "$_precioFijoTokens tokens")
                        else
                          _filaCosto("Duración × tarifa:",
                              "$_duracionSeg s × ${_tarifaBasePorSeg.toInt()} t/s"),
                        _filaCosto("Repeticiones:", "× $reps"),
                        const Divider(color: Colors.white12),
                        _filaCosto("Total tokens:", "$totalTokens tokens",
                            destacado: true),
                        _filaCosto("Total en pesos:",
                            "${totalCop.toStringAsFixed(0)} COP",
                            destacado: true),
                        _filaCosto("Tu saldo actual:", "$_saldoActual tokens",
                            color: alcanzaSaldo
                                ? Colors.greenAccent
                                : Colors.redAccent),
                        if (!alcanzaSaldo)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "⚠️ Saldo insuficiente. Necesitas ${totalTokens - _saldoActual} tokens más.",
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Botón confirmar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: alcanzaSaldo
                              ? BioConfig.colorPrimario
                              : Colors.grey[800],
                          foregroundColor:
                              alcanzaSaldo ? Colors.black : Colors.grey[600],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(
                            alcanzaSaldo
                                ? Icons.play_arrow_rounded
                                : Icons.lock_outline,
                            size: 22),
                        label: Text(
                          alcanzaSaldo
                              ? "Iniciar $reps reproduccion${reps == 1 ? '' : 'es'}"
                              : "Saldo insuficiente",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: alcanzaSaldo
                            ? () {
                                if (!mounted) return;
                                setState(() {
                                  _repeticiones =
                                      repetirIndefinido ? 999999 : reps;
                                  _repetirIndefinido = repetirIndefinido;
                                });
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                _reproducir();
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      ctrl.dispose();
    }
  }

  // Fila helper para la tabla de costos
  Widget _filaCosto(String label, String valor,
      {bool destacado = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white54, fontSize: destacado ? 13 : 12)),
          Text(valor,
              style: TextStyle(
                  color: color ?? (destacado ? Colors.amber : Colors.white70),
                  fontSize: destacado ? 14 : 12,
                  fontWeight: destacado ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _bucleTimer?.cancel();
    _contadorTimer?.cancel();
    _desactivarFlagSeguro();
    // MEJORA 2: cancelar vibración antes de destruir el player
    HapticHelper.detener();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String nombre = widget.sonidoData['Nombre'] ?? 'Frecuencia';
    final String descripcion = widget.sonidoData['descripcion'] ?? '';
    final String urlVideo = widget.sonidoData['url_video'] ?? '';

    final double costoTokensCop = _precioUnitario * _valorTokenCop;

    // ── Pantallas especiales de receta ───────────────────────────────────
    if (_estadoReceta == _EstadoReceta.pendientePago ||
        _estadoReceta == _EstadoReceta.bloqueadoCiclo ||
        _estadoReceta == _EstadoReceta.completado) {
      return _pantallaReceta();
    }

    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      appBar: AppBar(
        backgroundColor: BioConfig.colorFondo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _player.stop();
            Navigator.pop(context);
          },
        ),
        title: Row(children: [
          Expanded(
              child: Text(nombre,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
          // Indicador de estado de carga en el title
          if (_cargandoAcceso)
            const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white38)))
          else if (!_audioBuffereado && !_sonidoBloqueado)
            Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.tealAccent)),
                  const SizedBox(width: 5),
                  const Text('cargando',
                      style: TextStyle(color: Colors.tealAccent, fontSize: 11)),
                ]))
          else if (_audioBuffereado && !_reproduciendo && !_sonidoBloqueado)
            const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle_outline,
                    color: Colors.greenAccent, size: 16)),
        ]),
        actions: [
          // Indicador de días restantes
          if (!_sonidoBloqueado && _contadorTexto.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Row(children: [
                        Icon(Icons.lock_clock, color: BioConfig.colorPrimario),
                        SizedBox(width: 10),
                        Text("Acceso activo",
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                      ]),
                      content: Text(
                        "En $_contadorTexto (DD:HH:MM:SS) este sonido "
                        "se volverá a bloquear por video y, por tu seguridad, "
                        "tendrás que ver nuevamente las instrucciones.",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Entendido",
                              style: TextStyle(color: BioConfig.colorPrimario)),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BioConfig.colorPrimario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: BioConfig.colorPrimario.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    "🔓 $_contadorTexto",
                    style: TextStyle(
                        color: BioConfig.colorPrimario,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _cargandoAcceso
          ? Center(
              child: CircularProgressIndicator(color: BioConfig.colorPrimario))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              controller: _scrollCtrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Descripción ─────────────────────────────────────
                  if (descripcion.isNotEmpty) ...[
                    Text(descripcion,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14, height: 1.5)),
                    const SizedBox(height: 20),
                  ],

                  // ── Contador global de usos ─────────────────────────
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(BioConfig.colSonidos)
                        .doc(widget.sonidoId)
                        .snapshots(),
                    builder: (_, snap) {
                      int usos = snap.hasData && snap.data!.exists
                          ? BioConfig.toInt(snap.data!['total_usos'])
                          : 0;
                      if (usos == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(children: [
                          const Icon(Icons.bar_chart,
                              color: Colors.white38, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Usado $usos ${usos == 1 ? 'vez' : 'veces'} por la comunidad",
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ]),
                      );
                    },
                  ),

                  // ── Costo en tokens y pesos ──────────────────────────
                  if (_duracionSeg > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: _esTester
                              ? Colors.amber.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: _esTester
                              ? Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3))
                              : null),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              _esTester ? "Modo Tester ⚡" : "Costo por sesión:",
                              style: TextStyle(
                                  color:
                                      _esTester ? Colors.amber : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(
                              _esTester
                                  ? "Reproducción gratuita"
                                  : "${_precioUnitario} tokens (${costoTokensCop.toStringAsFixed(0)} COP)",
                              style: TextStyle(
                                  color:
                                      _esTester ? Colors.amber : Colors.amber,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ── ACCESO BLOQUEADO: flujo según estado ─────────────
                  if (_sonidoBloqueado) ...[
                    const SizedBox(height: 8),
                    _widgetAccesoBloqueado(),
                  ],

                  const SizedBox(height: 8),
                  // Video ahora es tutorial opcional
                  if (widget.sonidoData['url_video'] != null &&
                      (widget.sonidoData['url_video'] as String)
                          .isNotEmpty) ...[
                    const Text("📹 VIDEO TUTORIAL",
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),

                    // Botón del video
                    GestureDetector(
                      onTap: () {
                        if (urlVideo.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                "⏳ El video de este sonido estará disponible pronto."),
                          ));
                          return;
                        }
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PantallaVideoCompleto(
                                videoUrl: urlVideo,
                                nombreSonido: nombre,
                                onVideoTerminado: null,
                              ),
                            ));
                      },
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: urlVideo.isEmpty
                              ? Colors.white.withValues(alpha: 0.03)
                              : _sonidoBloqueado
                                  ? Colors.red.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: urlVideo.isEmpty
                                ? Colors.white12
                                : _sonidoBloqueado
                                    ? Colors.red.withValues(alpha: 0.5)
                                    : Colors.white12,
                          ),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 16),
                          Icon(
                            urlVideo.isEmpty
                                ? Icons.hourglass_top
                                : _sonidoBloqueado
                                    ? Icons.play_circle
                                    : Icons.play_circle_outline,
                            color: urlVideo.isEmpty
                                ? Colors.white24
                                : _sonidoBloqueado
                                    ? Colors.redAccent
                                    : Colors.white38,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                urlVideo.isEmpty
                                    ? "Video disponible pronto"
                                    : _sonidoBloqueado
                                        ? "▶ Ver video para desbloquear"
                                        : "▶ Ver video tutorial",
                                style: TextStyle(
                                    color: urlVideo.isEmpty
                                        ? Colors.white24
                                        : _sonidoBloqueado
                                            ? Colors.redAccent
                                            : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              Text(
                                  urlVideo.isEmpty
                                      ? "Lo estamos preparando para ti"
                                      : _sonidoBloqueado
                                          ? "Requerido antes de usar el sonido"
                                          : "Opcional — puedes verlo cuando quieras",
                                  style: const TextStyle(
                                      color: Colors.white24, fontSize: 11)),
                            ],
                          )),
                          const SizedBox(width: 12),
                        ]),
                      ),
                    ),
                  ], // fin if url_video

                  // ── REPRODUCTOR estilo Mi Music ──────────────────────
                  const SizedBox(height: 32),
                  Builder(builder: (_) {
                    // audioListo = el player tiene el source cargado y listo
                    // (no depende de _duracionSeg que puede ser el fallback 60s)
                    final audioListo = _audioBuffereado;
                    final Color accent = BioConfig.colorPrimario;

                    return Column(children: [
                      // ── Nombre del sonido ─────────────────────────────
                      Text(
                        nombre,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descripcion.isEmpty
                            ? 'Frecuencia Bioacústica'
                            : descripcion,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13),
                      ),

                      const SizedBox(height: 40),

                      // ── Barra de progreso (real si está sonando, indeterminada si carga) ──
                      if (_reproduciendo)
                        Column(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _repeticiones > 0
                                  ? (_repeticiones -
                                          _repeticionesRestantes +
                                          1) /
                                      _repeticiones
                                  : 0,
                              minHeight: 3,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rep. ${_repeticiones - _repeticionesRestantes + 1} de $_repeticiones',
                                style: TextStyle(color: accent, fontSize: 11),
                              ),
                              Text(
                                _duracionSeg > 0 ? '${_duracionSeg}s' : '',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ])
                      else if (!audioListo)
                        // Barra indeterminada mientras carga el buffer
                        Column(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  accent.withValues(alpha: 0.6)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('Preparando audio...',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ])
                      else
                        // Barra vacía en reposo
                        Column(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: 0,
                              minHeight: 3,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _sonidoBloqueado
                                ? '🔒 Sonido bloqueado'
                                : 'Listo para reproducir',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ]),

                      const SizedBox(height: 36),

                      // ── Controles principales ─────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Botón de repeticiones (izquierda)
                          GestureDetector(
                            onTap: (_reproduciendo ||
                                    _sonidoBloqueado ||
                                    !_audioBuffereado)
                                ? null
                                : _mostrarModalBucle,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              child: Icon(Icons.repeat_rounded,
                                  color: (_reproduciendo ||
                                          _sonidoBloqueado ||
                                          !_audioBuffereado)
                                      ? Colors.white12
                                      : Colors.white54,
                                  size: 22),
                            ),
                          ),

                          const SizedBox(width: 28),

                          // ── Botón central PLAY / PAUSE / LOADING ─────
                          _sonidoBloqueado
                              ? GestureDetector(
                                  onTap: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              '🔒 Desbloquea el sonido primero'))),
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.06),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: const Icon(Icons.lock_outline,
                                        color: Colors.white24, size: 30),
                                  ),
                                )
                              : !audioListo
                                  // CARGANDO — no se puede tocar
                                  ? Stack(
                                      alignment: Alignment.center,
                                      children: [
                                          SizedBox(
                                            width: 72,
                                            height: 72,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: accent,
                                            ),
                                          ),
                                          Icon(Icons.music_note_rounded,
                                              color:
                                                  accent.withValues(alpha: 0.5),
                                              size: 28),
                                        ])
                                  : _reproduciendo
                                      // REPRODUCIENDO → toca para pausar
                                      ? GestureDetector(
                                          onTap: _pausar,
                                          child: Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: accent,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: accent.withValues(
                                                        alpha: 0.45),
                                                    blurRadius: 24,
                                                    spreadRadius: 2)
                                              ],
                                            ),
                                            child: const Icon(
                                                Icons.pause_rounded,
                                                color: Colors.black,
                                                size: 36),
                                          ),
                                        )
                                      // LISTO → toca para reproducir directamente
                                      : GestureDetector(
                                          onTap: _reproducir,
                                          child: Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: accent,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: accent.withValues(
                                                        alpha: 0.45),
                                                    blurRadius: 24,
                                                    spreadRadius: 2)
                                              ],
                                            ),
                                            child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.black,
                                                size: 36),
                                          ),
                                        ),

                          const SizedBox(width: 28),

                          // Costo por sesión (derecha)
                          GestureDetector(
                            onTap: null,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.toll_rounded,
                                      color: _esTester
                                          ? Colors.amber
                                          : Colors.white38,
                                      size: 18),
                                  Text(
                                    _esTester
                                        ? 'free'
                                        : _precioUnitario >= 1000
                                            ? '${(_precioUnitario / 1000).toStringAsFixed(1)}k'
                                            : '$_precioUnitario',
                                    style: TextStyle(
                                      color: _esTester
                                          ? Colors.amber
                                          : Colors.white38,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ]);
                  }),
                ],
              ),
            ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA VIDEO COMPLETO — sin botones skip, sin adelantar
// ═════════════════════════════════════════════════════════════════════════════
class PantallaVideoCompleto extends StatefulWidget {
  final String videoUrl;
  final String nombreSonido;
  final VoidCallback? onVideoTerminado; // null si es vista voluntaria

  const PantallaVideoCompleto({
    super.key,
    required this.videoUrl,
    required this.nombreSonido,
    this.onVideoTerminado,
  });

  @override
  State<PantallaVideoCompleto> createState() => _PantallaVideoCompletoState();
}

class _PantallaVideoCompletoState extends State<PantallaVideoCompleto> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _cargando = true;
  bool _videoTerminado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      // Limpiar URL: quitar transformaciones de Cloudinary que causan redirecciones
      String urlLimpia = widget.videoUrl;
      // Si es Cloudinary con f_auto,q_auto u otras transformaciones, usar URL directa
      if (urlLimpia.contains('cloudinary.com') &&
          urlLimpia.contains('/upload/')) {
        final uploadIdx = urlLimpia.indexOf('/upload/');
        final despuesUpload =
            urlLimpia.substring(uploadIdx + 8); // después de /upload/
        // Si hay transformaciones antes del nombre del archivo (contiene /)
        // Las transformaciones son todo lo que va antes del último segmento con v+números
        final versionMatch = RegExp(r'v\d+/').firstMatch(despuesUpload);
        if (versionMatch != null) {
          urlLimpia = urlLimpia.substring(0, uploadIdx + 8) +
              despuesUpload.substring(versionMatch.start);
        }
      }

      _videoController = VideoPlayerController.networkUrl(Uri.parse(urlLimpia),
          httpHeaders: const {'User-Agent': 'BioFreq/2.0'});
      await _videoController!.initialize().timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception(
                "Tiempo de carga agotado. Verifica tu conexión."),
          );

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: false,
        allowMuting: false,
        showControls: false, // Ocultamos controles de Chewie
        showOptions: false,
        allowPlaybackSpeedChanging: false,
      );

      // Detectar fin del video
      _videoController!.addListener(() {
        if (!mounted) return;
        final pos = _videoController!.value.position;
        final dur = _videoController!.value.duration;
        if (dur.inSeconds > 0 && pos >= dur - const Duration(seconds: 1)) {
          if (!_videoTerminado) {
            setState(() => _videoTerminado = true);
            widget.onVideoTerminado?.call();
          }
        }
      });

      if (mounted) {
        setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error cargando video: $e";
          _cargando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.nombreSonido,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
      body: Column(children: [
        // Banner informativo
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _videoTerminado
              ? Colors.green.withValues(alpha: 0.2)
              : BioConfig.colorPrimario.withValues(alpha: 0.1),
          child: Text(
            _videoTerminado
                ? "✅ Video completado. Regresa para desbloquear el sonido."
                : widget.onVideoTerminado != null
                    ? "👁 Mira el video completo para desbloquear esta frecuencia."
                    : "▶ Reproduciendo tutorial.",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _videoTerminado ? Colors.greenAccent : Colors.white70,
                fontSize: 12),
          ),
        ),
        // Reproductor
        Expanded(
          child: _cargando
              ? Center(
                  child:
                      CircularProgressIndicator(color: BioConfig.colorPrimario))
              : _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 14))))
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Chewie(controller: _chewieController!),
                        // Overlay de controles propios (sin skip)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(children: [
                              // Play/Pause
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_videoController!.value.isPlaying) {
                                      _videoController!.pause();
                                    } else {
                                      _videoController!.play();
                                    }
                                  });
                                },
                                child: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Barra de progreso
                              Expanded(
                                child: VideoProgressIndicator(
                                  _videoController!,
                                  allowScrubbing: false, // No permite adelantar
                                  colors: VideoProgressColors(
                                    playedColor: BioConfig.colorPrimario,
                                    bufferedColor: Colors.white30,
                                    backgroundColor: Colors.white10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Tiempo
                              ValueListenableBuilder(
                                valueListenable: _videoController!,
                                builder: (_, val, __) {
                                  final pos = val.position;
                                  final dur = val.duration;
                                  String fmt(Duration d) =>
                                      '${d.inMinutes.toString().padLeft(2, '0')}:'
                                      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
                                  return Text(
                                    '${fmt(pos)} / ${fmt(dur)}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                  );
                                },
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
        ),
        // Botón volver al terminar
        if (_videoTerminado)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: BioConfig.colorPrimario,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text("Volver a la frecuencia",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA INVESTIGACIÓN — donaciones, progreso, ensayos
// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA RETIROS Y TESTIMONIOS
// ═════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════
// PANTALLA ADMIN
// ═══════════════════════════════════════════════
