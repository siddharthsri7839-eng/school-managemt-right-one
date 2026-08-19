// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$attendanceControllerHash() =>
    r'536e89b15ccbde0830275b2fe291fd448d95f307';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$AttendanceController
    extends BuildlessAutoDisposeAsyncNotifier<AttendanceState> {
  late final int sectionId;
  late final String date;

  FutureOr<AttendanceState> build(
    int sectionId,
    String date,
  );
}

/// See also [AttendanceController].
@ProviderFor(AttendanceController)
const attendanceControllerProvider = AttendanceControllerFamily();

/// See also [AttendanceController].
class AttendanceControllerFamily extends Family<AsyncValue<AttendanceState>> {
  /// See also [AttendanceController].
  const AttendanceControllerFamily();

  /// See also [AttendanceController].
  AttendanceControllerProvider call(
    int sectionId,
    String date,
  ) {
    return AttendanceControllerProvider(
      sectionId,
      date,
    );
  }

  @override
  AttendanceControllerProvider getProviderOverride(
    covariant AttendanceControllerProvider provider,
  ) {
    return call(
      provider.sectionId,
      provider.date,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'attendanceControllerProvider';
}

/// See also [AttendanceController].
class AttendanceControllerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    AttendanceController, AttendanceState> {
  /// See also [AttendanceController].
  AttendanceControllerProvider(
    int sectionId,
    String date,
  ) : this._internal(
          () => AttendanceController()
            ..sectionId = sectionId
            ..date = date,
          from: attendanceControllerProvider,
          name: r'attendanceControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$attendanceControllerHash,
          dependencies: AttendanceControllerFamily._dependencies,
          allTransitiveDependencies:
              AttendanceControllerFamily._allTransitiveDependencies,
          sectionId: sectionId,
          date: date,
        );

  AttendanceControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sectionId,
    required this.date,
  }) : super.internal();

  final int sectionId;
  final String date;

  @override
  FutureOr<AttendanceState> runNotifierBuild(
    covariant AttendanceController notifier,
  ) {
    return notifier.build(
      sectionId,
      date,
    );
  }

  @override
  Override overrideWith(AttendanceController Function() create) {
    return ProviderOverride(
      origin: this,
      override: AttendanceControllerProvider._internal(
        () => create()
          ..sectionId = sectionId
          ..date = date,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sectionId: sectionId,
        date: date,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<AttendanceController, AttendanceState>
      createElement() {
    return _AttendanceControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AttendanceControllerProvider &&
        other.sectionId == sectionId &&
        other.date == date;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sectionId.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AttendanceControllerRef
    on AutoDisposeAsyncNotifierProviderRef<AttendanceState> {
  /// The parameter `sectionId` of this provider.
  int get sectionId;

  /// The parameter `date` of this provider.
  String get date;
}

class _AttendanceControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<AttendanceController,
        AttendanceState> with AttendanceControllerRef {
  _AttendanceControllerProviderElement(super.provider);

  @override
  int get sectionId => (origin as AttendanceControllerProvider).sectionId;
  @override
  String get date => (origin as AttendanceControllerProvider).date;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
