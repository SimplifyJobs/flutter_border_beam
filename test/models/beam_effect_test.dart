import 'package:flutter_border_beam/flutter_border_beam.dart';
import 'package:flutter_test/flutter_test.dart';

/// `BeamEffect` is the sealed "what the beam does" value: four effects in
/// two families, each carrying its own defaults, and the parameterised ones
/// compare by value so a rebuilt-inline effect never re-resolves a config.
void main() {
  const travelling = {'rotate', 'line'};
  const ambient = {'pulse', 'halo'};

  group('values', () {
    test('lists all four effects in gallery order', () {
      expect(BeamEffect.values.map((e) => e.name), [
        'rotate',
        'line',
        'pulse',
        'halo',
      ]);
    });

    test('every entry is a distinct effect with a distinct name', () {
      expect(BeamEffect.values.map((e) => e.name).toSet(), hasLength(4));
      expect(BeamEffect.values.map((e) => e.runtimeType).toSet(), hasLength(4));
      expect(BeamEffect.values.toSet(), hasLength(4));
    });

    test('carries each effect with its default parameters', () {
      expect(BeamEffect.values, contains(const BeamEffect.rotate()));
      expect(BeamEffect.values, contains(const BeamEffect.line()));
      expect(BeamEffect.values, contains(const BeamEffect.pulse()));
      expect(BeamEffect.values, contains(const BeamEffect.halo()));
    });
  });

  group('families', () {
    for (final effect in BeamEffect.values) {
      test('${effect.name} travels: ${travelling.contains(effect.name)}', () {
        expect(effect.travels, travelling.contains(effect.name));
        expect(effect.travels, isNot(ambient.contains(effect.name)));
      });
    }

    test('the two families partition the effects', () {
      expect({...travelling, ...ambient}, hasLength(4));
      expect(
        BeamEffect.values.where((e) => e.travels).map((e) => e.name).toSet(),
        travelling,
      );
    });

    test('parameters do not change the family', () {
      expect(const BeamEffect.rotate(count: 3, comet: true).travels, isTrue);
      expect(const BeamEffect.line(edge: BeamEdge.top).travels, isTrue);
    });
  });

  group('defaults', () {
    for (final effect in BeamEffect.values) {
      test('${effect.name}: cycle and hue period are positive', () {
        expect(effect.defaultCycle, greaterThan(Duration.zero));
        expect(effect.defaultHuePeriod, greaterThan(Duration.zero));
        expect(effect.defaultCycleGap, greaterThanOrEqualTo(Duration.zero));
      });
    }

    test('no effect rests between sweeps by default', () {
      for (final effect in BeamEffect.values) {
        expect(effect.defaultCycleGap, Duration.zero, reason: effect.name);
      }
    });

    test('parameters do not change the defaults', () {
      const a = BeamEffect.rotate();
      const b = BeamEffect.rotate(length: 2, count: 4, comet: true);
      expect(b.defaultCycle, a.defaultCycle);
      expect(b.defaultCycleGap, a.defaultCycleGap);
      expect(b.defaultHueMode, a.defaultHueMode);
      expect(b.defaultHuePeriod, a.defaultHuePeriod);
      const c = BeamEffect.line();
      const d = BeamEffect.line(edge: BeamEdge.left);
      expect(d.defaultCycle, c.defaultCycle);
      expect(d.defaultCycleGap, c.defaultCycleGap);
      expect(d.defaultHueMode, c.defaultHueMode);
      expect(d.defaultHuePeriod, c.defaultHuePeriod);
    });

    test('rotate defaults to one plain beam of unit length', () {
      const rotate = RotateEffect();
      expect(rotate.length, 1);
      expect(rotate.count, 1);
      expect(rotate.comet, isFalse);
    });

    test('line rides the bottom edge by default', () {
      expect(const LineEffect().edge, BeamEdge.bottom);
    });
  });

  group('equality', () {
    test('equal parameters are equal with equal hash codes', () {
      const pairs = <(BeamEffect, BeamEffect)>[
        (BeamEffect.rotate(), RotateEffect(length: 1, count: 1)),
        (
          BeamEffect.rotate(length: 1.5, count: 2, comet: true),
          RotateEffect(length: 1.5, count: 2, comet: true),
        ),
        (BeamEffect.line(edge: BeamEdge.left), LineEffect(edge: BeamEdge.left)),
        (BeamEffect.pulse(), PulseEffect()),
        (BeamEffect.halo(), HaloEffect()),
      ];
      for (final (a, b) in pairs) {
        expect(a, b);
        expect(a.hashCode, b.hashCode, reason: '$a');
      }
    });

    test('every parameter is part of the value', () {
      const base = BeamEffect.rotate();
      for (final other in const [
        BeamEffect.rotate(length: 2),
        BeamEffect.rotate(count: 2),
        BeamEffect.rotate(comet: true),
      ]) {
        expect(other, isNot(base), reason: '$other');
        expect(other.hashCode, isNot(base.hashCode), reason: '$other');
      }
      expect(
        const BeamEffect.line(edge: BeamEdge.top),
        isNot(const BeamEffect.line()),
      );
    });

    test('different effects are never equal', () {
      final effects = BeamEffect.values;
      for (var i = 0; i < effects.length; i++) {
        for (var j = 0; j < effects.length; j++) {
          if (i == j) continue;
          expect(effects[i], isNot(effects[j]));
        }
      }
    });
  });

  group('toString', () {
    test('names the effect and its parameters', () {
      expect(
        const BeamEffect.rotate(length: 1.5, count: 2, comet: true).toString(),
        'BeamEffect.rotate(length: 1.5, count: 2, comet: true)',
      );
      expect(
        const BeamEffect.line(edge: BeamEdge.top).toString(),
        'BeamEffect.line(edge: top)',
      );
    });

    test('a parameterless effect prints empty parentheses', () {
      for (final effect in const [BeamEffect.pulse(), BeamEffect.halo()]) {
        expect(effect.toString(), 'BeamEffect.${effect.name}()');
      }
    });
  });

  group('rotate asserts', () {
    // Runtime values, so the analyzer cannot fold the constructor into a
    // const evaluation and report the failing assert at compile time.
    final zero = double.parse('0');
    final negative = double.parse('-1');

    test('rejects a non-positive length', () {
      expect(() => RotateEffect(length: zero), throwsAssertionError);
      expect(() => RotateEffect(length: negative), throwsAssertionError);
    });

    test('rejects a count outside 1–4', () {
      expect(() => RotateEffect(count: int.parse('0')), throwsAssertionError);
      expect(() => RotateEffect(count: int.parse('5')), throwsAssertionError);
    });

    test('accepts the whole 1–4 count range', () {
      for (var count = 1; count <= 4; count++) {
        expect(RotateEffect(count: count).count, count);
      }
    });
  });
}
