// lib/core/constants/app_strings.dart
// Todos los textos visibles al usuario en espanol.
// NUNCA hardcodear strings en la UI.

class AppStrings {
  // Generales
  static const String appName = 'POS Cuba';
  static const String appVersion = '1.0.0';
  static const String loading = 'Cargando...';
  static const String error = 'Error';
  static const String success = 'Exito';
  static const String cancel = 'Cancelar';
  static const String save = 'Guardar';
  static const String delete = 'Eliminar';
  static const String edit = 'Editar';
  static const String add = 'Agregar';
  static const String confirm = 'Confirmar';
  static const String close = 'Cerrar';
  static const String search = 'Buscar';
  static const String back = 'Atras';
  static const String next = 'Siguiente';
  static const String done = 'Hecho';
  static const String yes = 'Si';
  static const String no = 'No';

  // Navegacion
  static const String dashboard = 'Dashboard';
  static const String sales = 'Vender';
  static const String inventory = 'Inventario';
  static const String cashbox = 'Caja';
  static const String reports = 'Reportes';
  static const String settings = 'Configuracion';

  // Autenticacion
  static const String login = 'Iniciar Sesion';
  static const String register = 'Registrarse';
  static const String email = 'Correo Electronico';
  static const String password = 'Contrasena';
  static const String forgotPassword = 'Olvide mi Contrasena';
  static const String enterPin = 'Introduce tu PIN';
  static const String pin = 'PIN';
  static const String adminAccess = 'Acceso de Administrador';
  static const String workerAccess = 'Acceso de Trabajador';
  static const String logout = 'Cerrar Sesion';
  static const String invalidPin = 'PIN incorrecto';
  static const String pinRequired = 'El PIN es requerido';
  static const String pinLengthError = 'El PIN debe tener entre 4 y 6 digitos';

  // Dashboard
  static const String totalSalesToday = 'Total de Ventas de Hoy';
  static const String totalProfitToday = 'Ganancia Total de Hoy';
  static const String workerPayToday = 'Cobro del Trabajador (Hoy)';
  static const String totalTransfersToday = 'Total Transferencias (Hoy)';
  static const String transactionsToday = 'Transacciones de Hoy';
  static const String salesLast7Days = 'Ventas de los Ultimos 7 Dias';
  static const String cashboxStatus = 'Estado de la Caja';
  static const String cashboxOpen = 'Abierta';
  static const String cashboxClosed = 'Cerrada';

  // Ventas
  static const String cart = 'Carrito';
  static const String cartEmpty = 'El carrito esta vacio';
  static const String totalToPay = 'Total a Pagar';
  static const String finalizeSale = 'Finalizar Venta';
  static const String paymentMethod = 'Metodo de Pago';
  static const String cash = 'Efectivo';
  static const String transfer = 'Transferencia';
  static const String receipt = 'Recibo';
  static const String printReceipt = 'Imprimir Recibo';
  static const String saleSuccess = 'Venta finalizada exitosamente';
  static const String saleError = 'Error al procesar la venta';
  static const String stockInsufficient = 'Stock insuficiente';
  static const String productNotFound = 'Producto no encontrado';
  static const String cancelSale = 'Anular Venta';
  static const String cancelSaleConfirm = '¿Estas seguro de que quieres anular esta venta?';
  static const String saleCancelled = 'Venta anulada correctamente';
  static const String discount = 'Descuento';
  static const String applyDiscount = 'Aplicar Descuento';
  static const String subtotal = 'Subtotal';
  static const String quantity = 'Cantidad';
  static const String price = 'Precio';
  static const String product = 'Producto';

  // Inventario
  static const String products = 'Productos';
  static const String addProduct = 'Anadir Producto';
  static const String editProduct = 'Editar Producto';
  static const String productName = 'Nombre del Producto';
  static const String category = 'Categoria';
  static const String salePrice = 'Precio de Venta';
  static const String costPrice = 'Precio de Compra';
  static const String stock = 'Stock';
  static const String minStock = 'Stock Minimo';
  static const String barcode = 'Codigo de Barras';
  static const String productImage = 'Foto del Producto';
  static const String stockHistory = 'Historial de Movimientos';
  static const String lowStockAlert = 'Alerta: Stock bajo';
  static const String outOfStock = 'Sin stock';
  static const String importProducts = 'Importar Productos';
  static const String exportProducts = 'Exportar Productos';
  static const String deleteProductConfirm = '¿Eliminar este producto? Esta accion no se puede deshacer.';
  static const String categories = 'Categorias';
  static const String addCategory = 'Anadir Categoria';
  static const String categoryName = 'Nombre de la Categoria';

  // Caja
  static const String openCashbox = 'Abrir Caja';
  static const String closeCashbox = 'Cerrar Caja';
  static const String openingAmount = 'Monto Inicial';
  static const String closingAmount = 'Monto Final Contado';
  static const String expectedAmount = 'Monto Esperado';
  static const String difference = 'Diferencia';
  static const String cashMovements = 'Movimientos de Caja';
  static const String addMovement = 'Anadir Movimiento';
  static const String movementType = 'Tipo de Movimiento';
  static const String movementIn = 'Entrada';
  static const String movementOut = 'Salida';
  static const String movementDescription = 'Descripcion';
  static const String cashboxOpened = 'Caja abierta exitosamente';
  static const String cashboxClosed = 'Caja cerrada exitosamente';
  static const String cashboxRequired = 'Debes abrir la caja para procesar ventas en efectivo';
  static const String surplus = 'Sobrante';
  static const String shortage = 'Faltante';
  static const String balanceCorrect = 'Balance Correcto';

  // Reportes
  static const String dateRange = 'Rango de Fechas';
  static const String startDate = 'Fecha de Inicio';
  static const String endDate = 'Fecha de Fin';
  static const String filterByMethod = 'Filtrar por Metodo';
  static const String allMethods = 'Todos';
  static const String generateReport = 'Generar Reporte';
  static const String exportToCsv = 'Exportar a CSV';
  static const String salesByDay = 'Ventas por Dia';
  static const String salesByCategory = 'Ventas por Categoria';
  static const String topProducts = 'Productos Mas Vendidos';
  static const String saleDetails = 'Detalle de Ventas';
  static const String noData = 'No hay datos para mostrar';

  // Configuracion
  static const String workerSettings = 'Configuracion de Pago al Trabajador';
  static const String commissionPercentage = 'Porcentaje de Comision (%)';
  static const String fixedDailySalary = 'Salario Fijo Diario';
  static const String commissionType = 'Tipo de Comision';
  static const String percentage = 'Porcentaje';
  static const String fixed = 'Fijo';
  static const String changePin = 'Cambiar PIN';
  static const String currentPin = 'PIN Actual';
  static const String newPin = 'Nuevo PIN';
  static const String confirmNewPin = 'Confirmar Nuevo PIN';
  static const String pinChanged = 'PIN actualizado correctamente';
  static const String pinMismatch = 'Los PINs no coinciden';
  static const String backupRestore = 'Copia de Seguridad y Restauracion';
  static const String createBackup = 'Crear Copia de Seguridad';
  static const String restoreBackup = 'Restaurar Copia de Seguridad';
  static const String backupWarning = 'Esto reemplazara todos los datos actuales';
  static const String currencySettings = 'Configuracion de Moneda';
  static const String currencySymbol = 'Simbolo de Moneda';
  static const String darkMode = 'Modo Oscuro';
  static const String lightMode = 'Modo Claro';

  // Trabajadores
  static const String workers = 'Trabajadores';
  static const String addWorker = 'Anadir Trabajador';
  static const String editWorker = 'Editar Trabajador';
  static const String workerName = 'Nombre del Trabajador';
  static const String workerPin = 'PIN del Trabajador';
  static const String isActive = 'Activo';

  // Licencias
  static const String licenseStatus = 'Estado de Licencia';
  static const String licenseValid = 'Licencia Activa';
  static const String licenseTrial = 'Periodo de Prueba';
  static const String licenseExpired = 'Licencia Vencida';
  static const String licenseSuspended = 'Licencia Suspendida';
  static const String gracePeriod = 'Periodo de Gracia';
  static const String daysRemaining = 'dias restantes';
  static const String contactDeveloper = 'Contactar al Desarrollador';
  static const String renewLicense = 'Renovar Licencia';
  static const String licenseBlockedMessage = 'Tu licencia ha vencido. Contacta al desarrollador para renovar.';

  // Errores
  static const String genericError = 'Ha ocurrido un error. Intenta de nuevo.';
  static const String networkError = 'Error de conexion. Verifica tu internet.';
  static const String validationError = 'Por favor, verifica los datos ingresados.';
  static const String unauthorizedError = 'No tienes permiso para realizar esta accion.';
  static const String notFoundError = 'No se encontro el recurso solicitado.';
}
