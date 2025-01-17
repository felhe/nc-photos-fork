import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/entity/share.dart';
import 'package:nc_photos/entity/share/data_source.dart';
import 'package:np_codegen/np_codegen.dart';
import 'package:to_string/to_string.dart';

part 'list_share.g.dart';

abstract class ListShareBlocEvent {
  const ListShareBlocEvent();
}

@toString
class ListShareBlocQuery extends ListShareBlocEvent {
  const ListShareBlocQuery(this.account, this.file);

  @override
  String toString() => _$toString();

  final Account account;
  final File file;
}

@toString
abstract class ListShareBlocState {
  const ListShareBlocState(this.account, this.file, this.items);

  @override
  String toString() => _$toString();

  final Account? account;
  final File file;
  final List<Share> items;
}

class ListShareBlocInit extends ListShareBlocState {
  ListShareBlocInit() : super(null, File(path: ""), const []);
}

class ListShareBlocLoading extends ListShareBlocState {
  const ListShareBlocLoading(Account? account, File file, List<Share> items)
      : super(account, file, items);
}

class ListShareBlocSuccess extends ListShareBlocState {
  const ListShareBlocSuccess(Account? account, File file, List<Share> items)
      : super(account, file, items);
}

@toString
class ListShareBlocFailure extends ListShareBlocState {
  const ListShareBlocFailure(
      Account? account, File file, List<Share> items, this.exception)
      : super(account, file, items);

  @override
  String toString() => _$toString();

  final dynamic exception;
}

/// List all shares from a given file
@npLog
class ListShareBloc extends Bloc<ListShareBlocEvent, ListShareBlocState> {
  ListShareBloc() : super(ListShareBlocInit()) {
    on<ListShareBlocEvent>(_onEvent);
  }

  Future<void> _onEvent(
      ListShareBlocEvent event, Emitter<ListShareBlocState> emit) async {
    _log.info("[_onEvent] $event");
    if (event is ListShareBlocQuery) {
      await _onEventQuery(event, emit);
    }
  }

  Future<void> _onEventQuery(
      ListShareBlocQuery ev, Emitter<ListShareBlocState> emit) async {
    try {
      emit(ListShareBlocLoading(ev.account, ev.file, state.items));
      emit(ListShareBlocSuccess(ev.account, ev.file, await _query(ev)));
    } catch (e, stackTrace) {
      _log.severe("[_onEventQuery] Exception while request", e, stackTrace);
      emit(ListShareBlocFailure(ev.account, ev.file, state.items, e));
    }
  }

  Future<List<Share>> _query(ListShareBlocQuery ev) {
    final shareRepo = ShareRepo(ShareRemoteDataSource());
    return shareRepo.list(ev.account, ev.file);
  }
}
