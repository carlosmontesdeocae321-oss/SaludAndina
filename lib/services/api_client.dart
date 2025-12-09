abstract class ApiClient {
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data);

  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula);

  Future<Map<String, dynamic>> subirDocumentosDoctor(
      int uid, List<String> attachments);

  Future<bool> crearHistorial(
      Map<String, String> fields, List<String> archivos);

  Future<bool> agendarCita(Map<String, dynamic> data);
}
