import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqpk_app/core/realtime/realtime_provider.dart';
import 'package:resqpk_app/core/realtime/socket_service.dart';
import 'package:resqpk_app/features/driver/screens/dispatch_request_screen.dart';
import 'package:resqpk_app/features/sos/data/models/dispatch_request_model.dart';

/// The offer screen has to close itself when the patient calls it off.
///
/// It used to sit there for the rest of its fifteen-second countdown, and a
/// driver who accepted in that window was told "another ambulance took it" —
/// the wrong reason for the right outcome.
class _FakeSocket extends SocketService {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get caseUpdateStream => _controller.stream;

  void send(Map<String, dynamic> event) => _controller.add(event);

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  final request = DispatchRequestModel.fromJson(const {
    'caseId': 'case-1',
    'caseNumber': 'RQ-1',
    'patientLat': 25.39,
    'patientLng': 68.36,
    'timeoutMs': 15000,
  });

  /// Shows the offer the way the duty screen does, and reports what it
  /// eventually popped with.
  Future<({List<String?> results, _FakeSocket socket})> showOffer(
    WidgetTester tester,
  ) async {
    final socket = _FakeSocket();
    final results = <String?>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [socketServiceProvider.overrideWithValue(socket)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final r = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => DispatchRequestScreen(request: request),
                      ),
                    );
                    results.add(r);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      tester.takeException();
    }
    return (results: results, socket: socket);
  }

  testWidgets('closes when the patient cancels this case', (tester) async {
    final (:results, :socket) = await showOffer(tester);
    expect(find.byType(DispatchRequestScreen), findsOneWidget);

    socket.send({'event': 'cancelled', 'caseId': 'case-1'});
    await tester.pumpAndSettle();

    expect(find.byType(DispatchRequestScreen), findsNothing,
        reason: 'the offer stayed up after the patient cancelled it');
    expect(results, ['cancelled'],
        reason: 'the duty screen needs the real reason, not a decline');
  });

  testWidgets('ignores a cancellation for a different case', (tester) async {
    final (:results, :socket) = await showOffer(tester);

    // A stale room, or a case this driver is not being offered, must not pull
    // a live offer off the screen.
    socket.send({'event': 'cancelled', 'caseId': 'some-other-case'});
    // Not pumpAndSettle: the countdown ticks every 100ms, so this screen never
    // settles while it is still up.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.byType(DispatchRequestScreen), findsOneWidget,
        reason: 'someone else cancelling closed this driver\'s offer');
    expect(results, isEmpty);
  });

  testWidgets('ignores other case events', (tester) async {
    final (:results, :socket) = await showOffer(tester);

    for (final event in ['hospital_accepted', 'quick_message', 'arrived']) {
      socket.send({'event': event, 'caseId': 'case-1'});
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.byType(DispatchRequestScreen), findsOneWidget);
    expect(results, isEmpty);
  });
}
