import 'package:nc_photos/int_extension.dart';
import 'package:nc_photos/iterable_extension.dart';
import 'package:quiver/core.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  group("IterableExtension", () {
    test("withIndex", () {
      final src = [1, 4, 5, 2, 3];
      final result = src.withIndex().toList();
      expect(result[0], const Tuple2(0, 1));
      expect(result[1], const Tuple2(1, 4));
      expect(result[2], const Tuple2(2, 5));
      expect(result[3], const Tuple2(3, 2));
      expect(result[4], const Tuple2(4, 3));
    });

    test("containsIf", () {
      final src = [
        _ContainsIfTest(1),
        _ContainsIfTest(4),
        _ContainsIfTest(5),
        _ContainsIfTest(2),
        _ContainsIfTest(3),
      ];
      expect(src.containsIf(_ContainsIfTest(5), (a, b) => a.x == b.x), true);
    });

    group("distinct", () {
      test("primitive", () {
        expect([1, 2, 3, 4, 5, 3, 2, 4, 6].distinct(), [1, 2, 3, 4, 5, 6]);
      });

      test("class", () {
        expect(
            [
              _DistinctTest(1, 1),
              _DistinctTest(2, 2),
              _DistinctTest(3, 3),
              _DistinctTest(4, 4),
              _DistinctTest(5, 4),
              _DistinctTest(3, 6),
              _DistinctTest(2, 2),
              _DistinctTest(4, 8),
              _DistinctTest(6, 9),
            ].distinct(),
            [
              _DistinctTest(1, 1),
              _DistinctTest(2, 2),
              _DistinctTest(3, 3),
              _DistinctTest(4, 4),
              _DistinctTest(5, 4),
              _DistinctTest(3, 6),
              _DistinctTest(4, 8),
              _DistinctTest(6, 9),
            ]);
      });
    });

    test("distinctIf", () {
      expect(
          [
            _DistinctTest(1, 1),
            _DistinctTest(2, 2),
            _DistinctTest(3, 3),
            _DistinctTest(4, 4),
            _DistinctTest(5, 5),
            _DistinctTest(3, 6),
            _DistinctTest(2, 7),
            _DistinctTest(4, 8),
            _DistinctTest(6, 9),
          ].distinctIf((a, b) => a.x == b.x, (a) => a.x),
          [
            _DistinctTest(1, 1),
            _DistinctTest(2, 2),
            _DistinctTest(3, 3),
            _DistinctTest(4, 4),
            _DistinctTest(5, 5),
            _DistinctTest(6, 9),
          ]);
    });

    group("indexOf", () {
      test("start = 0", () {
        expect([1, 2, 3, 4, 5].indexOf(3), 2);
      });

      test("start > 0", () {
        expect([1, 2, 3, 4, 5].indexOf(3, 2), 2);
        expect([1, 2, 3, 4, 5].indexOf(3, 3), -1);
      });
    });

    test("withPartition", () async {
      expect(
        await 0.until(10).withPartition((sublist) => [sublist], 4),
        [
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9],
        ],
      );
    });
  });
}

class _ContainsIfTest {
  _ContainsIfTest(this.x);

  final int x;
}

class _DistinctTest {
  _DistinctTest(this.x, this.y);

  @override
  operator ==(Object other) =>
      other is _DistinctTest && x == other.x && y == other.y;

  @override
  get hashCode => hash2(x, y);

  @override
  toString() => "{x: $x, y: $y}";

  final int x;
  final int y;
}
