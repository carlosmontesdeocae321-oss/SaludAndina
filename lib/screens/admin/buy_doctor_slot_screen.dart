// Deprecated: use `BuyDoctorSlotDialog` (modal) instead of this full-screen
// `BuyDoctorSlotScreen`. Kept as a placeholder to avoid breaking imports
// in case some code still references it. Prefer removing this file
// after confirming the app builds and no references remain.

import 'package:flutter/material.dart';

class BuyDoctorSlotScreen extends StatelessWidget {
  const BuyDoctorSlotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprar slot (obsoleto)')),
      body: const Center(
          child:
              Text('Esta pantalla está obsoleta. Usa el diálogo de compra.')),
    );
  }
}
