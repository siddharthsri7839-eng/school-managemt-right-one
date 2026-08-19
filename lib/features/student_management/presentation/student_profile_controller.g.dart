// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$studentProfileControllerHash() =>
    r'2fc8eb61fcfc11e7bd981bf3eff0896c1226a4c6';

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

abstract class _$StudentProfileController
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final int studentId;

  FutureOr<Map<String, dynamic>> build(
    int studentId,
  );
}

/// See also [StudentProfileController].
@ProviderFor(StudentProfileController)
const studentProfileControllerProvider = StudentProfileControllerFamily();

/// See also [StudentProfileController].
class StudentProfileControllerFamily
    extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [StudentProfileController].
  const StudentProfileControllerFamily();

  /// See also [StudentProfileController].
  StudentProfileControllerProvider call(
    int studentId,
  ) {
    return StudentProfileControllerProvider(
      studentId,
    );
  }

  @override
  StudentProfileControllerProvider getProviderOverride(
    covariant StudentProfileControllerProvider provider,
  ) {
    return call(
      provider.studentId,
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
  String? get name => r'studentProfileControllerProvider';
}

/// See also [StudentProfileController].
class StudentProfileControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<StudentProfileController,
        Map<String, dynamic>> {
  /// See also [StudentProfileController].
  StudentProfileControllerProvider(
    int studentId,
  ) : this._internal(
          () => StudentProfileController()..studentId = studentId,
          from: studentProfileControllerProvider,
          name: r'studentProfileControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$studentProfileControllerHash,
          dependencies: StudentProfileControllerFamily._dependencies,
          allTransitiveDependencies:
              StudentProfileControllerFamily._allTransitiveDependencies,
          studentId: studentId,
        );

  StudentProfileControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.studentId,
  }) : super.internal();

  final int studentId;

  @override
  FutureOr<Map<String, dynamic>> runNotifierBuild(
    covariant StudentProfileController notifier,
  ) {
    return notifier.build(
      studentId,
    );
  }

  @override
  Override overrideWith(StudentProfileController Function() create) {
    return ProviderOverride(
      origin: this,
      override: StudentProfileControllerProvider._internal(
        () => create()..studentId = studentId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        studentId: studentId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<StudentProfileController,
      Map<String, dynamic>> createElement() {
    return _StudentProfileControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StudentProfileControllerProvider &&
        other.studentId == studentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, studentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StudentProfileControllerRef
    on AutoDisposeAsyncNotifierProviderRef<Map<String, dynamic>> {
  /// The parameter `studentId` of this provider.
  int get studentId;
}

class _StudentProfileControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<StudentProfileController,
        Map<String, dynamic>> with StudentProfileControllerRef {
  _StudentProfileControllerProviderElement(super.provider);

  @override
  int get studentId => (origin as StudentProfileControllerProvider).studentId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
