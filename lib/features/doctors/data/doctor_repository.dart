import '../../../core/api/api_client.dart';
import 'availability.dart';
import 'doctor.dart';

/// The directory, as the screens need it.
///
/// An interface so a test can hand a screen a fixed list of doctors without a
/// server, and so the screens never learn what an HTTP status code is.
abstract interface class DoctorRepository {
  /// [specialtyField] is the rail's value — "Cardiology", not "Cardiologist".
  Future<List<Doctor>> list({String? specialtyField, String? query});

  /// The fields that actually have doctors in them, in the server's order.
  Future<List<String>> specialtyFields();

  Future<Doctor> byId(String id);

  Future<List<AvailabilityDay>> availability(
    String doctorId, {
    DateTime? from,
    int days = 7,
  });
}

class HttpDoctorRepository implements DoctorRepository {
  const HttpDoctorRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Doctor>> list({String? specialtyField, String? query}) async {
    final body = await _api.get(
      '/doctors',
      query: {
        if (specialtyField != null && specialtyField.isNotEmpty)
          'specialty': specialtyField,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'perPage': '50',
      },
      // The directory is browsable before signing in; sending the token when
      // we have one costs nothing and keeps one code path.
      authenticated: true,
    );

    final doctors = (body as Map<String, dynamic>?)?['doctors'];
    if (doctors is! List) return const [];
    return doctors
        .whereType<Map<String, dynamic>>()
        .map(Doctor.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<String>> specialtyFields() async {
    final body = await _api.get('/doctors/specialties');
    final entries = (body as Map<String, dynamic>?)?['specialties'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map((entry) => (entry['field'] ?? '') as String)
        .where((field) => field.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Doctor> byId(String id) async {
    final body = await _api.get('/doctors/$id');
    return Doctor.fromJson((body as Map<String, dynamic>?) ?? const {});
  }

  @override
  Future<List<AvailabilityDay>> availability(
    String doctorId, {
    DateTime? from,
    int days = 7,
  }) async {
    final body = await _api.get(
      '/doctors/$doctorId/availability',
      query: {
        if (from != null) 'from': from.toUtc().toIso8601String(),
        'days': '$days',
      },
    );

    final entries = (body as Map<String, dynamic>?)?['days'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(AvailabilityDay.fromJson)
        .toList(growable: false);
  }
}
