import 'package:flutter/material.dart';

/// Inserta [text] en el controller en la posición actual del cursor.
void insertTextAtSelection(TextEditingController controller, String text) {
  final value = controller.value;
  final selection = value.selection;

  // Defensive: ensure selection indices are valid; if not, append at end
  int start = selection.start;
  int end = selection.end;
  final len = value.text.length;
  if (start < 0 || start > len) start = len;
  if (end < 0 || end > len) end = len;
  if (start > end) {
    final tmp = start;
    start = end;
    end = tmp;
  }

  final newText = value.text.replaceRange(start, end, text);
  final newSelection = TextSelection.collapsed(offset: start + text.length);
  controller.value = value.copyWith(text: newText, selection: newSelection, composing: TextRange.empty);
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
