// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_location_file.dart';

// **************************************************************************
// NpLogGenerator
// **************************************************************************

// ignore: non_constant_identifier_names
final _$logListLocationFileBloc =
    Logger("bloc.list_location_file.ListLocationFileBloc");

extension _$ListLocationFileBlocNpLog on ListLocationFileBloc {
  // ignore: unused_element
  Logger get _log => _$logListLocationFileBloc;
}

// **************************************************************************
// ToStringGenerator
// **************************************************************************

extension _$ListLocationFileBlocQueryToString on ListLocationFileBlocQuery {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "ListLocationFileBlocQuery {account: $account, place: $place, countryCode: $countryCode}";
  }
}

extension _$_ListLocationFileBlocExternalEventToString
    on _ListLocationFileBlocExternalEvent {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_ListLocationFileBlocExternalEvent {}";
  }
}

extension _$ListLocationFileBlocStateToString on ListLocationFileBlocState {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "${objectRuntimeType(this, "ListLocationFileBlocState")} {account: $account, items: [length: ${items.length}]}";
  }
}

extension _$ListLocationFileBlocFailureToString on ListLocationFileBlocFailure {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "ListLocationFileBlocFailure {account: $account, items: [length: ${items.length}], exception: $exception}";
  }
}