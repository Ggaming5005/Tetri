import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/app/preferences.dart';
import 'package:tetri/core/api.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/providers.dart';
import 'package:tetri/core/session.dart';
import 'package:tetri/design/theme.dart';

const sampleUser = AuthUser(
  id: 'user-1',
  email: 'nino@example.test',
  displayName: 'Nino K.',
  handle: '@nino',
);
const sampleAccounts = [
  MoneyAccount(id: 'gel', balance: Money(100000, 'GEL')),
  MoneyAccount(id: 'usd', balance: Money(30000, 'USD')),
  MoneyAccount(id: 'eur', balance: Money(30000, 'EUR')),
];
final sampleRates = FxRates(
  spread: '0.005',
  rates: [
    FxRate(currency: 'USD', rateToGel: '2.7', rateDate: DateTime(2024, 1, 2)),
    FxRate(currency: 'EUR', rateToGel: '3.0', rateDate: DateTime(2024, 1, 2)),
  ],
);

TransactionView sampleTransaction(
  String id, {
  int minor = -2500,
  String currency = 'GEL',
  String kind = 'transfer',
}) => TransactionView(
  id: id,
  kind: kind,
  status: 'posted',
  description: 'Lunch',
  createdAt: DateTime(2024, 1, 2, 12),
  entries: [
    EntryView(
      accountId: currency.toLowerCase(),
      amount: Money(minor, currency),
    ),
  ],
  counterparty: const RecipientView(
    displayName: 'Giorgi M.',
    handle: '@giorgi',
  ),
);

typedef HistoryHandler = Future<TransactionPage> Function({
  String? accountId,
  required String filter,
  String? cursor,
  required int pageSize,
});

class FakeBankApi extends BankApi {
  FakeBankApi() : super(Dio());
  Future<AuthUser> Function() profileHandler = () async => sampleUser;
  Future<List<MoneyAccount>> Function() accountsHandler = () async =>
      sampleAccounts;
  Future<FxRates> Function() ratesHandler = () async => sampleRates;
  Future<TransactionView> Function(String) transactionHandler = (id) async =>
      sampleTransaction(id);
  HistoryHandler historyHandler = ({
    accountId,
    required filter,
    cursor,
    required pageSize,
  }) async => const TransactionPage(items: []);
  final List<({String? accountId, String filter, String? cursor, int pageSize})>
  historyCalls = [];
  @override
  Future<AuthUser> profile() => profileHandler();
  @override
  Future<List<MoneyAccount>> accounts() => accountsHandler();
  @override
  Future<FxRates> rates() => ratesHandler();
  @override
  Future<TransactionView> transaction(String id) => transactionHandler(id);
  @override
  Future<TransactionPage> transactions({
    String? accountId,
    String filter = 'all',
    String? cursor,
    int pageSize = 20,
  }) {
    historyCalls.add((
      accountId: accountId,
      filter: filter,
      cursor: cursor,
      pageSize: pageSize,
    ));
    return historyHandler(
      accountId: accountId,
      filter: filter,
      cursor: cursor,
      pageSize: pageSize,
    );
  }
}

Future<void> pumpBanking(
  WidgetTester tester,
  Widget screen,
  FakeBankApi api, {
  Brightness brightness = Brightness.light,
  Size size = const Size(360, 800),
  TextScaler textScaler = TextScaler.noScaling,
  SessionController? session,
  ValueNotifier<ThemeMode>? themePreference,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (context, state) => screen),
      for (final route in [
        '/home',
        '/payments',
        '/activity',
        '/settings',
        '/change-pin',
        '/pin-setup',
        '/send',
        '/convert',
        '/accounts/:id',
        '/transactions/:id',
      ])
        GoRoute(
          path: route,
          builder: (context, state) =>
              Scaffold(body: Text(state.uri.toString())),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bankApiProvider.overrideWithValue(api),
        if (session != null) sessionProvider.overrideWithValue(session),
        if (themePreference != null)
          themeModeProvider.overrideWithValue(themePreference),
      ],
      child: MaterialApp.router(
        theme: brightness == Brightness.dark
            ? TetriTheme.dark
            : TetriTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: true, textScaler: textScaler),
          child: RepaintBoundary(
            key: const ValueKey('banking-screen'),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
