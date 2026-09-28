// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_session_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StudySessionViewModel)
final studySessionViewModelProvider = StudySessionViewModelProvider._();

final class StudySessionViewModelProvider
    extends $AsyncNotifierProvider<StudySessionViewModel, StudySessionState> {
  StudySessionViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studySessionViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studySessionViewModelHash();

  @$internal
  @override
  StudySessionViewModel create() => StudySessionViewModel();
}

String _$studySessionViewModelHash() =>
    r'b025d818ca73e0d05d72ff476ce41d324b37f2a4';

abstract class _$StudySessionViewModel
    extends $AsyncNotifier<StudySessionState> {
  FutureOr<StudySessionState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<StudySessionState>, StudySessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<StudySessionState>, StudySessionState>,
              AsyncValue<StudySessionState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
