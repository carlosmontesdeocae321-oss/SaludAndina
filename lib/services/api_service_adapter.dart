import 'api_client.dart';
import 'api_services.dart';

class ApiServiceAdapter implements ApiClient {
  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async {
    return await ApiService.crearPaciente(data);
  }

  @override
  Future<bool> crearHistorial(
      Map<String, String> fields, List<String> archivos) async {
    return await ApiService.crearHistorial(fields, archivos);
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerConsultasPacienteRaw(
      String pacienteId) async {
    return await ApiService.obtenerConsultasPacienteRaw(pacienteId);
  }

  @override
  Future<bool> eliminarHistorial(String id) async {
    return await ApiService.eliminarHistorial(id);
  }

  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async {
    return await ApiService.agendarCita(data);
  }

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async {
    return await ApiService.buscarPacientePorCedula(cedula);
  }

  @override
  Future<bool> eliminarPaciente(String id) async {
    return await ApiService.eliminarPaciente(id);
  }

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
      int uid, List<String> attachments) async {
    return await ApiService.subirDocumentosDoctor(uid, attachments);
  }
}
