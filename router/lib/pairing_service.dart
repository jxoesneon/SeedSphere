import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

/// Represents a pairing session between a Gardener and a Seedling.
class PairingSession {
  final String id;
  final String pin;
  final DateTime createdAt;
  String? gardenerId;
  String? seedlingId;
  bool isComplete;

  PairingSession({
    required this.id,
    required this.pin,
    required this.createdAt,
    this.gardenerId,
    this.seedlingId,
    this.isComplete = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'pin': pin,
    'createdAt': createdAt.toIso8601String(),
    'gardenerId': gardenerId,
    'seedlingId': seedlingId,
    'isComplete': isComplete,
  };
}

/// Service managing device pairing sessions with feature parity to legacy server.
class PairingService {
  final Map<String, PairingSession> _sessions = {};
  final _uuid = const Uuid();

  /// Creates a new pairing session and returns the PIN.
  Future<String> createSession(String seedlingId) async {
    final id = _uuid.v4();
    final pin = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
        .toString();

    final session = PairingSession(
      id: id,
      pin: pin,
      createdAt: DateTime.now(),
      seedlingId: seedlingId,
    );

    _sessions[pin] = session;

    // Auto-expire after 5 minutes
    Timer(const Duration(minutes: 5), () {
      _sessions.remove(pin);
    });

    return pin;
  }

  /// Completes a pairing session using a PIN and Gardener identity.
  Future<PairingSession?> completePairing(String pin, String gardenerId) async {
    final session = _sessions[pin];
    if (session == null) return null;

    session.gardenerId = gardenerId;
    session.isComplete = true;

    return session;
  }

  /// Retrieves a session status by pin.
  PairingSession? getSession(String pin) => _sessions[pin];
}
