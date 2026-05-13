// ======================================================================
// BioFreq — Módulo: auth
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

class CheckReferralWrapper extends StatefulWidget {
  final VersionInfo? remoteVersion;
  const CheckReferralWrapper({super.key, this.remoteVersion});
  @override
  State<CheckReferralWrapper> createState() => _CheckReferralWrapperState();
}

class _CheckReferralWrapperState extends State<CheckReferralWrapper> {
  bool _verificandoDuplicado = false;

  // ⚠️  Al detectar que el UID no tiene doc en Firestore, antes de crear uno nuevo
  //     verificamos si ya existe otro doc con el mismo email (cuenta duplicada).
  //     Si existe → ofrecemos fusionar. Esto evita que el mismo usuario acumule
  //     múltiples cuentas por reinstalaciones o cambios de dispositivo.
  Future<void> _verificarDuplicadoPorEmail(
      BuildContext ctx, String uid, String email) async {
    setState(() => _verificandoDuplicado = true);
    try {
      if (ctx.mounted) {
        Navigator.of(ctx).pushReplacement(
            MaterialPageRoute(builder: (_) => const ReferralScreen()));
      }
    } catch (e) {
      debugPrint('[DuplicateCheck] Error: \$e');
      if (ctx.mounted) {
        Navigator.of(ctx).pushReplacement(
            MaterialPageRoute(builder: (_) => const ReferralScreen()));
      }
    } finally {
      if (mounted) setState(() => _verificandoDuplicado = false);
    }
  }

  // ── Fusionar: copiar datos del doc viejo al UID nuevo, borrar el viejo ─────
  // ⚠️  Estrategia: el UID activo (nuevo login) se queda, sus datos se enriquecen
  //     con los de la cuenta vieja. Los tokens se SUMAN. Se conserva el código
  //     afiliado de la cuenta más antigua (tiene historial de referidos).
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (_verificandoDuplicado) {
      return const Scaffold(
          body: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verificando cuenta…',
                style: TextStyle(color: Colors.white54)),
          ])));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // ⚠️  Antes de ir a ReferralScreen, verificar si hay duplicado por email
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_verificandoDuplicado && user?.email != null) {
              _verificarDuplicadoPorEmail(context, user!.uid, user.email!);
            } else if (user?.email == null) {
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ReferralScreen()));
            }
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final suspendido = data[BioConfig.campoSuspendido] == true ||
            (data[BioConfig.campoEstadoCuenta]?.toString().toLowerCase() ==
                'suspendida');
        if (suspendido) {
          return const PantallaCuentaSuspendida();
        }
        return PantallaListaSonidos(remoteVersion: widget.remoteVersion);
      },
    );
  }
}

class PantallaCuentaSuspendida extends StatelessWidget {
  const PantallaCuentaSuspendida({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 72, color: Colors.redAccent.shade200),
              const SizedBox(height: 18),
              const Text(
                'Cuenta suspendida',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu acceso a BioFreq fue suspendido. Si crees que esto fue un error, contacta al equipo de BioFreq.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA: Registro de referido
// ─────────────────────────────────────────────
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final refController = TextEditingController();
  bool validando = false;

  @override
  void dispose() {
    refController.dispose();
    super.dispose();
  }

  String _generarCodigoPropio() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return "BIO-${List.generate(5, (i) => chars[Random().nextInt(chars.length)]).join()}";
  }

  // ignore: unused_element
  Future<void> _validarYRegistrar() async {
    String cod = refController.text.trim().toUpperCase();
    if (cod.isEmpty) return;
    setState(() => validando = true);
    try {
      // Verificar código maestro desde Firestore (evita que esté en el APK)
      String codigoMaestroActual = BioConfig.codigoMaestro; // fallback local
      try {
        final configDoc = await FirebaseFirestore.instance
            .collection(BioConfig.colConfiguracion)
            .doc('app')
            .get();
        final maestroRemoto = configDoc.data()?['codigo_maestro'] as String?;
        if (maestroRemoto != null && maestroRemoto.isNotEmpty) {
          codigoMaestroActual = maestroRemoto;
        }
      } catch (_) {} // usar fallback si falla

      bool esValido = cod == codigoMaestroActual;
      if (!esValido) {
        var q = await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .where(BioConfig.campoCodigoPropio, isEqualTo: cod)
            .get();
        if (q.docs.isNotEmpty) {
          // Bloquear si el dueño del código es un usuario común (rol "user")
          final rolDueno = q.docs.first.data()['rol'] ?? BioConfig.rolUser;
          if (rolDueno == BioConfig.rolUser) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Código no válido. Verifica con tu médico de confianza.',
                  ),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            setState(() => validando = false);
            return;
          }
          esValido = true;
        }
      }
      if (esValido) {
        final user = FirebaseAuth.instance.currentUser;
        // Resolver medico_id si el código que ingresó es de un PS (BIOMED-XXXX)
        String? medicoUid;
        if (cod != codigoMaestroActual && cod.startsWith('BIOMED-')) {
          final qPS = await FirebaseFirestore.instance
              .collection(BioConfig.colUsuarios)
              .where(BioConfig.campoCodigoPropio, isEqualTo: cod)
              .limit(1)
              .get();
          if (qPS.docs.isNotEmpty) medicoUid = qPS.docs.first.id;
        }
        await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user!.uid)
            .set({
          'uid': user.uid,
          'email': user.email,
          'nombre': user.displayName ?? 'Usuario Nuevo',
          BioConfig.campoTokens: 0,
          BioConfig.campoHistorico: 0,
          BioConfig.campoNivel: BioConfig.nivelBasico,
          BioConfig.campoReferidoPor: cod,
          BioConfig.campoCodigoPropio: _generarCodigoPropio(),
          'rol': BioConfig.rolUser,
          'can_invite': false,
          'medico_id': medicoUid,
          'fecha_registro': FieldValue.serverTimestamp(),
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("El código ingresado no existe.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => validando = false);
      }
    }
  }

  Future<String> _obtenerCodigoMaestroActual() async {
    String codigoMaestroActual = BioConfig.codigoMaestro;
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection(BioConfig.colConfiguracion)
          .doc('app')
          .get();
      final maestroRemoto = configDoc.data()?['codigo_maestro'] as String?;
      if (maestroRemoto != null && maestroRemoto.isNotEmpty) {
        codigoMaestroActual = maestroRemoto.trim().toUpperCase();
      }
    } catch (_) {}
    return codigoMaestroActual;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
      _seleccionarPsAleatorio() async {
    try {
      final qPs = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .where('rol', isEqualTo: BioConfig.rolPS)
          .get();
      final candidatos = qPs.docs.where((doc) {
        final codigo =
            doc.data()[BioConfig.campoCodigoPropio]?.toString().trim() ?? '';
        return codigo.isNotEmpty && codigo != '---';
      }).toList();
      if (candidatos.isEmpty) return null;

      final usuariosSnap = await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .get();
      final cargas = <String, int>{};
      for (final ps in candidatos) {
        cargas[ps.id] = 0;
      }
      for (final doc in usuariosSnap.docs) {
        final medicoId =
            doc.data()[BioConfig.campoMedicoId]?.toString().trim() ?? '';
        if (cargas.containsKey(medicoId)) {
          cargas[medicoId] = (cargas[medicoId] ?? 0) + 1;
        }
      }

      candidatos.sort((a, b) {
        final cargaA = cargas[a.id] ?? 0;
        final cargaB = cargas[b.id] ?? 0;
        if (cargaA != cargaB) return cargaA.compareTo(cargaB);
        final nombreA = (a.data()['nombre'] ?? a.data()['email'] ?? '')
            .toString()
            .toLowerCase();
        final nombreB = (b.data()['nombre'] ?? b.data()['email'] ?? '')
            .toString()
            .toLowerCase();
        return nombreA.compareTo(nombreB);
      });
      return candidatos.first;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String?>> _resolverReferenciaYMedico(
      String codigoIngresado, String codigoMaestroActual) async {
    final cod = codigoIngresado.trim().toUpperCase();

    if (cod.isEmpty || cod == codigoMaestroActual) {
      final psAleatorio = await _seleccionarPsAleatorio();
      final codigoPs =
          psAleatorio?.data()[BioConfig.campoCodigoPropio]?.toString().trim();
      return {
        'referido_por': (codigoPs != null && codigoPs.isNotEmpty)
            ? codigoPs
            : codigoMaestroActual,
        BioConfig.campoMedicoId: psAleatorio?.id,
      };
    }

    final qInvitador = await FirebaseFirestore.instance
        .collection(BioConfig.colUsuarios)
        .where(BioConfig.campoCodigoPropio, isEqualTo: cod)
        .limit(1)
        .get();

    if (qInvitador.docs.isEmpty) {
      return {'error': 'El código ingresado no existe.'};
    }

    final invitador = qInvitador.docs.first;
    final dataInvitador = invitador.data();
    final errorMacro =
        await MacroSegmentoConfig.validarUsoCodigoReferido(cod, dataInvitador);
    if (errorMacro != null) {
      return {'error': errorMacro};
    }
    final rolInvitador = (dataInvitador['rol'] ?? BioConfig.rolUser).toString();

    String? medicoUid;
    if (rolInvitador == BioConfig.rolPS || rolInvitador == BioConfig.rolAdmin) {
      medicoUid = invitador.id;
    } else {
      medicoUid = dataInvitador[BioConfig.campoMedicoId]?.toString();
      if (medicoUid == null || medicoUid.isEmpty) {
        final psAleatorio = await _seleccionarPsAleatorio();
        medicoUid = psAleatorio?.id;
      }
    }

    return {
      'referido_por': cod,
      BioConfig.campoMedicoId: medicoUid,
    };
  }

  Future<void> _registrarConArbolReferidos() async {
    final cod = refController.text.trim().toUpperCase();
    setState(() => validando = true);
    try {
      final codigoMaestroActual = await _obtenerCodigoMaestroActual();
      final vinculo =
          await _resolverReferenciaYMedico(cod, codigoMaestroActual);

      if (vinculo['error'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vinculo['error']!)),
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final referidoPorFinal =
          (vinculo['referido_por'] ?? codigoMaestroActual).trim();
      final medicoUid = vinculo['medico_id']?.trim();

      await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user!.uid)
          .set({
        'uid': user.uid,
        'email': user.email,
        'nombre': user.displayName ?? 'Usuario Nuevo',
        BioConfig.campoTokens: 0,
        BioConfig.campoHistorico: 0,
        BioConfig.campoNivel: BioConfig.nivelBasico,
        BioConfig.campoReferidoPor: referidoPorFinal,
        BioConfig.campoCodigoPropio: _generarCodigoPropio(),
        'rol': BioConfig.rolUser,
        'can_invite': false,
        BioConfig.campoSuspendido: false,
        BioConfig.campoEstadoCuenta: 'activa',
        BioConfig.campoMedicoId:
            (medicoUid != null && medicoUid.isNotEmpty) ? medicoUid : null,
        'fecha_registro': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => validando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: BioConfig.colorPrimario),
            const SizedBox(height: 20),
            const Text("ACCESO POR INVITACIÓN",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
                "Para acceder necesitas un código de invitación de tu Profesional de Salud o del equipo BioFreq.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text("¿No tienes código? Escríbenos a biofreq@gmail.com",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 24),
            // Botón de contacto por si no tienen código
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse(
                    'mailto:biofreq@gmail.com?subject=Solicitud%20de%20acceso%20BioFreq');
                try {
                  await launchUrl(uri);
                } catch (_) {}
              },
              icon: const Icon(Icons.mail_outline,
                  size: 16, color: Colors.white38),
              label: const Text('Contactar a BioFreq para obtener acceso',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: refController,
              style: const TextStyle(color: Colors.white),
              maxLength: 12,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                UpperCaseTextFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: "Código (Ej: BIO-XXXXX)",
                border: OutlineInputBorder(),
                counterStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: validando ? null : _registrarConArbolReferidos,
                child: const Text(
                  'Continuar sin codigo',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: BioConfig.colorPrimario),
                onPressed: validando ? null : _registrarConArbolReferidos,
                child: validando
                    ? const CircularProgressIndicator()
                    : const Text("INGRESAR"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA: Login
// FIX 1: Logo restaurado desde assets
// FIX 2: Login con email/contraseña agregado
// FIX 5/6: Google Sign In usa google_sign_in (nativo) en vez de signInWithProvider
// ─────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool cargando = false;
  bool mostrarEmail = false;
  bool esRegistro = false;
  bool _aceptoEula = false; // ← NUEVO
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool verPass = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // ── Google Login ───────────────────────────────────────────────────────────
  Future<void> _googleLogin() async {
    if (!_aceptoEula) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Debes aceptar el EULA para continuar.")));
      return;
    }
    setState(() => cargando = true);
    try {
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
      if (gUser == null) {
        if (mounted) setState(() => cargando = false);
        return;
      }
      final GoogleSignInAuthentication gAuth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
    } catch (e) {
      debugPrint("Error Google: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  // ── Email Login ────────────────────────────────────────────────────────────
  Future<void> _emailLogin() async {
    if (!_aceptoEula) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Debes aceptar el EULA para continuar.")));
      return;
    }
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Completa todos los campos.")));
      return;
    }
    setState(() => cargando = true);
    try {
      if (esRegistro) {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pass);
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Error de autenticación.";
      if (e.code == 'user-not-found')
        msg = "No existe una cuenta con ese correo.";
      if (e.code == 'wrong-password') msg = "Contraseña incorrecta.";
      if (e.code == 'invalid-credential')
        msg = "Correo o contraseña incorrectos.";
      if (e.code == 'invalid-email')
        msg = "El formato del correo no es válido.";
      if (e.code == 'user-disabled') msg = "Esta cuenta ha sido desactivada.";
      if (e.code == 'email-already-in-use')
        msg = "Ese correo ya está registrado.";
      if (e.code == 'weak-password')
        msg = "La contraseña debe tener al menos 6 caracteres.";
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  // ── Recuperar contraseña ───────────────────────────────────────────────────
  Future<void> _recuperarPassword() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Escribe tu correo para recuperar la contraseña.")));
      return;
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Correo de recuperación enviado ✅")));
    }
  }

  // ── Modal EULA ─────────────────────────────────────────────────────────────
  void _mostrarEula() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.shield_outlined, color: BioConfig.colorPrimario, size: 22),
          const SizedBox(width: 10),
          const Flexible(
              child: Text("EULA y Aviso de Responsabilidad",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold))),
        ]),
        content: const SingleChildScrollView(
          child: Text(BioConfig.eulaTexto,
              style:
                  TextStyle(color: Colors.white70, fontSize: 13, height: 1.6)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BioConfig.colorPrimario,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              setState(() => _aceptoEula = true); // marcar al leer
              Navigator.pop(context);
            },
            child: const Text("Acepto",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioConfig.colorFondo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ════════════════════════════════════════════════════
              // ⚠️  LOGO — leer desde assets/logo.png
              //     Si cambia este widget, NO usar FlutterLogo ni
              //     Icons.waves como reemplazo permanente.
              //     Asegurarse de que pubspec.yaml declare:
              //       - assets/logo.png
              // ════════════════════════════════════════════════════
              Image.asset(
                'assets/logo.png',
                height: 110,
                errorBuilder: (_, __, ___) => Icon(Icons.waves,
                    size: 100, color: BioConfig.colorPrimario),
              ),
              const SizedBox(height: 12),
              // ════════════════════════════════════════════════════
              // ⚠️  VERSIÓN + BOTÓN ACTUALIZAR — SIEMPRE VISIBLE
              //     Todo el bloque es tappable. No separar en dos
              //     widgets distintos ni envolver en condiciones.
              //     El botón abre el APK en el navegador externo.
              // ════════════════════════════════════════════════════
              GestureDetector(
                onTap: () async {
                  final apkUrl = await AppUpdateConfig.load();
                  final uri = Uri.parse(apkUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Column(children: [
                  Text('BIOFREQ v${BioConfig.versionDisplay}',
                      style: TextStyle(
                          color: BioConfig.colorPrimario,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.system_update_alt,
                        size: 11, color: Colors.white38),
                    SizedBox(width: 4),
                    Text('Actualizar app',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 0.5)),
                  ]),
                ]),
              ),
              const SizedBox(height: 6),
              Text(BioConfig.taglineApp,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BioConfig.colorPrimario,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 40),

              if (cargando)
                CircularProgressIndicator(color: BioConfig.colorPrimario)
              else ...[
                // ── Botón Google ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _aceptoEula ? Colors.white : Colors.grey[700],
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.g_mobiledata, size: 35),
                    label: const Text("INGRESAR CON GOOGLE",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _aceptoEula
                        ? _googleLogin
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Primero acepta el EULA para continuar.")));
                          },
                  ),
                ),
                const SizedBox(height: 16),

                // ── Divisor ────────────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(mostrarEmail ? "o usa Google" : "o usa correo",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  const Expanded(child: Divider(color: Colors.white24)),
                ]),
                const SizedBox(height: 16),

                // ── Botón toggle email ─────────────────────────────────────
                if (!mostrarEmail)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: BioConfig.colorPrimario,
                          side: BorderSide(color: BioConfig.colorPrimario),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.email_outlined),
                      label: const Text("INGRESAR CON CORREO",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => mostrarEmail = true),
                    ),
                  ),

                // ── Formulario email ───────────────────────────────────────
                if (mostrarEmail) ...[
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Correo electrónico",
                      prefixIcon:
                          Icon(Icons.email_outlined, color: Colors.grey),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: !verPass,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 64,
                    inputFormatters: [LengthLimitingTextInputFormatter(64)],
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: Colors.grey),
                      border: const OutlineInputBorder(),
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                            verPass ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey),
                        onPressed: () => setState(() => verPass = !verPass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => esRegistro = !esRegistro),
                        child: Text(
                            esRegistro
                                ? "¿Ya tienes cuenta? Inicia sesión"
                                : "¿No tienes cuenta? Regístrate",
                            style: const TextStyle(
                                color: Colors.cyan, fontSize: 12),
                            textAlign: TextAlign.center),
                      ),
                      if (!esRegistro)
                        TextButton(
                          onPressed: _recuperarPassword,
                          child: const Text("¿Olvidaste tu contraseña?",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _aceptoEula
                              ? BioConfig.colorPrimario
                              : Colors.grey[700],
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: _aceptoEula
                          ? _emailLogin
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Primero acepta el EULA para continuar.")));
                            },
                      child: Text(esRegistro ? "REGISTRARME" : "INICIAR SESIÓN",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],

                // ── EULA Checkbox ──────────────────────────────────────────
                const SizedBox(height: 20),
                Theme(
                  data: Theme.of(context).copyWith(
                    checkboxTheme: CheckboxThemeData(
                      fillColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected)
                              ? BioConfig.colorPrimario
                              : Colors.transparent),
                      checkColor: WidgetStateProperty.all(Colors.black),
                      side: const BorderSide(color: Colors.white38, width: 1.5),
                    ),
                  ),
                  child: CheckboxListTile(
                    value: _aceptoEula,
                    onChanged: (val) =>
                        setState(() => _aceptoEula = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: GestureDetector(
                      onTap: _mostrarEula,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12, height: 1.4),
                          children: [
                            const TextSpan(text: "He leído y acepto el "),
                            TextSpan(
                              text: "EULA y Aviso de Responsabilidad",
                              style: TextStyle(
                                  color: BioConfig.colorPrimario,
                                  decoration: TextDecoration.underline,
                                  decorationColor: BioConfig.colorPrimario),
                            ),
                            const TextSpan(
                                text:
                                    ". BioFreq es una terapia bioacústica complementaria."),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DialogVideoTutorial extends StatefulWidget {
  final String sonidoId;
  final String videoUrl; // URL directa del MP4
  final String nombreSonido;
  final int costoTokens;

  const DialogVideoTutorial({
    super.key,
    required this.sonidoId,
    required this.videoUrl,
    required this.nombreSonido,
    required this.costoTokens,
  });

  @override
  State<DialogVideoTutorial> createState() => _DialogVideoTutorialState();
}

class _DialogVideoTutorialState extends State<DialogVideoTutorial> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoTerminado = false;
  bool _desbloqueando = false;
  bool _cargando = true;
  bool _aceptoResponsabilidad = false;
  String? _errorVideo;

  @override
  void initState() {
    super.initState();
    _inicializarPlayer();
  }

  Future<void> _inicializarPlayer() async {
    // Verificar saldo antes de cargar el video — evita ver video sin poder pagar
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.costoTokens > 0) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .get();
        final saldo = BioConfig.toInt(doc.data()?[BioConfig.campoTokens]);
        if (saldo < widget.costoTokens && mounted) {
          setState(() {
            _errorVideo =
                'Saldo insuficiente: necesitas ${widget.costoTokens} tokens '
                '(tienes $saldo). Compra tokens desde Mi Cuenta.';
            _cargando = false;
          });
          return;
        }
      } catch (_) {
        /* Si falla la verificación, continuamos — el cobro la valida */
      }
    }
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: false, // Sin pantalla completa
        allowMuting: true,
        showControls: true,
        showOptions: false, // Sin menú de opciones (3 puntos)
        allowPlaybackSpeedChanging: false, // Sin cambio de velocidad
        // Desactivamos seek y skip para que no se salten el video
        additionalOptions: (_) => [],
        materialProgressColors: ChewieProgressColors(
          playedColor: BioConfig.colorPrimario,
          handleColor: BioConfig.colorPrimario,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );

      // Detectar fin del video
      _videoController!.addListener(() {
        if (!mounted) return;
        final pos = _videoController!.value.position;
        final dur = _videoController!.value.duration;
        if (dur.inSeconds > 0 && pos >= dur - const Duration(seconds: 1)) {
          if (!_videoTerminado) setState(() => _videoTerminado = true);
        }
      });

      if (mounted) {
        setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorVideo = "Error cargando video: $e";
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

  Future<void> _confirmarYDesbloquear() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _desbloqueando = true);
    try {
      // m2: Verificar saldo ANTES de cobrar (puede haber cambiado desde que abrió)
      if (widget.costoTokens > 0) {
        final userDoc = await FirebaseFirestore.instance
            .collection(BioConfig.colUsuarios)
            .doc(user.uid)
            .get();
        final saldoActual =
            BioConfig.toInt(userDoc.data()?[BioConfig.campoTokens]);
        if (saldoActual < widget.costoTokens) {
          if (mounted) {
            setState(() => _desbloqueando = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "Saldo insuficiente. Necesitas ${widget.costoTokens} tokens."),
              backgroundColor: Colors.redAccent,
            ));
          }
          return;
        }
      }

      var sonidoDoc = await FirebaseFirestore.instance
          .collection(BioConfig.colSonidos)
          .doc(widget.sonidoId)
          .get();
      int versionActual = sonidoDoc.data()?['version_video'] ?? 1;

      var accesoRef = FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .collection(BioConfig.colAccesosSonidos)
          .doc(widget.sonidoId);

      var accesoDoc = await accesoRef.get();

      // FieldValue.increment(1) es atómico — no hay race conditions
      await accesoRef.set({
        'sonido_id': widget.sonidoId,
        'version_vista': versionActual,
        'ultimo_uso': FieldValue.serverTimestamp(),
        'ciclos_completados': FieldValue.increment(1),
      }, SetOptions(merge: true));
      // fecha_primer_uso solo la primera vez
      if (!accesoDoc.exists) {
        await accesoRef.set({
          'fecha_primer_uso': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await FirebaseFirestore.instance
          .collection(BioConfig.colUsuarios)
          .doc(user.uid)
          .set({
        BioConfig.campoTokens: FieldValue.increment(-widget.costoTokens)
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _desbloqueando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: SafeArea(
            child: Column(
              children: [
                // Barra superior
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.nombreSonido,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                ),
                // Instrucción
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  color: BioConfig.colorPrimario.withValues(alpha: 0.12),
                  child: Text(
                    _videoTerminado
                        ? "✅ Video completado. Ya puedes iniciar la frecuencia."
                        : "👁  Mira el tutorial completo para desbloquear esta frecuencia.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _videoTerminado
                            ? Colors.greenAccent
                            : Colors.white70,
                        fontSize: 12),
                  ),
                ),
                // Reproductor — FutureBuilder ya resuelto en initState
                Expanded(
                  child: _cargando
                      ? Center(
                          child: CircularProgressIndicator(
                              color: BioConfig.colorPrimario))
                      : _errorVideo != null
                          ? Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(_errorVideo!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.redAccent))))
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
                                            if (_videoController!
                                                .value.isPlaying) {
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
                                          allowScrubbing:
                                              false, // No permite adelantar
                                          colors: VideoProgressColors(
                                            playedColor:
                                                BioConfig.colorPrimario,
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
                                                color: Colors.white70,
                                                fontSize: 11),
                                          );
                                        },
                                      ),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                ),
                // ── Panel de confirmación / desbloqueo ────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _videoTerminado
                      ? _desbloqueando
                          // Procesando...
                          ? Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: BioConfig.colorPrimario,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.black)),
                              ),
                            )
                          // Video terminado — mostrar checkbox + botones
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Checkbox de responsabilidad
                                GestureDetector(
                                  onTap: () => setState(() =>
                                      _aceptoResponsabilidad =
                                          !_aceptoResponsabilidad),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _aceptoResponsabilidad
                                          ? BioConfig.colorPrimario
                                              .withValues(alpha: 0.12)
                                          : Colors.grey[900],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _aceptoResponsabilidad
                                            ? BioConfig.colorPrimario
                                            : Colors.grey[700]!,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _aceptoResponsabilidad
                                              ? Icons.check_box_rounded
                                              : Icons
                                                  .check_box_outline_blank_rounded,
                                          color: _aceptoResponsabilidad
                                              ? BioConfig.colorPrimario
                                              : Colors.grey[600],
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Text(
                                            "Entendí las instrucciones y me responsabilizo por el uso que le voy a dar a este sonido.",
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Botones: Volver a ver / Continuar
                                Row(children: [
                                  // Botón volver a ver
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(
                                            color: Colors.white24),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      icon: const Icon(Icons.replay, size: 18),
                                      label: const Text("Ver de nuevo",
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        setState(() {
                                          _videoTerminado = false;
                                          _aceptoResponsabilidad = false;
                                        });
                                        _videoController?.seekTo(Duration.zero);
                                        _videoController?.play();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Botón continuar
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _aceptoResponsabilidad
                                            ? BioConfig.colorPrimario
                                            : Colors.grey[800],
                                        foregroundColor: _aceptoResponsabilidad
                                            ? Colors.black
                                            : Colors.grey[600],
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      icon: Icon(
                                        _aceptoResponsabilidad
                                            ? Icons.play_arrow_rounded
                                            : Icons.lock_outline,
                                        size: 20,
                                      ),
                                      label: Text(
                                        _aceptoResponsabilidad
                                            ? "Continuar  (-${widget.costoTokens} tokens)"
                                            : "Acepta primero",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: _aceptoResponsabilidad
                                          ? _confirmarYDesbloquear
                                          : null,
                                    ),
                                  ),
                                ]),
                              ],
                            )
                      // Video no terminado — candado bloqueado
                      : Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock,
                                  size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text("Ve el video completo para desbloquear",
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANTALLA PRINCIPAL: Lista de Sonidos
// ─────────────────────────────────────────────
