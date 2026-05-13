// ======================================================================
// BioFreq — Módulo: version
// part of '../main.dart'
// ======================================================================

part of '../main.dart';

// ── Resultado de comparar la versión local con la remota ─────────────────
enum VersionDelta { upToDate, minor, major, patch }

class VersionInfo {
  final int major, minor, patch;
  final int
      buildNumber; // +50, +51 … para detectar PATCH dentro del mismo semver
  final String raw;
  final String? apkUrl; // solo viene en actualizaciones MAJOR
  final String? apkSha256; // hash opcional del APK publicado
  final String? changelogEs; // texto corto para el banner MINOR

  const VersionInfo({
    required this.major,
    required this.minor,
    required this.patch,
    required this.raw,
    this.buildNumber = 0,
    this.apkUrl,
    this.apkSha256,
    this.changelogEs,
  });

  factory VersionInfo.parse(
    String v, {
    int buildNumber = 0,
    String? apkUrl,
    String? apkSha256,
    String? changelogEs,
  }) {
    // Acepta tanto "2.10.0" como "2.10.0+50"
    final versionOnly = v.contains('+') ? v.split('+').first : v;
    final parts = versionOnly.split('.').map(int.parse).toList();
    return VersionInfo(
      major: parts[0],
      minor: parts[1],
      patch: parts[2],
      buildNumber: buildNumber,
      raw: v,
      apkUrl: apkUrl,
      apkSha256: apkSha256,
      changelogEs: changelogEs,
    );
  }

  VersionDelta compareTo(VersionInfo other) {
    // MAJOR: único que bloquea la app (cambio de sistema/seguridad)
    // Solo cuando el primer número SUBE — versiones anteriores siguen funcionando
    if (other.major > major) return VersionDelta.major;

    // MINOR/PATCH: nunca bloquean, solo muestran banner informativo
    // Versiones antiguas del mismo MAJOR funcionan sin restricción
    if (other.minor > minor) return VersionDelta.minor;
    if (other.patch > patch) return VersionDelta.minor; // patch → banner suave
    if (other.buildNumber > buildNumber) {
      return VersionDelta.upToDate; // build silencioso
    }
    return VersionDelta.upToDate;
  }
}

class AppUpdateConfig {
  // FUENTE OFICIAL DEL BANNER: version.json debe ganar siempre.
  // No volver a priorizar Firestore/Play Store aqui: Firestore es solo fallback
  // heredado para Admin/enlaces cuando version.json no trae apk_url.
  static const String _defaultApkUrl =
      'https://raw.githubusercontent.com/biofreqapp-cloud/Biofreq-sounds/main/app-release.apk';

  static String? _cachedUpdaterUrl;
  static bool _loaded = false;

  static String get defaultApkUrl => _defaultApkUrl;

  static String get currentApkUrl =>
      normalizeUpdaterUrl(_cachedUpdaterUrl) ?? _defaultApkUrl;

  static Future<String> load() async {
    if (_loaded) return currentApkUrl;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(BioConfig.colConfiguracion)
          .doc(BioConfig.docApp)
          .get();
      final raw = doc.data()?[BioConfig.campoUrlActualizadorApk]?.toString();
      final normalized = normalizeUpdaterUrl(raw);
      if (normalized != null && normalized.isNotEmpty) {
        _cachedUpdaterUrl = normalized;
      }
    } catch (e) {
      debugPrint('[Updater] Error cargando URL remota: $e');
    }
    _loaded = true;
    return currentApkUrl;
  }

  static void setCachedUrl(String rawUrl) {
    final normalized = normalizeUpdaterUrl(rawUrl);
    if (normalized == null || normalized.isEmpty) return;
    _cachedUpdaterUrl = normalized;
    _loaded = true;
  }

  static String resolve([String? remoteUrl]) {
    // ORDEN CRITICO: el banner usa apk_url de version.json. Firestore no puede
    // pisarlo porque ahi suelen quedar URLs viejas del updater.
    final versionJsonUrl = normalizeUpdaterUrl(remoteUrl);
    if (versionJsonUrl != null && versionJsonUrl.isNotEmpty) {
      return versionJsonUrl;
    }

    final firestoreUrl = normalizeUpdaterUrl(_cachedUpdaterUrl);
    if (firestoreUrl != null && firestoreUrl.isNotEmpty) {
      return firestoreUrl;
    }

    return _defaultApkUrl;
  }

  static String withReferralCode(String codigo) {
    final base = Uri.parse(currentApkUrl);
    final params = Map<String, String>.from(base.queryParameters);
    params['ref'] = codigo;
    return base.replace(queryParameters: params).toString();
  }

  static String? normalizeUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final text = rawUrl.trim();
    if (text.isEmpty) return null;

    if (RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(text)) {
      return 'https://drive.google.com/uc?export=download&id=$text';
    }

    final uri = Uri.tryParse(text);
    if (uri == null) return text;

    final host = uri.host.toLowerCase();
    if (host.contains('drive.google.com') || host.contains('docs.google.com')) {
      final idFromQuery = uri.queryParameters['id'];
      if (idFromQuery != null && idFromQuery.isNotEmpty) {
        return 'https://drive.google.com/uc?export=download&id=$idFromQuery';
      }

      final segments = uri.pathSegments;
      final dIndex = segments.indexOf('d');
      if (dIndex != -1 && dIndex + 1 < segments.length) {
        return 'https://drive.google.com/uc?export=download&id=${segments[dIndex + 1]}';
      }

      final fileIndex = segments.indexOf('file');
      if (fileIndex != -1 &&
          fileIndex + 2 < segments.length &&
          segments[fileIndex + 1] == 'd') {
        return 'https://drive.google.com/uc?export=download&id=${segments[fileIndex + 2]}';
      }
    }

    return text;
  }

  static String? normalizeUpdaterUrl(String? rawUrl) {
    final normalized = normalizeUrl(rawUrl);
    if (normalized == null || normalized.isEmpty) return null;

    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final rejectedUpdaterTarget = scheme == 'market' ||
        host.contains('play.google.com') ||
        host.contains('onrender.com');

    if (rejectedUpdaterTarget) {
      debugPrint('[Updater] URL rechazada para APK: $normalized');
      return null;
    }

    return normalized;
  }
}

const MethodChannel _kSystemDownloaderChannel = MethodChannel(
  'biofreq/system_downloader',
);
const String _kUpdaterDownloadIdKey = 'biofreq_updater_download_id';
const String _kUpdaterDownloadUrlKey = 'biofreq_updater_download_url';
const String _kUpdaterDownloadFileKey = 'biofreq_updater_download_file';

class _AndroidDownloadSnapshot {
  final int status;
  final int reason;
  final int downloadedBytes;
  final int totalBytes;
  final String? localUri;
  final String? contentUri;

  const _AndroidDownloadSnapshot({
    required this.status,
    required this.reason,
    required this.downloadedBytes,
    required this.totalBytes,
    this.localUri,
    this.contentUri,
  });

  factory _AndroidDownloadSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return _AndroidDownloadSnapshot(
      status: (map['status'] as num?)?.toInt() ?? -1,
      reason: (map['reason'] as num?)?.toInt() ?? 0,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      localUri: map['localUri']?.toString(),
      contentUri: map['contentUri']?.toString(),
    );
  }

  bool get isPending => status == 1;
  bool get isRunning => status == 2;
  bool get isPaused => status == 4;
  bool get isSuccessful => status == 8;
  bool get isFailed => status == 16;

  double? get progress {
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }
}

Future<void> _clearStoredAndroidDownload() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kUpdaterDownloadIdKey);
  await prefs.remove(_kUpdaterDownloadUrlKey);
  await prefs.remove(_kUpdaterDownloadFileKey);
}

Future<void> _storeAndroidDownload({
  required int id,
  required String apkUrl,
  required String fileName,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kUpdaterDownloadIdKey, id);
  await prefs.setString(_kUpdaterDownloadUrlKey, apkUrl);
  await prefs.setString(_kUpdaterDownloadFileKey, fileName);
}

Future<({int id, String? apkUrl, String? fileName})?>
    _loadStoredAndroidDownload() async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getInt(_kUpdaterDownloadIdKey);
  if (id == null) return null;
  return (
    id: id,
    apkUrl: prefs.getString(_kUpdaterDownloadUrlKey),
    fileName: prefs.getString(_kUpdaterDownloadFileKey),
  );
}

Future<int?> _enqueueAndroidApkDownload(
  String apkUrl, {
  required String fileName,
}) async {
  final result = await _kSystemDownloaderChannel.invokeMethod<dynamic>(
    'enqueueApkDownload',
    {
      'url': apkUrl,
      'fileName': fileName,
      'title': 'BioFreq ${BioConfig.version}',
      'description':
          'Descargando actualizacion. Puedes bloquear el telefono y continuara.',
    },
  );
  if (result is int) return result;
  if (result is num) return result.toInt();
  return int.tryParse(result?.toString() ?? '');
}

Future<_AndroidDownloadSnapshot?> _queryAndroidDownload(int downloadId) async {
  final raw = await _kSystemDownloaderChannel.invokeMethod<dynamic>(
    'queryDownload',
    {'downloadId': downloadId},
  );
  if (raw is Map) return _AndroidDownloadSnapshot.fromMap(raw);
  return null;
}

Future<bool> _openDownloadedAndroidApk(int downloadId) async {
  final raw = await _kSystemDownloaderChannel.invokeMethod<dynamic>(
    'openDownloadedApk',
    {'downloadId': downloadId},
  );
  if (raw is bool) return raw;
  return raw?.toString() == 'true';
}

Future<String?> _sha256AndroidDownload(int downloadId) async {
  final raw = await _kSystemDownloaderChannel.invokeMethod<dynamic>(
    'sha256DownloadedApk',
    {'downloadId': downloadId},
  );
  return _normalizeSha256(raw?.toString());
}

Future<void> _openDownloadsUi() async {
  try {
    await _kSystemDownloaderChannel.invokeMethod('openDownloadsUi');
  } catch (_) {}
}

void _pollAndroidDownloadInBackground(
  int downloadId, {
  required String apkUrl,
  ValueChanged<double>? onProgress,
}) {
  unawaited(() async {
    for (var i = 0; i < 3600; i++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final snap = await _queryAndroidDownload(downloadId);
        if (snap == null) return;
        final progress = snap.progress;
        if (progress != null) onProgress?.call(progress);

        if (snap.isSuccessful) {
          await _addInstallBreadcrumb(
            'system_download_completed',
            message: 'Descarga persistente completada',
            apkUrl: apkUrl,
            resultType: snap.status.toString(),
            resultMessage: snap.contentUri ?? snap.localUri,
          );
          onProgress?.call(1.0);
          return;
        }
        if (snap.isFailed) {
          await _captureInstallMessage(
            'La descarga persistente fallo',
            stage: 'system_download_failed',
            level: SentryLevel.error,
            apkUrl: apkUrl,
            resultType: snap.status.toString(),
            resultMessage: 'reason=${snap.reason}',
          );
          await _clearStoredAndroidDownload();
          return;
        }
      } catch (_) {
        return;
      }
    }
  }());
}

Future<bool> _handleAndroidPersistentDownload(
  BuildContext context,
  String apkUrl, {
  String? expectedSha256,
  ValueChanged<double>? onProgress,
}) async {
  final stored = await _loadStoredAndroidDownload();
  if (stored != null && stored.apkUrl == apkUrl) {
    final existing = await _queryAndroidDownload(stored.id);
    if (existing != null) {
      if (existing.isSuccessful) {
        final hashOk = await _verifyAndroidDownloadedApk(
          context,
          stored.id,
          expectedSha256,
          apkUrl,
        );
        if (!hashOk) return false;

        final installerReady = await _ensureAndroidInstallerReady(context);
        if (!installerReady) {
          _mostrarSnackActualizador(
            context,
            'La actualización ya está descargada. Permite instalar apps y vuelve a tocar Actualizar.',
          );
          return false;
        }
        final opened = await _openDownloadedAndroidApk(stored.id);
        if (opened) {
          await _addInstallBreadcrumb(
            'system_download_install_opened',
            message:
                'Instalador abierto desde descarga persistente ya completa',
            apkUrl: apkUrl,
          );
          return true;
        }
      }

      if (existing.isPending || existing.isRunning || existing.isPaused) {
        final progress = existing.progress;
        if (progress != null) onProgress?.call(progress);
        _pollAndroidDownloadInBackground(
          stored.id,
          apkUrl: apkUrl,
          onProgress: onProgress,
        );
        _mostrarSnackActualizador(
          context,
          'La actualización ya se está descargando. Puedes bloquear el teléfono; Android continuará la descarga.',
        );
        return true;
      }

      if (existing.isFailed) {
        await _clearStoredAndroidDownload();
      }
    }
  }

  final now = DateTime.now();
  final fileName =
      'BioFreq_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.apk';
  final downloadId = await _enqueueAndroidApkDownload(
    apkUrl,
    fileName: fileName,
  );
  if (downloadId == null) {
    await _captureInstallMessage(
      'No se pudo encolar la descarga persistente',
      stage: 'system_download_enqueue_failed',
      level: SentryLevel.error,
      apkUrl: apkUrl,
    );
    return false;
  }

  await _storeAndroidDownload(
      id: downloadId, apkUrl: apkUrl, fileName: fileName);
  await _addInstallBreadcrumb(
    'system_download_enqueued',
    message: 'Descarga persistente encolada en DownloadManager',
    apkUrl: apkUrl,
    resultType: downloadId.toString(),
  );
  onProgress?.call(0);
  _pollAndroidDownloadInBackground(
    downloadId,
    apkUrl: apkUrl,
    onProgress: onProgress,
  );
  _mostrarSnackActualizador(
    context,
    'Descarga iniciada. Si bloqueas el teléfono, Android seguirá descargando y quedará en Descargas para instalar luego.',
  );
  await _openDownloadsUi();
  return true;
}

String _enumName(Object? value) {
  if (value == null) return 'null';
  final text = value.toString();
  final idx = text.lastIndexOf('.');
  return idx == -1 ? text : text.substring(idx + 1);
}

Future<void> _addInstallBreadcrumb(
  String stage, {
  String? message,
  String? apkUrl,
  String? apkPath,
  String? resultType,
  String? resultMessage,
  Map<String, Object?>? extra,
}) async {
  final data = <String, Object?>{
    'stage': stage,
    if (apkUrl != null) 'apk_url': apkUrl,
    if (apkPath != null) 'apk_path': apkPath,
    if (resultType != null) 'result_type': resultType,
    if (resultMessage != null) 'result_message': resultMessage,
    ...?extra,
  };

  await Sentry.addBreadcrumb(
    Breadcrumb(
      category: 'app.install',
      type: 'debug',
      level: SentryLevel.info,
      message: message ?? stage,
      data: data,
    ),
  );
}

Future<void> _captureInstallMessage(
  String message, {
  required String stage,
  SentryLevel level = SentryLevel.warning,
  String? apkUrl,
  String? apkPath,
  String? resultType,
  String? resultMessage,
  Map<String, Object?>? extra,
}) async {
  await Sentry.captureMessage(
    message,
    level: level,
    withScope: (scope) {
      scope.setTag('flow', 'app_install');
      scope.setTag('install_stage', stage);
      if (apkUrl != null) scope.setExtra('apk_url', apkUrl);
      if (apkPath != null) scope.setExtra('apk_path', apkPath);
      if (resultType != null) scope.setExtra('result_type', resultType);
      if (resultMessage != null)
        scope.setExtra('result_message', resultMessage);
      extra?.forEach((key, value) => scope.setExtra(key, value));
    },
  );
}

Future<void> _captureInstallException(
  Object error,
  StackTrace stackTrace, {
  required String stage,
  String? apkUrl,
  String? apkPath,
  String? resultType,
  String? resultMessage,
  Map<String, Object?>? extra,
}) async {
  await Sentry.captureException(
    error,
    stackTrace: stackTrace,
    withScope: (scope) {
      scope.setTag('flow', 'app_install');
      scope.setTag('install_stage', stage);
      if (apkUrl != null) scope.setExtra('apk_url', apkUrl);
      if (apkPath != null) scope.setExtra('apk_path', apkPath);
      if (resultType != null) scope.setExtra('result_type', resultType);
      if (resultMessage != null)
        scope.setExtra('result_message', resultMessage);
      extra?.forEach((key, value) => scope.setExtra(key, value));
    },
  );
}

Future<bool> instalarActualizacionDesdeUrl(
  BuildContext context,
  String rawUrl, {
  String? expectedSha256,
  ValueChanged<double>? onProgress,
}) async {
  final apkUrl = AppUpdateConfig.resolve(rawUrl);
  if (apkUrl.isEmpty) {
    await _captureInstallMessage(
      'Updater sin URL disponible',
      stage: 'updater_url_missing',
      level: SentryLevel.error,
      apkUrl: rawUrl,
    );
    if (!context.mounted) return false;
    _mostrarSnackActualizador(
      context,
      'URL de actualización no disponible.',
      isError: true,
    );
    return false;
  }

  try {
    if (Platform.isAndroid) {
      return await _handleAndroidPersistentDownload(
        context,
        apkUrl,
        expectedSha256: expectedSha256,
        onProgress: onProgress,
      );
    }

    await _addInstallBreadcrumb(
      'installer_requested',
      message: 'Inicio de flujo de actualización',
      apkUrl: apkUrl,
    );

    if (!context.mounted) return false;
    if (Platform.isAndroid) {
      final installerReady = await _ensureAndroidInstallerReady(context);
      if (!installerReady) return false;
    }

    final dir = await getTemporaryDirectory();
    final apkPath =
        '${dir.path}/biofreq_update_${DateTime.now().millisecondsSinceEpoch}.apk';

    await _addInstallBreadcrumb(
      'download_started',
      message: 'Descargando APK de actualización',
      apkUrl: apkUrl,
      apkPath: apkPath,
    );

    await Dio().download(
      apkUrl,
      apkPath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(received / total);
        }
      },
      options: Options(
        followRedirects: true,
        maxRedirects: 10,
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    await _addInstallBreadcrumb(
      'download_completed',
      message: 'APK descargado',
      apkUrl: apkUrl,
      apkPath: apkPath,
    );

    final apkFile = File(apkPath);
    if (!await apkFile.exists()) {
      await _captureInstallMessage(
        'El APK descargado no existe al terminar la descarga',
        stage: 'apk_missing_after_download',
        level: SentryLevel.error,
        apkUrl: apkUrl,
        apkPath: apkPath,
      );
      throw Exception('No se encontr\u00f3 el APK descargado.');
    }
    if (!await _isProbablyApkFile(apkFile)) {
      await _captureInstallMessage(
        'La descarga no parece un APK válido',
        stage: 'apk_validation_failed',
        level: SentryLevel.error,
        apkUrl: apkUrl,
        apkPath: apkPath,
      );
      throw Exception(
        'La descarga no parece un APK v\u00e1lido. Revisa la URL del actualizador.',
      );
    }

    if (!await _verifyDownloadedApkSha256(
      context,
      apkFile,
      expectedSha256,
      apkUrl,
    )) {
      return false;
    }

    await _addInstallBreadcrumb(
      'installer_launch_attempt',
      message: 'Intentando abrir el instalador del sistema',
      apkUrl: apkUrl,
      apkPath: apkPath,
    );

    var result = await OpenFile.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );

    await _addInstallBreadcrumb(
      'installer_launch_result',
      message: 'Resultado del primer OpenFile',
      apkUrl: apkUrl,
      apkPath: apkPath,
      resultType: result.type.toString(),
      resultMessage: result.message,
    );

    if (result.type == ResultType.done) {
      await _addInstallBreadcrumb(
        'installer_handoff_ok',
        message: 'Control entregado al instalador Android',
        apkUrl: apkUrl,
        apkPath: apkPath,
      );
      return true;
    }

    var message = result.message.toLowerCase();
    if (Platform.isAndroid && _isInstallerPermissionError(message)) {
      if (!context.mounted) return false;
      await _captureInstallMessage(
        'El sistema bloqueó la apertura del instalador por permiso',
        stage: 'installer_permission_blocked',
        apkUrl: apkUrl,
        apkPath: apkPath,
        resultType: result.type.toString(),
        resultMessage: result.message,
      );
      if (!context.mounted) return false;
      final installerReady = await _ensureAndroidInstallerReady(
        context,
        forceRequest: true,
      );
      if (!installerReady) return false;

      result = await OpenFile.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );
      await _addInstallBreadcrumb(
        'installer_launch_retry_result',
        message: 'Resultado del segundo OpenFile',
        apkUrl: apkUrl,
        apkPath: apkPath,
        resultType: result.type.toString(),
        resultMessage: result.message,
      );
      if (result.type == ResultType.done) {
        await _addInstallBreadcrumb(
          'installer_handoff_ok_after_permission',
          message: 'Control entregado al instalador tras pedir permiso',
          apkUrl: apkUrl,
          apkPath: apkPath,
        );
        return true;
      }
      message = result.message.toLowerCase();
    }

    await _captureInstallMessage(
      'OpenFile no logró entregar el APK al instalador',
      stage: 'installer_open_failed',
      level: SentryLevel.error,
      apkUrl: apkUrl,
      apkPath: apkPath,
      resultType: result.type.toString(),
      resultMessage: result.message,
    );
    throw Exception(result.message);
  } catch (e, stackTrace) {
    await _captureInstallException(
      e,
      stackTrace,
      stage: 'installer_exception',
      apkUrl: apkUrl,
    );
    if (!context.mounted) return false;
    _mostrarSnackActualizador(
      context,
      'Error al descargar o instalar: $e',
      isError: true,
    );
    return false;
  }
}

void _mostrarSnackActualizador(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor:
          isError ? AccesibleColors.error : AccesibleColors.warning,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 5 : 7),
    ),
  );
}

Future<bool> _ensureAndroidInstallerReady(
  BuildContext context, {
  bool forceRequest = false,
}) async {
  if (!Platform.isAndroid) return true;

  try {
    var status = await Permission.requestInstallPackages.status;
    await _addInstallBreadcrumb(
      'installer_permission_status',
      message: 'Estado actual del permiso de instalación',
      extra: {'permission_status': _enumName(status)},
    );
    if (status.isGranted) return true;

    if (forceRequest || status.isDenied || status.isRestricted) {
      status = await Permission.requestInstallPackages.request();
      await _addInstallBreadcrumb(
        'installer_permission_requested',
        message: 'Resultado de solicitar permiso de instalación',
        extra: {'permission_status': _enumName(status)},
      );
      if (status.isGranted) return true;
    }

    await _captureInstallMessage(
      'Permiso de instalar apps desconocidas no concedido',
      stage: 'installer_permission_not_granted',
      extra: {'permission_status': _enumName(status)},
    );
    if (!context.mounted) return false;
    _mostrarSnackActualizador(
      context,
      'Debes permitir "Instalar apps desconocidas" para BioFreq antes de actualizar.',
    );
    return false;
  } catch (e) {
    debugPrint('[Updater] Error comprobando permiso de instalaci\u00f3n: $e');
    await _captureInstallException(
      e,
      StackTrace.current,
      stage: 'installer_permission_check_exception',
    );
    return true;
  }
}

bool _isInstallerPermissionError(String message) {
  return message.contains('request_install_packages') ||
      (message.contains('permission') && message.contains('denied'));
}

Future<bool> _isProbablyApkFile(File file) async {
  final raf = await file.open();
  try {
    if (await raf.length() < 4) return false;
    final header = await raf.read(4);
    if (header.length < 2) return false;
    return header[0] == 0x50 && header[1] == 0x4B;
  } finally {
    await raf.close();
  }
}

String? _normalizeSha256(String? value) {
  final text = value?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(text)) return null;
  return text;
}

Future<bool> _verifyAndroidDownloadedApk(
  BuildContext context,
  int downloadId,
  String? expectedSha256,
  String apkUrl,
) async {
  final expected = _normalizeSha256(expectedSha256);
  if (expected == null) return true;

  try {
    final actual = await _sha256AndroidDownload(downloadId);
    if (actual == expected) {
      await _addInstallBreadcrumb(
        'apk_sha256_verified',
        message: 'APK verificado antes de instalar',
        apkUrl: apkUrl,
        resultType: 'android_download_manager',
        extra: {'sha256': actual},
      );
      return true;
    }

    await _clearStoredAndroidDownload();
    await _captureInstallMessage(
      'El APK descargado no coincide con el hash publicado',
      stage: 'apk_sha256_mismatch',
      level: SentryLevel.error,
      apkUrl: apkUrl,
      resultType: 'android_download_manager',
      extra: {
        'expected_sha256': expected,
        'actual_sha256': actual ?? 'unavailable',
      },
    );
    if (context.mounted) {
      _mostrarSnackActualizador(
        context,
        'La descarga no paso la verificacion de seguridad. Toca Actualizar otra vez.',
        isError: true,
      );
    }
    return false;
  } catch (e, stackTrace) {
    await _captureInstallException(
      e,
      stackTrace,
      stage: 'apk_sha256_exception',
      apkUrl: apkUrl,
      resultType: 'android_download_manager',
      extra: {'expected_sha256': expected},
    );
    if (context.mounted) {
      _mostrarSnackActualizador(
        context,
        'No se pudo verificar la descarga. Intentalo de nuevo.',
        isError: true,
      );
    }
    return false;
  }
}

Future<bool> _verifyDownloadedApkSha256(
  BuildContext context,
  File apkFile,
  String? expectedSha256,
  String apkUrl,
) async {
  final expected = _normalizeSha256(expectedSha256);
  if (expected == null) return true;

  try {
    final digest = await sha256.bind(apkFile.openRead()).first;
    final actual = digest.toString().toLowerCase();
    if (actual == expected) {
      await _addInstallBreadcrumb(
        'apk_sha256_verified',
        message: 'APK verificado antes de instalar',
        apkUrl: apkUrl,
        apkPath: apkFile.path,
        resultType: 'dart_file',
        extra: {'sha256': actual},
      );
      return true;
    }

    await _captureInstallMessage(
      'El APK descargado no coincide con el hash publicado',
      stage: 'apk_sha256_mismatch',
      level: SentryLevel.error,
      apkUrl: apkUrl,
      apkPath: apkFile.path,
      resultType: 'dart_file',
      extra: {
        'expected_sha256': expected,
        'actual_sha256': actual,
      },
    );
    if (context.mounted) {
      _mostrarSnackActualizador(
        context,
        'La descarga no paso la verificacion de seguridad. Toca Actualizar otra vez.',
        isError: true,
      );
    }
    return false;
  } catch (e, stackTrace) {
    await _captureInstallException(
      e,
      stackTrace,
      stage: 'apk_sha256_exception',
      apkUrl: apkUrl,
      apkPath: apkFile.path,
      resultType: 'dart_file',
      extra: {'expected_sha256': expected},
    );
    if (context.mounted) {
      _mostrarSnackActualizador(
        context,
        'No se pudo verificar la descarga. Intentalo de nuevo.',
        isError: true,
      );
    }
    return false;
  }
}

class EdMarkConfig {
  static String? _cachedBaseUrl;
  static bool _loaded = false;

  static String? get currentBaseUrl => normalizeBaseUrl(_cachedBaseUrl);

  static Future<String?> load() async {
    if (_loaded) return currentBaseUrl;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(BioConfig.colConfiguracion)
          .doc(BioConfig.docApp)
          .get();
      final raw = doc.data()?[BioConfig.campoUrlEdmark]?.toString();
      _cachedBaseUrl = normalizeBaseUrl(raw);
    } catch (e) {
      debugPrint('[EdMark] Error cargando URL remota: $e');
    }
    _loaded = true;
    return currentBaseUrl;
  }

  static void setCachedUrl(String? rawUrl) {
    _cachedBaseUrl = normalizeBaseUrl(rawUrl);
    _loaded = true;
  }

  static String? resolve([String? remoteUrl]) {
    return normalizeBaseUrl(_cachedBaseUrl) ?? normalizeBaseUrl(remoteUrl);
  }

  static String? uploadBannerUrl([String? remoteUrl]) {
    final base = resolve(remoteUrl);
    if (base == null || base.isEmpty) return null;
    if (base.endsWith('/uploadBannerGithub')) return base;
    return '$base/uploadBannerGithub';
  }

  static String? normalizeBaseUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final text = rawUrl.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    final clean = uri.replace(queryParameters: {}, fragment: '');
    var normalized = clean.toString();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

class VersionManager {
  // ⚠️  ARCHIVO EN GITHUB: remote_config.json — NO renombrar a version.json
  //     La app lee ESTE archivo para saber si hay actualización disponible.
  // ⚠️  Apunta a version.json — el mismo archivo que edita el admin en GitHub.
  //     Era remote_config.json antes, pero el admin edita version.json.
  static const String _versionJsonUrl =
      'https://raw.githubusercontent.com/biofreqapp-cloud/Biofreq-sounds/main/version.json';
  static const int _maxJsonBytes = 64 * 1024;

  static Map<String, dynamic>? _decodeSmallJsonResponse(
    http.Response resp,
    String label,
  ) {
    final bytes = resp.bodyBytes;
    if (bytes.length > _maxJsonBytes) {
      debugPrint(
        '[Version] $label demasiado grande: ${bytes.length} bytes. Se ignora.',
      );
      return null;
    }

    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    if (decoded is Map<String, dynamic>) return decoded;

    debugPrint('[Version] $label no devolvió un objeto JSON.');
    return null;
  }

  /// Comprueba la versión remota y retorna el delta. Nunca lanza excepción.
  static Future<({VersionDelta delta, VersionInfo? remote})> check(
      String localVersion) async {
    try {
      await AppUpdateConfig.load();
      final resp = await http.get(
        Uri.parse(_versionJsonUrl),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200)
        return (delta: VersionDelta.upToDate, remote: null);

      final json = _decodeSmallJsonResponse(resp, 'version.json');
      if (json == null) {
        return (delta: VersionDelta.upToDate, remote: null);
      }

      // Leer build_number del JSON (campo nuevo desde v2.10.0+50)
      final remoteBuild = (json['build_number'] as num?)?.toInt() ?? 0;

      final remote = VersionInfo.parse(
        json['version'] as String,
        buildNumber: remoteBuild,
        apkUrl: AppUpdateConfig.resolve(json['apk_url'] as String?),
        apkSha256: json['apk_sha256']?.toString() ?? json['sha256']?.toString(),
        changelogEs: json['changelog_es'] as String?,
      );

      // Extraer build number local desde "2.10.0+50" → 50
      int localBuild = 0;
      if (localVersion.contains('+')) {
        localBuild = int.tryParse(localVersion.split('+').last) ?? 0;
      }
      final local = VersionInfo.parse(localVersion, buildNumber: localBuild);

      return (delta: local.compareTo(remote), remote: remote);
    } catch (_) {
      return (delta: VersionDelta.upToDate, remote: null);
    }
  }

  /// PATCH: descarga config/labels remotos y los guarda en memoria.
  /// No muestra nada al usuario.
  static Future<void> applyPatchConfig(String configUrl) async {
    try {
      final resp = await http
          .get(Uri.parse(configUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = _decodeSmallJsonResponse(resp, 'remote_config');
        if (data != null) {
          RemoteConfig.apply(data); // aplica strings en memoria
        }
        debugPrint('[Version] PATCH config aplicado silenciosamente.');
      }
    } catch (_) {}
  }
}

/// Almacén en memoria para strings remotos (Hot Update de PATCH).
class RemoteConfig {
  static final Map<String, String> _data = {};

  static void apply(Map<String, dynamic> json) {
    json.forEach((k, v) => _data[k] = v.toString());
  }

  /// Devuelve el string remoto si existe, o el fallback local.
  static String get(String key, String fallback) => _data[key] ?? fallback;
}

// ═══════════════════════════════════════════════════════════════════════════
// SISTEMA 3 — GeminiMask (traducción volátil on-the-fly)
// Detecta el Locale del sistema y traduce strings a ese idioma mediante
// Gemini. El resultado NUNCA se guarda en BD — solo se muestra en pantalla.
// ═══════════════════════════════════════════════════════════════════════════
