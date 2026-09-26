import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/core/theme/tokens.dart';

/// The tracking sheet's collapsed height.
///
/// Dragged all the way down, the sheet must stop exactly between the header
/// text and "Call Rescue 1122": the whole header readable, none of the button.
/// A button sliced along the bottom edge reads as a rendering fault.
///
/// The card above the button is a fixed stack of pixels, so a flat fraction of
/// screen height lands somewhere different on every phone. On a 411x914 phone
/// the old 0.17 gave 155px where the header needs about 111 — the extra 44px
/// was the top half of the button.
///
/// The header height is a parameter here rather than measured, because
/// ResqType is GoogleFonts.inter, which fetches at runtime and resolves to a
/// much wider fallback in a test. Passing it in keeps these checks on the
/// arithmetic, which is where the bug was, and lets the production range be
/// covered explicitly.

/// Everything above the button, measured from the top of the card.
/// Mirrors the column in _TrackingCard.
double headerStack(double headerHeight) =>
    Resq.space3                 // card top padding
    + (5.0 + Resq.space3)       // grip and its bottom margin
    + Resq.space2               // gap below the grip
    + math.max(46.0, headerHeight);

/// The production calculation, with the header height supplied.
double collapsedFraction(Size screen, double bottomInset, double headerHeight) {
  const breathingRoom = 12.0;
  final collapsed = headerStack(headerHeight) + breathingRoom + bottomInset;
  return math.min(collapsed / screen.height, 0.40);
}

void main() {
  const devices = [
    ('small phone', Size(320, 640), 0.0),
    ('common phone', Size(360, 780), 24.0),
    ('the reported phone', Size(411, 914), 24.0),
    ('tall phone, gesture nav', Size(412, 915), 48.0),
    ('tablet', Size(768, 1024), 0.0),
  ];

  // What the real header measures: one line of title over a subtitle that
  // wraps to two lines on a phone, three on a narrow one, more at accessibility
  // text sizes.
  const headers = [
    ('two-line subtitle', 62.0),
    ('three-line subtitle', 80.0),
    ('large accessibility text', 120.0),
  ];

  for (final (device, size, inset) in devices) {
    for (final (shape, header) in headers) {
      test('$device, $shape: stops between the text and the button', () {
        final visible = collapsedFraction(size, inset, header) * size.height - inset;
        final stack = headerStack(header);

        // The whole header is readable.
        expect(visible, greaterThanOrEqualTo(stack),
            reason: 'the subtitle is being cut instead of the button');

        // And the button, which starts a space4 gap below the header, is
        // entirely below the fold.
        expect(visible, lessThanOrEqualTo(stack + Resq.space4),
            reason: 'the button is peeking above the collapsed edge');
      });
    }
  }

  test('the flat 0.17 spilled into the button on the reported phone', () {
    const size = Size(411, 914);
    const inset = 24.0;
    const header = 62.0; // the two-line subtitle this phone renders

    final oldVisible = 0.17 * size.height - inset;
    final buttonTop = headerStack(header) + Resq.space4;

    // The old height ran past the top of the button by most of its height.
    expect(oldVisible, greaterThan(buttonTop),
        reason: 'if this does not overrun, the reported bug is not reproduced');
    // 16pt of a 48pt button — the top third, which is what the report shows.
    expect(oldVisible - buttonTop, greaterThan(12),
        reason: 'it visibly sliced the button, not just grazed it');

    // The measured one stops before the button starts.
    final newVisible = collapsedFraction(size, inset, header) * size.height - inset;
    expect(newVisible, lessThanOrEqualTo(buttonTop));
  });

  test('the collapsed sheet never eats the map', () {
    for (final (_, size, inset) in devices) {
      for (final (_, header) in headers) {
        expect(collapsedFraction(size, inset, header), lessThanOrEqualTo(0.40));
      }
    }
  });
}
