package com.nenisapp.nenis_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val googleMapsChannel = "nenis_app/google_maps"
    private val bondedBluetoothChannel = "nenis_app/bonded_bluetooth_devices"
    private val rawSocketChannel = "nenis_app/raw_bluetooth_socket"
    private val rawSocketDataChannel = "nenis_app/raw_bluetooth_socket/data"
    private val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val mainHandler = Handler(Looper.getMainLooper())

    private var rawSocket: BluetoothSocket? = null
    private var rawReadThread: Thread? = null
    private var rawDataSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, googleMapsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasApiKey" -> result.success(hasGoogleMapsApiKey())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bondedBluetoothChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "list" -> result.success(bondedClassicDevices())
                    else -> result.notImplemented()
                }
            }

        // Impresoras con protocolo propio (p.ej. NIIMBOT) no hablan
        // ESC/TSPL/CPCL/ZPL, así que el handshake de verificación del SDK
        // de bluetooth_print_plus nunca termina con ellas. Este canal abre
        // un socket RFCOMM/SPP directo, sin verificación de ningún
        // protocolo de impresora: solo bytes crudos de ida y vuelta.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, rawSocketChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (address == null) {
                            result.error("bad_args", "address is required", null)
                        } else {
                            connectRawSocket(address, result)
                        }
                    }
                    "write" -> {
                        val bytes = call.argument<ByteArray>("data")
                        result.success(writeRawSocket(bytes))
                    }
                    "disconnect" -> {
                        disconnectRawSocket()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, rawSocketDataChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    rawDataSink = events
                }

                override fun onCancel(arguments: Any?) {
                    rawDataSink = null
                }
            })
    }

    private fun connectRawSocket(address: String, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("no_permission", "BLUETOOTH_CONNECT not granted", null)
            return
        }
        disconnectRawSocket()
        Thread {
            // Conectar de inmediato tras cerrar (o intentar y fallar) un
            // socket anterior suele dar "read failed, socket might closed
            // or timeout" en el stack clásico de Android: el canal RFCOMM
            // del lado remoto todavía está liberándose. Un respiro corto
            // antes de cada intento evita el falso negativo (mismo ajuste
            // que ya trae el SDK de la AIYIN al reabrir puerto). Antes solo
            // pausaba si el intento ANTERIOR había llegado a conectar, pero
            // un intento fallido nunca guarda el socket, así que en una
            // racha de fallos nunca se activaba.
            Thread.sleep(400)
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                val device = adapter?.getRemoteDevice(address)
                if (device == null) {
                    mainHandler.post { result.error("no_adapter", "Bluetooth adapter unavailable", null) }
                    return@Thread
                }
                adapter.cancelDiscovery()
                val socket = device.createRfcommSocketToServiceRecord(sppUuid)
                socket.connect()
                rawSocket = socket
                startRawReadLoop(socket)
                mainHandler.post { result.success(null) }
            } catch (e: IOException) {
                mainHandler.post { result.error("connect_failed", e.message, null) }
            }
        }.start()
    }

    private fun startRawReadLoop(socket: BluetoothSocket) {
        val thread = Thread {
            val buffer = ByteArray(1024)
            val input = socket.inputStream
            try {
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) break
                    val chunk = buffer.copyOf(read)
                    mainHandler.post { rawDataSink?.success(chunk) }
                }
            } catch (_: IOException) {
                // Socket cerrado: fin normal del ciclo de lectura.
            }
        }
        rawReadThread = thread
        thread.start()
    }

    private fun writeRawSocket(bytes: ByteArray?): Boolean {
        val socket = rawSocket ?: return false
        if (bytes == null) return false
        return try {
            socket.outputStream.write(bytes)
            socket.outputStream.flush()
            true
        } catch (e: IOException) {
            false
        }
    }

    private fun disconnectRawSocket() {
        rawReadThread = null
        try {
            rawSocket?.close()
        } catch (_: IOException) {
        }
        rawSocket = null
    }

    // Bluetooth clásico (RFCOMM) no reanuncia dispositivos ya emparejados
    // en un escaneo nuevo, así que para reconectar impresoras que la
    // vendedora ya emparejó en Ajustes > Bluetooth leemos directo la lista
    // de vinculados del sistema en vez de depender de un escaneo.
    private fun bondedClassicDevices(): List<Map<String, String>> {
        if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return emptyList()
        }
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return emptyList()
        return adapter.bondedDevices
            .filter { it.type != BluetoothDevice.DEVICE_TYPE_LE }
            .map { mapOf("name" to (it.name ?: ""), "address" to it.address) }
    }

    @Suppress("DEPRECATION")
    private fun hasGoogleMapsApiKey(): Boolean {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        val value = info.metaData
            ?.getString("com.google.android.geo.API_KEY")
            ?.trim()
            .orEmpty()

        return value.isNotEmpty() &&
            !value.equals("YOUR_API_KEY", ignoreCase = true) &&
            !value.contains("GOOGLE_MAPS_API_KEY")
    }
}
