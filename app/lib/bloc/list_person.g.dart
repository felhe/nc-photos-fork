// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_person.dart';

// **************************************************************************
// NpLogGenerator
// **************************************************************************

extension _$ListPersonBlocNpLog on ListPersonBloc {
  // ignore: unused_element
  Logger get _log => log;

  static final log = Logger("bloc.list_person.ListPersonBloc");
}

// **************************************************************************
// ToStringGenerator
// **************************************************************************

extension _$ListPersonBlocQueryToString on ListPersonBlocQuery {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "ListPersonBlocQuery {account: $account}";
  }
}

extension _$ListPersonBlocStateToString on ListPersonBlocState {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "${objectRuntimeType(this, "ListPersonBlocState")} {account: $account, items: [length: ${items.length}]}";
  }
}

extension _$ListPersonBlocFailureToString on ListPersonBlocFailure {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "ListPersonBlocFailure {account: $account, items: [length: ${items.length}], exception: $exception}";
  }
}
