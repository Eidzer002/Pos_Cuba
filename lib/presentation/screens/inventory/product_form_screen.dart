// lib/presentation/screens/inventory/product_form_screen.dart
// Pantalla de creación y edición de productos.
// Ruta /inventory/new  -> productId == null (crear)
// Ruta /inventory/:id  -> productId != null  (editar)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_movement_repository.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/product_provider.dart';

// ---------------------------------------------------------------------------
// Provider del formulario (estado local de la pantalla)
// ---------------------------------------------------------------------------

class _FormState {
  final bool isLoading;
  final String? errorMessage;
  _FormState({this.isLoading = false, this.errorMessage});
  _FormState copyWith({bool? isLoading, String? errorMessage}) => _FormState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

// ---------------------------------------------------------------------------
// ProductFormScreen
// ---------------------------------------------------------------------------

class ProductFormScreen extends ConsumerStatefulWidget {
  /// null = modo creación, non-null = modo edición
  final String? productId;

  const ProductFormScreen({this.productId, super.key});

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '0');
  final _barcodeCtrl = TextEditingController();

  // Estado del formulario
  String? _selectedCategoryId;
  bool _trackStock = true;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isLoaded = false; // para evitar re-cargar al rebuild

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _salePriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  // Llena los campos cuando tenemos el producto (modo edición)
  void _populateFields(Product p) {
    if (_isLoaded) return;
    _isLoaded = true;
    _nameCtrl.text = p.name;
    _descCtrl.text = p.description ?? '';
    _salePriceCtrl.text = p.salePrice.toStringAsFixed(2);
    _costPriceCtrl.text = p.costPrice.toStringAsFixed(2);
    _stockCtrl.text = p.stock.toString();
    _minStockCtrl.text = p.minStock.toString();
    _barcodeCtrl.text = p.barcode ?? '';
    _selectedCategoryId = p.categoryId;
    _trackStock = p.trackStock;
    _isActive = p.isActive;
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(productRepositoryProvider);
      final now = DateTime.now();

      final salePrice = double.parse(_salePriceCtrl.text.replaceAll(',', '.'));
      final costPrice = double.parse(_costPriceCtrl.text.replaceAll(',', '.'));
      final stock = int.tryParse(_stockCtrl.text) ?? 0;
      final minStock = int.tryParse(_minStockCtrl.text) ?? 0;

      if (widget.isEditing) {
        // ---- EDITAR ----
        final current = await repo.getProductById(widget.productId!, business.id);
        if (current == null) throw Exception('Producto no encontrado');

        final updated = current.copyWith(
          categoryId: _selectedCategoryId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          salePrice: salePrice,
          costPrice: costPrice,
          stock: stock,
          minStock: minStock,
          barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
          trackStock: _trackStock,
          isActive: _isActive,
        );

        await repo.updateProduct(updated);

        // Si cambió el stock, registrar movimiento
        if (stock != current.stock) {
          final diff = stock - current.stock;
          await StockMovementRepository(ref.read(productRepositoryProvider).db)
              .recordAdjustment(
            businessId: business.id,
            productId: current.id,
            quantityChange: diff,
            stockAfter: stock,
            notes: 'Ajuste manual desde formulario',
            createdBy: 'owner',
          );
        }

        if (mounted) {
          _showSuccess('Producto actualizado');
          context.pop();
        }
      } else {
        // ---- CREAR ----
        final newProduct = Product(
          id: const Uuid().v4(),
          businessId: business.id,
          categoryId: _selectedCategoryId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          salePrice: salePrice,
          costPrice: costPrice,
          stock: stock,
          minStock: minStock,
          barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
          trackStock: _trackStock,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        await repo.createProduct(newProduct);

        // Registrar movimiento inicial si hay stock
        if (stock > 0) {
          await StockMovementRepository(ref.read(productRepositoryProvider).db)
              .recordAdjustment(
            businessId: business.id,
            productId: newProduct.id,
            quantityChange: stock,
            stockAfter: stock,
            notes: 'Stock inicial',
            createdBy: 'owner',
          );
        }

        if (mounted) {
          _showSuccess('Producto creado');
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Eliminar (desactivar) producto
  // ---------------------------------------------------------------------------

  Future<void> _deactivate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desactivar producto'),
        content: const Text(
          'El producto no aparecerá en ventas ni en el inventario activo. '
          'Puedes reactivarlo más adelante.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(productRepositoryProvider).deactivateProduct(
            productId: widget.productId!,
            businessId: business.id,
            workerId: 'owner',
          );
      if (mounted) {
        _showSuccess('Producto desactivado');
        context.pop();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencySymbolProvider);
    final categoriesAsync = ref.watch(currentBusinessCategoriesProvider);

    // En modo edición, escuchar el stream del producto
    if (widget.isEditing) {
      final productAsync = ref.watch(productProvider(widget.productId!));
      productAsync.whenData((p) {
        if (p != null) _populateFields(p);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Producto' : 'Nuevo Producto'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Desactivar producto',
              onPressed: _isSaving ? null : _deactivate,
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Información básica ──────────────────────────────────
                  _SectionHeader(title: 'Información básica'),
                  const SizedBox(height: 12),

                  // Nombre
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto *',
                      prefixIcon: Icon(Icons.label_outline),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'El nombre es obligatorio';
                      if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Descripción
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  // Categoría
                  categoriesAsync.when(
                    data: (cats) => _CategoryDropdown(
                      categories: cats,
                      selectedId: _selectedCategoryId,
                      onChanged: (id) => setState(() => _selectedCategoryId = id),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error cargando categorías'),
                  ),
                  const SizedBox(height: 16),

                  // Código de barras
                  TextFormField(
                    controller: _barcodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código de barras (opcional)',
                      prefixIcon: Icon(Icons.qr_code_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),

                  const SizedBox(height: 24),

                  // ── Precios ─────────────────────────────────────────────
                  _SectionHeader(title: 'Precios ($currency)'),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _salePriceCtrl,
                          decoration: InputDecoration(
                            labelText: 'Precio de venta *',
                            prefixIcon: const Icon(Icons.sell_outlined),
                            prefixText: '$currency ',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            final d = double.tryParse(v.replaceAll(',', '.'));
                            if (d == null || d < 0) return 'Valor inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costPriceCtrl,
                          decoration: InputDecoration(
                            labelText: 'Costo *',
                            prefixIcon: const Icon(Icons.shopping_cart_outlined),
                            prefixText: '$currency ',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            final d = double.tryParse(v.replaceAll(',', '.'));
                            if (d == null || d < 0) return 'Valor inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  // Ganancia calculada en tiempo real
                  ValueListenableBuilder(
                    valueListenable: _salePriceCtrl,
                    builder: (_, __, ___) {
                      return ValueListenableBuilder(
                        valueListenable: _costPriceCtrl,
                        builder: (_, __, ___) {
                          final sale = double.tryParse(
                                  _salePriceCtrl.text.replaceAll(',', '.')) ??
                              0;
                          final cost = double.tryParse(
                                  _costPriceCtrl.text.replaceAll(',', '.')) ??
                              0;
                          final profit = sale - cost;
                          final margin = sale > 0 ? (profit / sale * 100) : 0.0;
                          final color = profit >= 0 ? Colors.green : Colors.red;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(children: [
                              const Icon(Icons.trending_up, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Ganancia: ${CurrencyFormatter.format(profit, currency)} '
                                '(${margin.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: color,
                                    fontWeight: FontWeight.w500),
                              ),
                            ]),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Stock ────────────────────────────────────────────────
                  _SectionHeader(title: 'Control de stock'),
                  const SizedBox(height: 12),

                  // Toggle de rastreo de stock
                  SwitchListTile.adaptive(
                    title: const Text('Rastrear stock'),
                    subtitle: const Text('Desactivar para productos de cantidad ilimitada'),
                    value: _trackStock,
                    onChanged: (v) => setState(() => _trackStock = v),
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (_trackStock) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Stock actual',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) {
                              if (!_trackStock) return null;
                              if (v == null || v.isEmpty) return 'Requerido';
                              if (int.tryParse(v) == null) return 'Número entero';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minStockCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Stock mínimo',
                              prefixIcon: Icon(Icons.warning_amber_outlined),
                              border: OutlineInputBorder(),
                              helperText: 'Alerta de stock bajo',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Estado activo/inactivo (solo en edición)
                  if (widget.isEditing) ...[
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      title: const Text('Producto activo'),
                      subtitle: const Text('Los productos inactivos no aparecen en ventas'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Botón guardar ────────────────────────────────────────
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(widget.isEditing ? 'Guardar cambios' : 'Crear producto'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: const InputDecoration(
        labelText: 'Categoría (opcional)',
        prefixIcon: Icon(Icons.category_outlined),
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Sin categoría')),
        ...categories.map(
          (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
