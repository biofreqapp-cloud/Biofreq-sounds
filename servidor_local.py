"""
╔══════════════════════════════════════════════════════════════════╗
║   BioFreq — Servidor local para el Panel Admin                  ║
║   Expone el Alembique como HTTP en localhost:5000               ║
╠══════════════════════════════════════════════════════════════════╣
║   Uso:                                                           ║
║     python servidor_local.py                                     ║
║                                                                  ║
║   Requiere que Alembique.py esté en la misma carpeta            ║
╚══════════════════════════════════════════════════════════════════╝
"""

import os, sys, json, requests as http_requests
from flask import Flask, request, jsonify
from flask_cors import CORS

# ── Google Auth para FCM V1 ───────────────────────────────────────────────────
try:
    from google.oauth2 import service_account
    import google.auth.transport.requests as google_auth_requests
    _google_auth_ok = True
except ImportError:
    _google_auth_ok = False
    print("⚠️  google-auth no instalado — notificaciones FCM desactivadas")
    print("   Instalar con: pip install google-auth")

# ── Configurar variables de entorno ANTES de importar Alembique ──────────────
# El token de GitHub lo toma Alembique desde os.environ
os.environ.setdefault("GITHUB_TOKEN",      "")  # ← poner en variable de entorno de Render
os.environ.setdefault("GITHUB_REPO_OWNER", "biofreqapp-cloud")
os.environ.setdefault("GITHUB_REPO_NAME",  "Biofreq-sounds")
os.environ.setdefault("GITHUB_BRANCH",     "main")
os.environ.setdefault("MODO_INDUSTRIAL",   "true")   # Sin filtro MedlinePlus en el panel admin
os.environ.setdefault("BYPASS_AUTH",       "true")   # Saltar verificación Firebase Auth en local
os.environ.setdefault("AUTOSUBIR_GITHUB",  "true")   # Subir a GitHub sin preguntar

# ── Importar las funciones del Alembique ─────────────────────────────────────
try:
    import Alembique as _alembique_mod
    from Alembique import generarSQC, mezclarAlkam
    print("✅ Alembique importado correctamente")
except ImportError as e:
    print(f"❌ No se pudo importar Alembique.py: {e}")
    print("   Asegurate de que Alembique.py esté en la misma carpeta que este archivo.")
    sys.exit(1)

# ── Bypass Auth para modo local ───────────────────────────────────────────────
# En producción (Cloud Functions) el Alembique verifica el idToken con Firebase.
# En local reemplazamos _verificar_admin para que devuelva un UID fijo sin llamar
# a Firebase Admin SDK (que requeriría credenciales de servicio).
if os.environ.get("BYPASS_AUTH", "false").lower() == "true":
    def _bypass_verificar_admin(id_token: str) -> str:
        return "admin_local"
    _alembique_mod._verificar_admin = _bypass_verificar_admin
    print("⚠️  Auth bypass activo — solo usar en local")

# ── Bypass prompt GitHub para modo servidor ───────────────────────────────────
# Cuando AUTOSUBIR_GITHUB=true, parcheamos _guardar_y_subir para que suba
# automáticamente sin pedir confirmación por stdin.
if os.environ.get("AUTOSUBIR_GITHUB", "false").lower() == "true":
    def _auto_guardar_y_subir(mp3_bytes, nombre_archivo):
        """Versión sin prompt: guarda local y sube a GitHub automáticamente."""
        ruta_local = _alembique_mod._guardar_local(mp3_bytes, nombre_archivo)
        gh_token = os.environ.get("GITHUB_TOKEN", "")
        if gh_token:
            try:
                url_github = _alembique_mod._subir_github_real(mp3_bytes, nombre_archivo)
                print(f"[GitHub] ✅ Subido automáticamente: {url_github}")
                return url_github
            except Exception as e:
                print(f"[GitHub] ⚠️  Error subiendo: {e} — usando ruta local")
                return ruta_local.as_uri()
        else:
            print("[GitHub] Sin token — usando ruta local")
            return ruta_local.as_uri()
    _alembique_mod._subir_github = _auto_guardar_y_subir
    print("✅ Auto-subida a GitHub activa")

# ── Flask app ────────────────────────────────────────────────────────────────
app = Flask(__name__)
CORS(app)  # Permite llamadas desde localhost:8080 (el panel admin)

# ── Configuración FCM V1 ──────────────────────────────────────────────────────
# ⚠️  PROJECT_ID: ID del proyecto en Firebase (no el nombre, el ID)
#     serviceAccount.json debe estar en la misma carpeta que este archivo.
#     NUNCA compartir ni subir a GitHub.
FCM_PROJECT_ID  = "biofreq-app"
FCM_KEY_FILE    = os.path.join(os.path.dirname(__file__), "serviceAccount.json")
FCM_SCOPES      = ["https://www.googleapis.com/auth/firebase.messaging"]
FCM_URL         = f"https://fcm.googleapis.com/v1/projects/{FCM_PROJECT_ID}/messages:send"


def _get_fcm_token() -> str:
    """
    Genera un OAuth2 token de corta duración usando el service account.
    FCM V1 requiere este token en cada llamada — no usa Server Key.
    """
    if not _google_auth_ok:
        raise RuntimeError("google-auth no está instalado")
    if not os.path.exists(FCM_KEY_FILE):
        raise FileNotFoundError(
            f"serviceAccount.json no encontrado en {FCM_KEY_FILE}\n"
            "Descárgalo desde Firebase Console → ⚙️ → Cuentas de servicio → "
            "Generar nueva clave privada"
        )
    creds = service_account.Credentials.from_service_account_file(
        FCM_KEY_FILE, scopes=FCM_SCOPES)
    creds.refresh(google_auth_requests.Request())
    return creds.token


def _enviar_fcm(token_dispositivo: str, titulo: str, cuerpo: str,
                datos: dict = None) -> dict:
    """
    Envía una notificación push a UN dispositivo específico via FCM V1.
    token_dispositivo: FCM registration token guardado en Usuarios/{uid}/fcm_token
    datos: payload extra (opcional) — pares clave-valor string
    """
    fcm_token = _get_fcm_token()
    mensaje = {
        "message": {
            "token": token_dispositivo,
            "notification": {
                "title": titulo,
                "body":  cuerpo,
            },
        }
    }
    if datos:
        # FCM data payload: todos los valores deben ser strings
        mensaje["message"]["data"] = {k: str(v) for k, v in datos.items()}

    resp = http_requests.post(
        FCM_URL,
        headers={
            "Authorization": f"Bearer {fcm_token}",
            "Content-Type":  "application/json",
        },
        json=mensaje,
        timeout=10,
    )
    return resp.json(), resp.status_code


class FakeRequest:
    """
    Imita firebase_functions.https_fn.Request para llamadas locales.
    Expone todos los atributos que generarSQC / mezclarAlkam puedan usar.
    """
    def __init__(self, flask_req):
        self.method  = flask_req.method
        self.headers = dict(flask_req.headers)
        self.args    = flask_req.args.to_dict()
        self.form    = flask_req.form.to_dict()
        self.files   = flask_req.files
        self.url     = flask_req.url
        self.path    = flask_req.path
        self._data   = flask_req.get_json(force=True, silent=True) or {}

    def get_json(self, silent=False, force=False, **kwargs):
        return self._data

    @property
    def data(self):
        import json
        return json.dumps(self._data).encode('utf-8')

    def json(self):
        return self._data

def _manejar_resultado(resultado):
    """
    El Alembique puede devolver:
      - Un objeto Response de Flask/Firebase  → retornar directo
      - Una tupla (Response, status_code)     → retornar directo con código
      - Un dict                               → envolver en jsonify
      - Una tupla (dict, status_code)         → envolver en jsonify con código
    """
    from flask import Response as FlaskResponse
    # Log para diagnóstico
    print(f"[DEBUG] Tipo resultado: {type(resultado)}")
    if isinstance(resultado, tuple):
        body, code = resultado
        print(f"[DEBUG] Tupla → code={code}, body={body}")
        if isinstance(body, FlaskResponse):
            body.status_code = code
            return body
        return jsonify(body), code
    if isinstance(resultado, FlaskResponse):
        print(f"[DEBUG] Response → status={resultado.status_code}, data={resultado.get_data(as_text=True)[:200]}")
        return resultado
    print(f"[DEBUG] Dict → {str(resultado)[:200]}")
    return jsonify(resultado)


@app.route("/generarSQC", methods=["POST", "OPTIONS"])
def endpoint_sqc():
    if request.method == "OPTIONS":
        return _cors_preflight()
    try:
        resultado = generarSQC(FakeRequest(request))
        return _manejar_resultado(resultado)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/mezclarAlkam", methods=["POST", "OPTIONS"])
def endpoint_alkam():
    if request.method == "OPTIONS":
        return _cors_preflight()
    try:
        resultado = mezclarAlkam(FakeRequest(request))
        return _manejar_resultado(resultado)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── Endpoints de notificaciones ──────────────────────────────────────────────


def _get_todos_fcm_tokens() -> list:
    # Lee todos los fcm_token de Usuarios en Firestore.
    # Excluye admin y tester.
    import firebase_admin
    from firebase_admin import credentials, firestore as fs_admin
    if not firebase_admin._apps:
        cred = credentials.Certificate(FCM_KEY_FILE)
        firebase_admin.initialize_app(cred)
    db = fs_admin.client()
    tokens = []
    for doc in db.collection("Usuarios").stream():
        data  = doc.to_dict()
        rol   = data.get("rol", "user")
        token = data.get("fcm_token", "")
        if token and rol not in ("admin", "tester"):
            tokens.append(token)
    return tokens

@app.route("/notificarNuevoSonido", methods=["POST", "OPTIONS"])
def endpoint_nuevo_sonido():
    # Notifica a todos los usuarios (menos admin/tester) sobre un nuevo sonido.
    # Llamado por alkam_admin.html al publicar en Firestore.
    if request.method == "OPTIONS":
        return _cors_preflight()
    try:
        data   = request.get_json(force=True, silent=True) or {}
        titulo = data.get("titulo", "Nueva frecuencia disponible")
        cuerpo = data.get("cuerpo", "")
        nombre = data.get("sonido_nombre", "")
        tokens = _get_todos_fcm_tokens()
        if not tokens:
            print("[FCM] Sin tokens registrados")
            return jsonify({"advertencia": "Sin tokens", "enviados": 0}), 200
        resultados = []
        for tok in tokens:
            try:
                res, st = _enviar_fcm(tok, titulo, cuerpo,
                                      {"tipo": "nuevo_sonido", "nombre": nombre})
                resultados.append({"status": st})
            except Exception as ex:
                resultados.append({"error": str(ex)})
        print(f"[FCM] Nuevo sonido '{nombre}' → {len(tokens)} usuarios")
        return jsonify({"enviados": len(tokens), "resultados": resultados}), 200
    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/notificar", methods=["POST", "OPTIONS"])
def endpoint_notificar():
    """
    Envía una notificación push a un dispositivo específico.
    Body: {
      "token":  "<fcm_registration_token>",  ← guardado en Firestore Usuarios/{uid}/fcm_token
      "titulo": "...",
      "cuerpo": "...",
      "datos":  {"clave": "valor"}            ← opcional
    }
    """
    if request.method == "OPTIONS":
        return _cors_preflight()
    try:
        data   = request.get_json(force=True, silent=True) or {}
        token  = data.get("token", "").strip()
        titulo = data.get("titulo", "BioFreq")
        cuerpo = data.get("cuerpo", "")
        datos  = data.get("datos", {})

        if not token:
            return jsonify({"error": "Falta el campo 'token'"}), 400

        resultado, status = _enviar_fcm(token, titulo, cuerpo, datos)
        print(f"[FCM] → {titulo} | status={status} | resp={resultado}")
        return jsonify(resultado), status

    except FileNotFoundError as e:
        print(f"[FCM] ❌ serviceAccount.json no encontrado: {e}")
        return jsonify({"error": str(e)}), 503
    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/notificarGrupo", methods=["POST", "OPTIONS"])
def endpoint_notificar_grupo():
    """
    Envía la misma notificación a múltiples tokens a la vez.
    Body: {
      "tokens": ["tok1", "tok2", ...],
      "titulo": "...",
      "cuerpo": "...",
      "datos":  {}
    }
    Útil para: notificar al Admin (varios dispositivos), broadcast de versión nueva, etc.
    """
    if request.method == "OPTIONS":
        return _cors_preflight()
    try:
        data   = request.get_json(force=True, silent=True) or {}
        tokens = data.get("tokens", [])
        titulo = data.get("titulo", "BioFreq")
        cuerpo = data.get("cuerpo", "")
        datos  = data.get("datos", {})

        if not tokens:
            return jsonify({"error": "Falta el campo 'tokens'"}), 400

        resultados = []
        for tok in tokens:
            try:
                res, st = _enviar_fcm(tok, titulo, cuerpo, datos)
                resultados.append({"token": tok[:20]+"…", "status": st, "resp": res})
            except Exception as ex:
                resultados.append({"token": tok[:20]+"…", "error": str(ex)})

        print(f"[FCM] Grupo → {titulo} | {len(tokens)} tokens")
        return jsonify({"enviados": len(tokens), "resultados": resultados}), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/crearPreferenciaMp", methods=["POST", "OPTIONS"])
def endpoint_crear_preferencia_mp():
    """
    Crea una preferencia de pago en MercadoPago server-side.
    La app Flutter llama a este endpoint en lugar de llamar a MP directamente.
    Body: {
      "titulo":   "Pack 500 Tokens BioFreq",
      "cantidad": 500,          ← tokens
      "precio":   50000,        ← COP (cantidad * 100)
      "uid":      "firebase_uid"
    }
    Retorna: { "init_point": "https://www.mercadopago.com.co/checkout/..." }
    """
    if request.method == "OPTIONS":
        return _cors_preflight()
    try:
        data    = request.get_json(force=True, silent=True) or {}
        titulo  = data.get("titulo",   "Tokens BioFreq")
        precio  = float(data.get("precio", 0))
        uid     = data.get("uid", "")

        if precio <= 0:
            return jsonify({"error": "precio inválido"}), 400

        # ⚠️  Usar TEST_ACCESS_TOKEN para pruebas, APP_USR para producción
        # Cambia este valor según el ambiente
        ACCESS_TOKEN = os.environ.get(
            "MP_ACCESS_TOKEN",
            "APP_USR-284b1633-1466-4e58-944d-57018311910a"  # producción
        )

        resp = http_requests.post(
            "https://api.mercadopago.com/checkout/preferences",
            headers={
                "Authorization": f"Bearer {ACCESS_TOKEN}",
                "Content-Type":  "application/json",
                "X-Idempotency-Key": uid + str(int(precio)),
            },
            json={
                "items": [{
                    "title":      titulo,
                    "quantity":   1,
                    "unit_price": precio,
                    "currency_id": "COP",
                }],
                "back_urls": {
                    "success": "biofreq://pago-exitoso",
                    "failure": "biofreq://pago-fallido",
                    "pending": "biofreq://pago-pendiente",
                },
                "auto_return": "approved",
                "statement_descriptor": "BioFreq",
                "external_reference": uid,
            },
            timeout=15,
        )

        print(f"[MP] {resp.status_code}: {resp.text[:300]}")

        if resp.status_code not in (200, 201):
            return jsonify({"error": resp.text}), resp.status_code

        mp_data = resp.json()
        return jsonify({
            "init_point":    mp_data.get("init_point"),
            "sandbox_init_point": mp_data.get("sandbox_init_point"),
            "id": mp_data.get("id"),
        }), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ── Webhook de MercadoPago ────────────────────────────────────────────────────
# MP llama a este endpoint cuando un pago cambia de estado.
# Valida la firma x-signature (HMAC SHA256) antes de procesar.
# Render.com lo expone con HTTPS gratis.
MP_WEBHOOK_SECRET = os.environ.get("MP_WEBHOOK_SECRET", "")  # clave secreta de Tus Integraciones

@app.route("/webhook/mp", methods=["POST"])
def endpoint_webhook_mp():
    try:
        # ── Validar firma x-signature ────────────────────────────────────────
        x_signature  = request.headers.get("x-signature", "")
        x_request_id = request.headers.get("x-request-id", "")
        data_id      = request.args.get("data.id", "")

        if MP_WEBHOOK_SECRET and x_signature:
            # Extraer ts y v1 del header
            ts = ""; v1 = ""
            for part in x_signature.split(","):
                kv = part.strip().split("=", 1)
                if len(kv) == 2:
                    if kv[0].strip() == "ts": ts = kv[1].strip()
                    elif kv[0].strip() == "v1": v1 = kv[1].strip()

            # Construir manifest y calcular HMAC
            manifest = f"id:{data_id};request-id:{x_request_id};ts:{ts};"
            import hmac as _hmac, hashlib as _hashlib
            calculado = _hmac.new(
                MP_WEBHOOK_SECRET.encode(),
                manifest.encode(),
                _hashlib.sha256
            ).hexdigest()

            if calculado != v1:
                print(f"[Webhook] ⚠️  Firma inválida — ignorando")
                return jsonify({"error": "firma inválida"}), 401

        # ── Procesar el evento ───────────────────────────────────────────────
        body = request.get_json(force=True, silent=True) or {}
        tipo = body.get("type", "")
        accion = body.get("action", "")
        pago_id = body.get("data", {}).get("id", "")

        print(f"[Webhook MP] tipo={tipo} accion={accion} id={pago_id}")

        if tipo == "payment" and pago_id:
            _procesar_pago_mp(pago_id)

        # MP requiere 200 en menos de 22 seg
        return jsonify({"status": "ok"}), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        # Devolver 200 igual para que MP no reintente indefinidamente
        return jsonify({"status": "error", "msg": str(e)}), 200


def _procesar_pago_mp(pago_id: str):
    """
    Consulta el pago en MP y acredita tokens en Firestore si está aprobado.
    El uid del usuario viene en external_reference que pusimos al crear la preferencia.
    """
    ACCESS_TOKEN = os.environ.get(
        "MP_ACCESS_TOKEN",
        "APP_USR-284b1633-1466-4e58-944d-57018311910a"
    )
    try:
        resp = http_requests.get(
            f"https://api.mercadopago.com/v1/payments/{pago_id}",
            headers={"Authorization": f"Bearer {ACCESS_TOKEN}"},
            timeout=10,
        )
        if resp.status_code != 200:
            print(f"[Webhook] Error consultando pago {pago_id}: {resp.text}")
            return

        pago = resp.json()
        status   = pago.get("status", "")
        uid      = pago.get("external_reference", "")
        monto    = pago.get("transaction_amount", 0)
        moneda   = pago.get("currency_id", "COP")

        print(f"[Webhook] Pago {pago_id} → status={status} uid={uid} monto={monto} {moneda}")

        if status != "approved" or not uid:
            return  # Solo procesar pagos aprobados

        # Calcular tokens (1 token = $100 COP)
        tokens = int(monto / 100) if moneda == "COP" else int(monto)

        # Acreditar en Firestore
        import firebase_admin
        from firebase_admin import credentials as fb_creds, firestore as fb_fs
        if not firebase_admin._apps:
            cred = fb_creds.Certificate(FCM_KEY_FILE)
            firebase_admin.initialize_app(cred)
        db = fb_fs.client()

        from google.cloud.firestore_v1 import transforms
        db.collection("Usuarios").document(uid).update({
            "tokens_disponibles":       transforms.Increment(tokens),
            "total_acumulado_historico": transforms.Increment(tokens),
        })
        print(f"[Webhook] ✅ {tokens} tokens acreditados a uid={uid}")

        # Notificar al usuario por FCM
        try:
            doc = db.collection("Usuarios").document(uid).get()
            fcm_token = doc.to_dict().get("fcm_token", "")
            if fcm_token:
                _enviar_fcm(
                    fcm_token,
                    "✅ Pago aprobado",
                    f"Se acreditaron {tokens} tokens a tu cuenta BioFreq.",
                    {"tipo": "compra_ok", "tokens": str(tokens)},
                )
        except Exception as e:
            print(f"[Webhook] FCM error: {e}")

    except Exception as e:
        print(f"[Webhook] Error procesando pago {pago_id}: {e}")
        import traceback; traceback.print_exc()


@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "ok", "mensaje": "Servidor Alembique corriendo ✅"})


def _cors_preflight():
    resp = app.make_response("")
    resp.headers["Access-Control-Allow-Origin"]  = "*"
    resp.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    return resp, 204


# ── Arranque ──────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print()
    print("╔══════════════════════════════════════════════╗")
    print("║   BioFreq — Servidor local Alembique         ║")
    print("╠══════════════════════════════════════════════╣")
    print("║   http://localhost:5000/generarSQC           ║")
    print("║   http://localhost:5000/mezclarAlkam         ║")
    print("║                                              ║")
    print("║   Ctrl+C para detener                        ║")
    print("╚══════════════════════════════════════════════╝")
    print()
    app.run(host="127.0.0.1", port=5000, debug=False, use_reloader=False)
