// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_sharee.dart';

// **************************************************************************
// NpLogGenerator
// **************************************************************************

extension _$ListShareeBlocNpLog on ListShareeBloc {
  // ignore: unused_element
  Logger get _log => log;

  static final log = Logger("bloc.list_sharee.ListShareeBloc");
}

// **************************************************************************
// ToStringGenerator
// **************************************************************************

extension _$ListShareeBlocQueryToString on ListShareeBlocQuery {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "ListShareeBlocQuery {account: $account}";
  }
}

extension _$ListShareeBlocStateToString on ListShareeBlocState {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "${objectRuntimeType(this, "ListShareeBlocState")} {account: $account, items: [length: ${items.length}]}";
  }
}

extension _$ListShareeBlocFailureToString on ListShareeBlocFailure {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "ListShareeBlocFailure {account: $account, items: [length: ${items.length}], exception: $exception}";
  }
}
