// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marks_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$marksRepositoryHash() => r'6cad3af8dc906eef206418ddf93624b3b37d539f';

/// See also [marksRepository].
@ProviderFor(marksRepository)
final marksRepositoryProvider = AutoDisposeProvider<MarksRepository>.internal(
  marksRepository,
  name: r'marksRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$marksRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MarksRepositoryRef = AutoDisposeProviderRef<MarksRepository>;
String _$marksSelectionHash() => r'fbfa4a453b956adb29c3db101de9b5fdad466ef3';

/// See also [MarksSelection].
@ProviderFor(MarksSelection)
final marksSelectionProvider = AutoDisposeAsyncNotifierProvider<MarksSelection,
    Map<String, dynamic>>.internal(
  MarksSelection.new,
  name: r'marksSelectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$marksSelectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MarksSelection = AutoDisposeAsyncNotifier<Map<String, dynamic>>;
String _$marksEntryControllerHash() =>
    r'cd670677bb956260e68b8911d5217b54c51832c7';

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

abstract class _$MarksEntryController
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final int examId;
  late final int classId;
  late final int sectionId;

  FutureOr<Map<String, dynamic>> build({
    required int examId,
    required int classId,
    required int sectionId,
  });
}

/// See also [MarksEntryController].
@ProviderFor(MarksEntryController)
const marksEntryControllerProvider = MarksEntryControllerFamily();

/// See also [MarksEntryController].
class MarksEntryControllerFamily
    extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [MarksEntryController].
  const MarksEntryControllerFamily();

  /// See also [MarksEntryController].
  MarksEntryControllerProvider call({
    required int examId,
    required int classId,
    required int sectionId,
  }) {
    return MarksEntryControllerProvider(
      examId: examId,
      classId: classId,
      sectionId: sectionId,
    );
  }

  @override
  MarksEntryControllerProvider getProviderOverride(
    covariant MarksEntryControllerProvider provider,
  ) {
    return call(
      examId: provider.examId,
      classId: provider.classId,
      sectionId: provider.sectionId,
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
  String? get name => r'marksEntryControllerProvider';
}

/// See also [MarksEntryController].
class MarksEntryControllerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    MarksEntryController, Map<String, dynamic>> {
  /// See also [MarksEntryController].
  MarksEntryControllerProvider({
    required int examId,
    required int classId,
    required int sectionId,
  }) : this._internal(
          () => MarksEntryController()
            ..examId = examId
            ..classId = classId
            ..sectionId = sectionId,
          from: marksEntryControllerProvider,
          name: r'marksEntryControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$marksEntryControllerHash,
          dependencies: MarksEntryControllerFamily._dependencies,
          allTransitiveDependencies:
              MarksEntryControllerFamily._allTransitiveDependencies,
          examId: examId,
          classId: classId,
          sectionId: sectionId,
        );

  MarksEntryControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.examId,
    required this.classId,
    required this.sectionId,
  }) : super.internal();

  final int examId;
  final int classId;
  final int sectionId;

  @override
  FutureOr<Map<String, dynamic>> runNotifierBuild(
    covariant MarksEntryController notifier,
  ) {
    return notifier.build(
      examId: examId,
      classId: classId,
      sectionId: sectionId,
    );
  }

  @override
  Override overrideWith(MarksEntryController Function() create) {
    return ProviderOverride(
      origin: this,
      override: MarksEntryControllerProvider._internal(
        () => create()
          ..examId = examId
          ..classId = classId
          ..sectionId = sectionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        examId: examId,
        classId: classId,
        sectionId: sectionId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<MarksEntryController,
      Map<String, dynamic>> createElement() {
    return _MarksEntryControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MarksEntryControllerProvider &&
        other.examId == examId &&
        other.classId == classId &&
        other.sectionId == sectionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, examId.hashCode);
    hash = _SystemHash.combine(hash, classId.hashCode);
    hash = _SystemHash.combine(hash, sectionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MarksEntryControllerRef
    on AutoDisposeAsyncNotifierProviderRef<Map<String, dynamic>> {
  /// The parameter `examId` of this provider.
  int get examId;

  /// The parameter `classId` of this provider.
  int get classId;

  /// The parameter `sectionId` of this provider.
  int get sectionId;
}

class _MarksEntryControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<MarksEntryController,
        Map<String, dynamic>> with MarksEntryControllerRef {
  _MarksEntryControllerProviderElement(super.provider);

  @override
  int get examId => (origin as MarksEntryControllerProvider).examId;
  @override
  int get classId => (origin as MarksEntryControllerProvider).classId;
  @override
  int get sectionId => (origin as MarksEntryControllerProvider).sectionId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
