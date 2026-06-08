// lib/services/printer_service.dart
// Servicio de impresión térmica Bluetooth (protocolo ESC/POS, papel 58mm).
//
// PERMISOS — añadir manualmente en android/app/src/main/AndroidManifest.xml
// dentro del tag <manifest>:
//
//   <!-- Android <= 11 -->
//   <uses-permission android:name="android.permission.BLUETOOTH"
//       android:maxSdkVersion="30" />
//   <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
//       android:maxSdkVersion="30" />
//
//   <!-- Android 12+ -->
//   <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
//       android:usesPermissionFlags="neverForLocation" />
//   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/sale.dart';
import '../data/models/sale_item.dart';

// ─────────────────────────────────────────────────────────────────────────────

class PrinterException implements Exception {
  final String message;
  const PrinterException(this.message);
  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────────────────────

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  static const _prefKey = 'saved_printer_mac';

  // ── Gestión de dispositivos ──────────────────────────────────────────────

  /// Lista impresoras ya emparejadas en el sistema.
  Future<List<BluetoothInfo>> getPairedDevices() =>
      PrintBluetoothThermal.pairedBluetooths;

  /// Dirección MAC guardada como impresora preferida.
  Future<String?> getSavedMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  /// Guarda la dirección MAC como impresora preferida.
  Future<void> saveMac(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mac);
  }

  /// Elimina la impresora guardada (para cambiarla).
  Future<void> clearSavedMac() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  // ── Impresión ────────────────────────────────────────────────────────────

  /// Conecta a [mac] y envía el recibo de venta.
  /// Lanza [PrinterException] si falla la conexión o el envío.
  Future<void> printReceipt({
    required String mac,
    required String businessName,
    required Sale sale,
    required List<SaleItem> items,
    required String currency,
  }) async {
    // Conectar si no hay conexión activa
    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (!ok) {
        throw const PrinterException(
          'No se pudo conectar. Verifica que la impresora esté encendida y emparejada.',
        );
      }
    }

    final bytes = await _buildReceiptBytes(
      businessName: businessName,
      sale: sale,
      items: items,
      currency: currency,
    );

    final sent = await PrintBluetoothThermal.writeBytes(bytes);
    if (!sent) {
      throw const PrinterException('Error al enviar datos. Intenta de nuevo.');
    }
  }

  // ── Construcción del recibo ESC/POS ─────────────────────────────────────

  Future<List<int>> _buildReceiptBytes({
    required String businessName,
    required Sale sale,
    required List<SaleItem> items,
    required String currency,
  }) async {
    final profile   = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes     = <int>[];

    // Cabecera
    bytes.addAll(generator.emptyLines(1));
    bytes.addAll(generator.text(
      businessName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    bytes.addAll(generator.text(
      DateFormat('dd/MM/yyyy  HH:mm').format(sale.createdAt),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      'Recibo #${sale.id.substring(0, 8).toUpperCase()}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.hr());

    // Items
    for (final item in items) {
      bytes.addAll(generator.row([
        PosColumn(
          text: '${item.productName} x${item.quantity}',
          width: 8,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _fmt(item.lineTotal, currency),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.hr());

    // Descuento (si aplica)
    if (sale.discountAmount > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Subtotal:', width: 8,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: _fmt(sale.subtotal, currency), width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      bytes.addAll(generator.row([
        PosColumn(text: 'Descuento:', width: 8,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: '-${_fmt(sale.discountAmount, currency)}', width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
      bytes.addAll(generator.hr());
    }

    // Total
    bytes.addAll(generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: _fmt(sale.total, currency),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]));

    bytes.addAll(generator.hr());

    // Método de pago
    bytes.addAll(generator.text(
      sale.paymentMethod == PaymentMethod.cash
          ? 'Pago en efectivo'
          : 'Transferencia',
      styles: const PosStyles(align: PosAlign.center),
    ));

    // Cierre
    bytes.addAll(generator.emptyLines(1));
    bytes.addAll(generator.text(
      '¡Gracias por su compra!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.emptyLines(4));
    bytes.addAll(generator.cut());

    return bytes;
  }

  String _fmt(double amount, String currency) =>
      '$currency ${amount.toStringAsFixed(2)}';
}
