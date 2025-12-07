import 'package:flutter/material.dart';

class MacroBar extends StatelessWidget {
  final Map<String, String> macros;
  final void Function(String) onInsert;
  // optional map of field label -> insert function (receives macro text)
  final Map<String, void Function(String)>? fieldInsertors;

  const MacroBar({
    super.key,
    required this.macros,
    required this.onInsert,
    this.fieldInsertors,
  });

  @override
  Widget build(BuildContext context) {
    // Use a Wrap so buttons compact and flow to new lines based on available width.
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: macros.keys.map((key) {
        final label = key;
        final macroText = macros[key] ?? '';
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => onInsert(macroText),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    );
  }
}
