import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/api_error.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/features/convert/conversion_controller.dart';
import 'package:tetri/features/transfer/transfer_controller.dart';

import '../helpers/fake_money_api.dart';

const timeout = ApiError(
  code: 'timeout',
  message: 'Retry',
  retryable: true,
  isTimeout: true,
  isTransport: true,
);
const inProgress = ApiError(
  code: 'request_in_progress',
  message: 'Retry',
  status: 409,
  retryable: true,
);
const expired = ApiError(
  code: 'quote_expired',
  message: 'Review again',
  status: 409,
);
const insufficient = ApiError(
  code: 'insufficient_funds',
  message: 'Enter less',
  status: 422,
);
const locked = ApiError(code: 'session_locked', message: 'Unlock first');

void main() {
  test(
    'send retries preserve exact body and key, and a new review gets a new key',
    () async {
      final api = FakeMoneyApi()..transferErrors.addAll([timeout, inProgress]);
      var key = 0;
      final delays = <Duration>[];
      final controller = TransferController(
        api,
        createKey: () => 'key-${++key}',
        delay: (duration) async => delays.add(duration),
      );
      addTearDown(controller.dispose);
      controller.openReview(FakeMoneyApi.nino, const Money(2500, 'GEL'));
      await controller.confirm();
      expect(api.transfers, hasLength(3));
      expect(api.transfers.map((request) => request.key).toSet(), {'key-1'});
      expect(api.transfers.map((request) => request.amount).toSet(), {
        const Money(2500, 'GEL'),
      });
      expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      expect(controller.receipt, isNotNull);
      await controller.confirm();
      expect(api.transfers, hasLength(3));
      controller.openReview(FakeMoneyApi.nino, const Money(2500, 'GEL'));
      await controller.confirm();
      expect(api.transfers.last.key, 'key-2');
    },
  );

  test('an unresolved send keeps its key for manual retry and prevents a new attempt', () async {
    final api = FakeMoneyApi()..transferErrors.addAll(List.filled(4, timeout));
    final controller = TransferController(
      api,
      createKey: () => 'same-key',
      delay: (_) async {},
    );
    addTearDown(controller.dispose);
    controller.openReview(FakeMoneyApi.nino, const Money(2500, 'GEL'));
    await controller.confirm();
    expect(controller.uncertain, isTrue);
    expect(api.transfers, hasLength(4));
    expect(
      () => controller.openReview(FakeMoneyApi.nino, const Money(5000, 'GEL')),
      throwsStateError,
    );
    await controller.confirm();
    expect(controller.receipt, isNotNull);
    expect(controller.uncertain, isFalse);
    expect(api.transfers.map((request) => request.key).toSet(), {'same-key'});
  });

  test('a final send rejection is not automatically retried', () async {
    final api = FakeMoneyApi()..transferErrors.add(insufficient);
    final controller = TransferController(api, delay: (_) async {});
    addTearDown(controller.dispose);
    controller.openReview(FakeMoneyApi.nino, const Money(2500, 'GEL'));
    final firstKey = controller.review!.idempotencyKey;
    await controller.confirm();
    expect(api.transfers, hasLength(1));
    expect(controller.uncertain, isFalse);
    controller.openReview(FakeMoneyApi.nino, const Money(1000, 'GEL'));
    expect(controller.review!.idempotencyKey, isNot(firstKey));
  });

  test('an unresolved send stops before retrying beyond24hours', () async {
    var now = DateTime.utc(2026, 11, 3);
    final api = FakeMoneyApi()..transferErrors.addAll(List.filled(4, timeout));
    final controller = TransferController(
      api,
      delay: (_) async {},
      now: () => now,
    );
    addTearDown(controller.dispose);
    controller.openReview(FakeMoneyApi.nino, const Money(2500, 'GEL'));
    await controller.confirm();
    now = now.add(const Duration(hours: 24));
    await controller.confirm();
    expect(api.transfers, hasLength(4));
    expect(controller.retryWindowExpired, isTrue);
    expect(controller.error!.code, 'confirmation_expired');
    expect(controller.uncertain, isTrue);
  });

  test('timeout then lock preserves send uncertainty and unlock retry reuses the key', () async {
    final api = FakeMoneyApi()..transferErrors.addAll([timeout, locked]);
    final controller = TransferController(
      api,
      createKey: () => 'held-key',
      delay: (_) async {},
    );
    addTearDown(controller.dispose);
    controller.openReview(FakeMoneyApi.nino, const Money(2500, 'GEL'));
    await controller.confirm();
    expect(controller.uncertain, isTrue);
    expect(controller.error!.code, 'session_locked');
    expect(
      () => controller.openReview(FakeMoneyApi.nino, const Money(5000, 'GEL')),
      throwsStateError,
    );
    await controller.confirm();
    expect(api.transfers.map((attempt) => attempt.key).toSet(), {'held-key'});
    expect(controller.receipt, isNotNull);
  });

  test(
    'automatic retries also recheck the24hour cutoff after a pause',
    () async {
      var now = DateTime.utc(2026, 11, 3);
      final api = FakeMoneyApi()..transferErrors.add(timeout);
      final controller = TransferController(
        api,
        delay: (_) async {
          now = now.add(const Duration(hours: 24));
        },
        now: () => now,
      );
      addTearDown(controller.dispose);
      controller.openReview(FakeMoneyApi.nino, const Money(2500, 'GEL'));
      await controller.confirm();
      expect(api.transfers, hasLength(1));
      expect(controller.retryWindowExpired, isTrue);
      expect(controller.uncertain, isTrue);
    },
  );

  test(
    'expired quote fetches fresh terms and waits for another confirmation',
    () async {
      final api = FakeMoneyApi()..conversionErrors.add(expired);
      var key = 0;
      final controller = ConversionController(
        api,
        createKey: () => 'key-${++key}',
        delay: (_) async {},
      );
      addTearDown(controller.dispose);
      controller.updateInput(const Money(1000, 'USD'), 'GEL');
      await controller.loadPreview();
      expect(controller.preview!.quoteId, 'quote-1');
      expect(await controller.openReview(), isTrue);
      expect(controller.review!.quoteId, 'quote-2');
      await controller.confirm();
      expect(api.conversions, [(key: 'key-1', quoteId: 'quote-2')]);
      expect(controller.review!.quoteId, 'quote-3');
      expect(controller.idempotencyKey, 'key-2');
      expect(controller.needsReview, isTrue);
      expect(controller.receipt, isNull);
      await controller.confirm();
      expect(api.conversions.last, (key: 'key-2', quoteId: 'quote-3'));
      expect(controller.receipt, isNotNull);
    },
  );

  test('conversion timeout retries the same quote and key', () async {
    final api = FakeMoneyApi()..conversionErrors.addAll([timeout, inProgress]);
    final controller = ConversionController(
      api,
      createKey: () => 'same-key',
      delay: (_) async {},
    );
    addTearDown(controller.dispose);
    controller.updateInput(const Money(1000, 'USD'), 'GEL');
    await controller.openReview();
    await controller.confirm();
    expect(api.conversions, hasLength(3));
    expect(api.conversions.toSet(), {(key: 'same-key', quoteId: 'quote-1')});
    expect(controller.receipt, isNotNull);
  });

  test('timeout then lock preserves conversion uncertainty and unlock retries original terms', () async {
    final api = FakeMoneyApi()..conversionErrors.addAll([timeout, locked]);
    final controller = ConversionController(
      api,
      createKey: () => 'held-key',
      delay: (_) async {},
    );
    addTearDown(controller.dispose);
    controller.updateInput(const Money(1000, 'USD'), 'GEL');
    await controller.openReview();
    await controller.confirm();
    expect(controller.uncertain, isTrue);
    expect(await controller.openReview(), isFalse);
    controller.updateInput(const Money(2000, 'USD'), 'EUR');
    expect(controller.review!.amountIn, const Money(1000, 'USD'));
    await controller.confirm();
    expect(api.conversions.toSet(), {(key: 'held-key', quoteId: 'quote-1')});
    expect(controller.receipt, isNotNull);
  });

  test('failed replacement quote never re-executes expired terms', () async {
    final api = FakeMoneyApi()..conversionErrors.add(expired);
    final controller = ConversionController(api, delay: (_) async {});
    addTearDown(controller.dispose);
    controller.updateInput(const Money(1000, 'USD'), 'GEL');
    await controller.openReview();
    api.quoteErrors.add(timeout);
    await controller.confirm();
    expect(controller.review, isNull);
    expect(controller.needsReview, isTrue);
    await controller.confirm();
    expect(api.conversions, hasLength(1));
    expect(await controller.openReview(), isTrue);
    expect(api.conversions, hasLength(1));
  });

  test('an unresolved conversion cannot be retried after24hours', () async {
    var now = DateTime.utc(2026, 11, 3);
    final api = FakeMoneyApi()
      ..conversionErrors.addAll(List.filled(4, timeout));
    final controller = ConversionController(
      api,
      delay: (_) async {},
      now: () => now,
    );
    addTearDown(controller.dispose);
    controller.updateInput(const Money(1000, 'USD'), 'GEL');
    await controller.openReview();
    await controller.confirm();
    now = now.add(const Duration(hours: 24));
    await controller.confirm();
    expect(api.conversions, hasLength(4));
    expect(controller.retryWindowExpired, isTrue);
    expect(controller.uncertain, isTrue);
  });

  testWidgets('quote preview waits300ms after the last edit', (tester) async {
    final api = FakeMoneyApi();
    final controller = ConversionController(api);
    addTearDown(controller.dispose);
    controller.updateInput(const Money(100, 'USD'), 'GEL');
    await tester.pump(const Duration(milliseconds: 200));
    controller.updateInput(const Money(200, 'USD'), 'GEL');
    await tester.pump(const Duration(milliseconds: 299));
    expect(api.quoteCalls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(api.quoteCalls, 1);
    expect(controller.preview!.amountIn, const Money(200, 'USD'));
  });
}
