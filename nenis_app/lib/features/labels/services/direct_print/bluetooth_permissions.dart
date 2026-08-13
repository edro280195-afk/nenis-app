import 'package:permission_handler/permission_handler.dart';

/// Pide de forma proactiva los permisos de Bluetooth necesarios para
/// escanear/conectar impresoras térmicas, antes de intentar cualquier
/// operación con el hardware.
///
/// Antes de este archivo, la única vía que disparaba el diálogo de
/// permisos del sistema era un efecto secundario de
/// `bluetooth_print_plus.startScan()`, y solo cubría la ruta de
/// descubrimiento clásico: la conexión BLE real de la AIYIN (y el socket
/// RFCOMM crudo de la NIIMBOT) nunca pasaban por ahí, así que si la
/// vendedora nunca había escaneado antes con esa pantalla, esas rutas
/// fallaban por falta de permiso con un mensaje que culpaba al hardware
/// ("enciéndela y acércala al teléfono") en vez de explicar que faltaba
/// conceder Bluetooth.
///
/// En Android 12+ (API 31+) esto pide `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT`
/// sin ubicación (el manifest declara `neverForLocation` en `BLUETOOTH_SCAN`
/// — ver third_party/bluetooth_print_plus/android/.../AndroidManifest.xml).
/// En versiones anteriores, `permission_handler` resuelve automáticamente
/// el permiso de ubicación heredado que el manifest sigue declarando para
/// esos casos. En iOS, la librería no separa scan/connect: el diálogo real
/// lo dispara Core Bluetooth la primera vez que se usa, gateado por
/// `NSBluetoothAlwaysUsageDescription` en Info.plist.
class BluetoothPermissions {
  const BluetoothPermissions._();

  static Future<BluetoothPermissionResult> ensureGranted() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    if (allGranted) {
      return const BluetoothPermissionResult(granted: true);
    }

    final permanentlyDenied = statuses.values.any((status) => status.isPermanentlyDenied);
    return BluetoothPermissionResult(granted: false, permanentlyDenied: permanentlyDenied);
  }
}

class BluetoothPermissionResult {
  const BluetoothPermissionResult({required this.granted, this.permanentlyDenied = false});

  final bool granted;
  final bool permanentlyDenied;

  /// Mensaje orientado a la vendedora, listo para mostrar en un
  /// NiimbotPrintException/AiyinPrintException.
  String get message => permanentlyDenied
      ? 'Nenis necesita permiso de Bluetooth para conectar tu impresora. '
          'Actívalo en Ajustes del teléfono > Apps > Nenis > Permisos.'
      : 'Nenis necesita permiso de Bluetooth para conectar tu impresora. '
          'Vuelve a intentarlo y acepta el permiso que te pida el teléfono.';
}
