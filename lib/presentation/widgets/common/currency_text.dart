// lib/presentation/widgets/common/currency_text.dart
// Texto formateado con moneda.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/business_provider.dart';

/// Widget que muestra un monto formateado con la moneda del negocio.
class CurrencyText extends ConsumerWidget {
  final double amount;
  final TextStyle? style;
  final bool compact;

  const CurrencyText({
    super.key,
    required this.amount,
    this.style,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencySymbolProvider);
    final formatted = compact
        ? CurrencyFormatter.formatCompact(amount, currency)
        : CurrencyFormatter.format(amount, currency);

    return Text(
      formatted,
      style: style,
    );
  }
}
