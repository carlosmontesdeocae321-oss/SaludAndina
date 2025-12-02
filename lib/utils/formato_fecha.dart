String formatoFecha(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso);
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  } catch (_) {
    return iso;
  }
}

int calcularEdad(String iso) {
  if (iso.isEmpty) return 0;
  try {
    final nacimiento = DateTime.parse(iso);
    final ahora = DateTime.now();
    var edad = ahora.year - nacimiento.year;
    if (ahora.month < nacimiento.month ||
        (ahora.month == nacimiento.month && ahora.day < nacimiento.day)) {
      edad -= 1;
    }
    return edad;
  } catch (_) {
    return 0;
  }
}

String fechaConEdad(String iso) {
  if (iso.isEmpty) return 'No registrada';
  final f = formatoFecha(iso);
  final e = calcularEdad(iso);
  return e > 0 ? '$f ($e años)' : f;
}
