import '../../../core/api/api_client.dart';
import '../../appointments/data/appointment.dart';
import 'doctor.dart';

/// The signed-in patient's own things: the doctors they saved, and the
/// appointments they booked.
///
/// Separate from [DoctorRepository] because everything here needs a session
/// and nothing there does — which is exactly the line `requireAuth` draws on
/// the server.
abstract interface class PatientRepository {
  /// The saved doctors, whole.
  ///
  /// `/me/favourites` populates them, so the screen that lists them and the
  /// screen that only needs to know which hearts are filled make the same one
  /// request — there is no lighter call to make.
  Future<List<Doctor>> favourites();

  /// Saves or unsaves in one call, because the heart is one control.
  Future<void> setFavourite(String doctorId, {required bool saved});

  Future<void> book({
    required String doctorId,
    required DateTime startsAt,
    String? reason,
  });

  /// The patient's own appointments, filtered the way the screen asks.
  Future<List<Appointment>> appointments(AppointmentFilter filter);

  /// Gives the slot back. The server frees it for everyone else at the same
  /// time — the unique index that stops double booking is partial on
  /// `status: 'booked'`, so cancelling reopens the time rather than burning it.
  Future<void> cancelAppointment(String id);
}

class HttpPatientRepository implements PatientRepository {
  const HttpPatientRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Doctor>> favourites() async {
    final body = await _api.get('/me/favourites');
    final doctors = (body as Map<String, dynamic>?)?['doctors'];
    if (doctors is! List) return const [];
    return doctors
        .whereType<Map<String, dynamic>>()
        .map(Doctor.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> setFavourite(String doctorId, {required bool saved}) async {
    if (saved) {
      await _api.put('/me/favourites/$doctorId');
    } else {
      await _api.delete('/me/favourites/$doctorId');
    }
  }

  @override
  Future<void> book({
    required String doctorId,
    required DateTime startsAt,
    String? reason,
  }) async {
    await _api.post('/appointments', body: {
      'doctorId': doctorId,
      'startsAt': startsAt.toUtc().toIso8601String(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  @override
  Future<List<Appointment>> appointments(AppointmentFilter filter) async {
    final body = await _api.get('/appointments', query: {
      'status': filter.status,
      'when': filter.when,
    });

    final entries = (body as Map<String, dynamic>?)?['appointments'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(Appointment.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> cancelAppointment(String id) async {
    await _api.post('/appointments/$id/cancel');
  }
}
