abstract class ApiClient {
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data);

  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula);

  Future<bool> eliminarPaciente(String id);

  Future<Map<String, dynamic>> subirDocumentosDoctor(
      int uid, List<String> attachments);

  Future<bool> crearHistorial(
      Map<String, String> fields, List<String> archivos);

  Future<List<Map<String, dynamic>>> obtenerConsultasPacienteRaw(
      String pacienteId);

  Future<bool> eliminarHistorial(String id);

  Future<bool> agendarCita(Map<String, dynamic> data);
}
