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
    final cs = Theme.of(context).colorScheme;
    // Use a Wrap so buttons compact and flow to new lines based on available width.
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: macros.keys.map((key) {
        final label = key;
        final macroText = macros[key] ?? '';
        // Render as a pill-like chip: subtle filled background + colored text and border
        final chipBg = cs.secondary.withOpacity(0.14);
        final chipFg = cs.secondary;
        return TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            backgroundColor: chipBg,
            foregroundColor: chipFg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: cs.secondary.withOpacity(0.36)),
            ),
          ),
          onPressed: () => onInsert(macroText),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, color: chipFg, fontWeight: FontWeight.w600)),
        );
      }).toList(),
    );
  }
}
