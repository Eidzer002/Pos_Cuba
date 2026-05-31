// lib/data/local/powersync_schema.dart
// Schema completo de PowerSync para SQLite local.
// Todas las tablas [SYNC] se sincronizan con Supabase PostgreSQL.
// La tabla settings_local es [LOCAL] y NO se sincroniza.

import 'package:powersync/powersync.dart';

/// Schema completo de la base de datos PowerSync.
/// 
/// Tablas [SYNC]: businesses, categories, products, sales, sale_items,
/// stock_movements, cash_sessions, cash_movements, workers
/// 
/// Tabla [LOCAL]: settings_local (solo local, no sync)
final Schema appSchema = Schema([
  // ============================================
  // [SYNC] businesses — Negocios registrados
  // ============================================
  Table('businesses', [
    Column.text('owner_id'),
    Column.text('name'),
    Column.text('currency_symbol'),
    Column.text('address'),
    Column.text('phone'),
    Column.text('logo_path'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ], indexes: [
    Index('idx_businesses_owner', ['owner_id']),
  ]),

  // ============================================
  // [SYNC] categories — Categorias de productos
  // ============================================
  Table('categories', [
    Column.text('business_id'),
    Column.text('name'),
    Column.text('color_hex'),
    Column.integer('sort_order'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'), // Soft delete
  ], indexes: [
    Index('idx_categories_business', ['business_id']),
    Index('idx_categories_sort', ['business_id', 'sort_order']),
  ]),

  // ============================================
  // [SYNC] products — Productos del inventario
  // ============================================
  Table('products', [
    Column.text('business_id'),
    Column.text('category_id'),
    Column.text('name'),
    Column.text('description'),
    Column.real('sale_price'),
    Column.real('cost_price'),
    Column.integer('stock'),
    Column.integer('min_stock'),
    Column.text('barcode'),
    Column.text('image_path'),
    Column.integer('track_stock'), // bool: 0/1
    Column.integer('is_active'), // bool: 0/1
    Column.text('created_at'),
    Column.text('updated_at'),
  ], indexes: [
    Index('idx_products_business', ['business_id']),
    Index('idx_products_category', ['category_id']),
    Index('idx_products_name', ['business_id', 'name']),
    Index('idx_products_barcode', ['business_id', 'barcode']),
  ]),

  // ============================================
  // [SYNC] sales — Ventas realizadas
  // ============================================
  Table('sales', [
    Column.text('business_id'),
    Column.text('worker_id'),
    Column.text('cash_session_id'),
    Column.real('total'),
    Column.real('subtotal'),
    Column.real('discount_amount'),
    Column.real('profit'),
    Column.real('worker_commission'),
    Column.text('payment_method'), // 'cash' o 'transfer'
    Column.text('notes'),
    Column.text('status'), // 'completed', 'cancelled'
    Column.text('cancelled_at'),
    Column.text('cancelled_reason'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ], indexes: [
    Index('idx_sales_business_date', ['business_id', 'created_at']),
    Index('idx_sales_session', ['cash_session_id']),
    Index('idx_sales_worker', ['worker_id']),
  ]),

  // ============================================
  // [SYNC] sale_items — Items de cada venta
  // ============================================
  Table('sale_items', [
    Column.text('business_id'),
    Column.text('sale_id'),
    Column.text('product_id'),
    Column.text('product_name'), // Snapshot del nombre
    Column.integer('quantity'),
    Column.real('unit_price'),
    Column.real('unit_cost'),
    Column.real('line_total'),
    Column.real('line_profit'),
    Column.text('created_at'),
  ], indexes: [
    Index('idx_sale_items_business', ['business_id']),
    Index('idx_sale_items_sale', ['sale_id']),
    Index('idx_sale_items_product', ['product_id']),
  ]),

  // ============================================
  // [SYNC] stock_movements — Historial de stock
  // ============================================
  Table('stock_movements', [
    Column.text('business_id'),
    Column.text('product_id'),
    Column.text('movement_type'), // 'sale', 'adjustment_in', 'adjustment_out', 'initial', 'loss', 'return'
    Column.integer('quantity_change'),
    Column.integer('stock_after'),
    Column.text('reference_id'), // ID de venta si aplica
    Column.text('notes'),
    Column.text('created_by'), // 'owner', 'worker', 'system'
    Column.text('created_at'),
  ], indexes: [
    Index('idx_stock_product_date', ['product_id', 'created_at']),
    Index('idx_stock_business', ['business_id']),
  ]),

  // ============================================
  // [SYNC] cash_sessions — Sesiones de caja
  // ============================================
  Table('cash_sessions', [
    Column.text('business_id'),
    Column.text('worker_id'),
    Column.real('opening_amount'),
    Column.real('closing_amount'),
    Column.real('expected_amount'),
    Column.real('difference'),
    Column.text('status'), // 'open', 'closed'
    Column.text('opened_at'),
    Column.text('closed_at'),
    Column.text('notes'),
    Column.text('updated_at'),
  ], indexes: [
    Index('idx_cash_sessions_business', ['business_id']),
    Index('idx_cash_sessions_open', ['business_id', 'status']),
    Index('idx_cash_sessions_worker', ['worker_id']),
  ]),

  // ============================================
  // [SYNC] cash_movements — Movimientos de caja
  // ============================================
  Table('cash_movements', [
    Column.text('business_id'),
    Column.text('cash_session_id'),
    Column.text('movement_type'), // 'in', 'out'
    Column.real('amount'),
    Column.text('description'),
    Column.text('created_at'),
  ], indexes: [
    Index('idx_cash_movements_session', ['cash_session_id']),
    Index('idx_cash_movements_business', ['business_id']),
  ]),

  // ============================================
  // [SYNC] workers — Trabajadores del negocio
  // ============================================
  Table('workers', [
    Column.text('business_id'),
    Column.text('name'),
    Column.text('pin_hash'), // SHA-256 hash, NUNCA texto plano
    Column.text('commission_type'), // 'percentage' o 'fixed'
    Column.real('commission_value'),
    Column.integer('is_active'), // bool: 0/1
    Column.text('created_at'),
    Column.text('updated_at'),
  ], indexes: [
    Index('idx_workers_business', ['business_id']),
    Index('idx_workers_pin', ['business_id', 'pin_hash']),
  ]),

  // ============================================
  // [LOCAL] settings_local — Configuracion local (NO SYNC)
  // ============================================
  // Esta tabla SOLO existe en el dispositivo.
  // Nunca se sincroniza con Supabase.
  Table.localOnly('settings_local', [
    Column.text('key'),
    Column.text('value'),
    Column.text('updated_at'),
  ], indexes: [
    Index('idx_settings_key', ['key']),
  ]),
]);

/// Claves usadas en settings_local
class SettingsKeys {
  SettingsKeys._();

  static const String theme = 'theme'; // 'light' o 'dark'
  static const String lastBusinessId = 'last_business_id';
  static const String lastActiveWorkerId = 'last_active_worker_id';
  static const String licenseToken = 'license_token'; // JWT cifrado
  static const String licenseLastChecked = 'license_last_checked';
  static const String licenseGraceStart = 'license_grace_start';
}
