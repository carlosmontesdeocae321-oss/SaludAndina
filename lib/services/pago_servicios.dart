import 'dart:io';
import 'package:http/http.dart' as http;
// No additional packages required for basic multipart upload

class PagoServicios {
  final String baseUrl;
  PagoServicios(this.baseUrl);

  Future<Map<String, dynamic>> solicitarPago(File imagen, int userId,
      {int? productoId, double? monto}) async {
    final uri = Uri.parse('$baseUrl/api/pagos/solicitar');
    final request = http.MultipartRequest('POST', uri);
    request.fields['userId'] = userId.toString();
    if (productoId != null) {
      request.fields['productoId'] = productoId.toString();
    }
    if (monto != null) request.fields['monto'] = monto.toString();

    request.files
        .add(await http.MultipartFile.fromPath('comprobante', imagen.path));

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return {'ok': true, 'body': resp.body};
    }
    return {'ok': false, 'status': resp.statusCode, 'body': resp.body};
  }
}
