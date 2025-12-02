import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BankTransferCard extends StatelessWidget {
  final String bankName;
  final String accountNumber;
  final String holder;

  const BankTransferCard({
    super.key,
    this.bankName = 'Banco del Pichincha',
    this.accountNumber = '2213835117',
    this.holder = 'Maryuri Soriano',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF0B6E4F), Color(0xFF36B37E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bankName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: accountNumber));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Número de cuenta copiado')));
                  },
                  icon: const Icon(Icons.copy, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    accountNumber,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace'),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: accountNumber));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Número de cuenta copiado')));
                  },
                  child: const Text('Copiar'),
                )
              ],
            ),
            const SizedBox(height: 6),
            Text('Titular: $holder',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
