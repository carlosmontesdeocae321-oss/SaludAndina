import 'package:flutter/material.dart';

/// Inserta [text] en el controller en la posición actual del cursor.
void insertTextAtSelection(TextEditingController controller, String text) {
  final value = controller.value;
  final selection = value.selection;
  final newText = value.text.replaceRange(selection.start, selection.end, text);
  final newSelection =
      TextSelection.collapsed(offset: selection.start + text.length);
  controller.value = value.copyWith(text: newText, selection: newSelection);
}

/// Calcula una representación ordinal simple en español para números pequeños.
String calcularOrdinalFromInt(int n) {
  if (n <= 0) return '';
  const ordinales = [
    '',
    'PRIMER',
    'SEGUNDO',
    'TERCERO',
    'CUARTO',
    'QUINTO',
    'SEXTO',
    'SÉPTIMO',
    'OCTAVO',
    'NOVENO',
    'DÉCIMO',
    'UNDÉCIMO',
    'DUODÉCIMO'
  ];
  if (n > 0 && n < ordinales.length) return ordinales[n];
  return n.toString();
}
