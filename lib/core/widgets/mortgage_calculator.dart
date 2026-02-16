import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';

class MortgageCalculator extends StatefulWidget {
  const MortgageCalculator({super.key, required this.price});

  final double price;

  @override
  State<MortgageCalculator> createState() => _MortgageCalculatorState();
}

class _MortgageCalculatorState extends State<MortgageCalculator> {
  late double _downPayment;
  int _years = 20;
  double _rate = 18.0;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _downPayment = widget.price * 0.2;
  }

  String _fmt(double n) => n.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _expanded = true),
        icon: const Icon(Icons.calculate_outlined, size: 18),
        label: const Text('Рассчитать ипотеку'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
        ),
      );
    }

    final loanAmount = widget.price - _downPayment;
    final monthlyRate = _rate / 100 / 12;
    final months = _years * 12;
    final monthly = monthlyRate > 0
        ? (loanAmount * monthlyRate * math.pow(1 + monthlyRate, months)) /
            (math.pow(1 + monthlyRate, months) - 1)
        : loanAmount / months;
    final totalPaid = monthly * months;
    final overpayment = totalPaid - loanAmount;
    final percent = (_downPayment / widget.price * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Калькулятор ипотеки',
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.appColors.textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _expanded = false),
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Первый взнос: ${_fmt(_downPayment)} ₽ ($percent%)',
                style: TextStyle(fontSize: 12, color: context.appColors.textMuted)),
            Slider(
              value: _downPayment,
              min: 0,
              max: widget.price,
              divisions: 100,
              onChanged: (v) => setState(() => _downPayment = v),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Срок, лет', style: TextStyle(fontSize: 12, color: context.appColors.textMuted)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: _years.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0 && n <= 30) setState(() => _years = n);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ставка, %', style: TextStyle(fontSize: 12, color: context.appColors.textMuted)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: _rate.toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) {
                          final n = double.tryParse(v);
                          if (n != null && n > 0 && n <= 50) setState(() => _rate = n);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _row('Ежемесячный платёж', '${_fmt(monthly)} ₽',
                      bold: true, color: context.appColors.primary),
                  const SizedBox(height: 4),
                  _row('Сумма кредита', '${_fmt(loanAmount)} ₽'),
                  _row('Переплата', '${_fmt(overpayment)} ₽',
                      color: context.appColors.error),
                  _row('Итого выплат', '${_fmt(totalPaid)} ₽'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: context.appColors.textMuted)),
        Text(value,
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? context.appColors.textPrimary,
            )),
      ],
    );
  }
}
