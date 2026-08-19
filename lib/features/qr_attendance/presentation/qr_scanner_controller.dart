/// The scan re-arm rule — the one part of the scanner that must not be improvised.
///
/// A QR/barcode held in front of a lens decodes 15–30×/second. A naive
/// "same code within N seconds" debounce that clears its key on reset produces an
/// infinite result → reset → re-decode loop (this bit the web kiosk on 2026-08-02).
///
/// The rule that actually works (plan §4.2): a code may only be *re-accepted* once it
/// has NOT been seen for a re-arm window (~1200 ms) — i.e. the card physically left
/// the frame — AND the per-person cooldown has elapsed. We therefore track *last
/// seen* (updated on EVERY decode, including ignored ones and while a result sheet is
/// up) separately from *last accepted*.
///
/// This class is pure and synchronous so it can be unit-tested by feeding a synthetic
/// 30 fps stream of the same code and asserting exactly one accept (plan §P4).
class ScanArmGate {
  final Duration rearmWindow;
  final Duration cooldown;

  final Map<String, DateTime> _lastSeen = {};
  final Map<String, DateTime> _lastAccept = {};

  ScanArmGate({
    this.rearmWindow = const Duration(milliseconds: 1200),
    required this.cooldown,
  });

  /// Offer a decoded [code] seen at [now]. Returns true exactly when it should be
  /// accepted. [active] is false while a result is on screen / the camera is paused;
  /// last-seen is still updated then, so a card held continuously through a result is
  /// treated as never having left and will not re-fire on resume.
  bool offer(String code, DateTime now, {required bool active}) {
    final previouslySeen = _lastSeen[code];
    final reArmed =
        previouslySeen == null || now.difference(previouslySeen) >= rearmWindow;

    // Always record the sighting, even when ignored.
    _lastSeen[code] = now;

    if (!active || !reArmed) return false;

    final lastAccept = _lastAccept[code];
    if (lastAccept != null && now.difference(lastAccept) < cooldown) {
      return false;
    }

    _lastAccept[code] = now;
    return true;
  }

  /// Forget a specific code's accept history (e.g. after an admin correction).
  void reset(String code) {
    _lastSeen.remove(code);
    _lastAccept.remove(code);
  }

  void clear() {
    _lastSeen.clear();
    _lastAccept.clear();
  }
}

/// Running tally shown on the scanner so the operator has continuous reassurance
/// ("42 IN · 5 OUT · 3 already done"), mirroring the web kiosk.
class ScanTally {
  int inCount = 0;
  int outCount = 0;
  int alreadyDone = 0;
  int rejected = 0;

  void record(String action) {
    switch (action) {
      case 'in':
        inCount++;
        break;
      case 'out':
        outCount++;
        break;
      case 'complete':
        alreadyDone++;
        break;
      default:
        rejected++;
    }
  }

  int get total => inCount + outCount + alreadyDone + rejected;
}
