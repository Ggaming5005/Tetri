# Mobile design review — 3 November 2026

The user requested native amount entry, layouts that fit different devices, banking-oriented navigation and properly centered payment results. They also supplied BOG, TBC Business and banking concept screenshots. These references guide hierarchy and interaction; Tetri retains its own name, palette, copy and assets.

## Reference research

- [BOG mobile banking](https://bankofgeorgia.ge/ka/retail/mobile-bank): its official dashboard artwork groups a prominent account balance, carousel indicators and compact money actions. This informed Tetri's account indicators and actions that follow the visible account currency.
- [BOG App Store listing](https://apps.apple.com/ge/app/bank-of-georgia/id1159368231): the screenshots show compact utility headers and distinct overview and transfer sections. Tetri uses Home, Payments and Activity as primary destinations, with profile/settings in the header.
- [TBC Business Google Play listing](https://play.google.com/store/apps/details?id=ge.tbc.msme): the screenshots place the total above readable account rows with consistent amount alignment. Tetri keeps supporting metadata quiet and gives long transaction amounts more space.
- [Hashbank Google Play listing](https://play.google.com/store/apps/details?id=com.hashbank): the transfer/conversion screenshots show paired source and destination amounts, nearby rates and fees, and a primary action above the native keyboard. Tetri uses compact account panels and the device's decimal keyboard, retaining explicit server-quoted review terms.

These are observations from official published screenshots, not hands-on verification of every bank flow. The user's concept examples also include cards, loans, offers and other features outside Tetri's scope; those are not added.

## Tetri decisions

- One compact header pattern across the three main destinations; profile is a 48-point target. Settings and money flows use back navigation.
- Balance, account pager, position indicators and quick actions form one overview. An unavailable exchange-rate total uses a compact retry message, keeping actual account balances and actions accessible. This failure treatment is a Tetri decision rather than a claimed bank behavior.
- Send and Convert use exact decimal text with the native keyboard. Input accepts dot/comma separators and rejects extra decimals and signed-64-bit overflow without converting money through floating point.
- Continue sits above the keyboard. Short landscape viewports scroll the action into view; panels stack their headers when enlarged text needs space. Tablet content is centered within a readable maximum width.
- Results use the bounded safe viewport: the icon, title, amount and recipient form a centered group; Done sits at the bottom. Small/large-text layouts scroll. Unresolved payments show a neutral waiting state, while definitive failures use the error treatment.
- Review remains explicit, and retries preserve the same idempotency key. Layout changes do not alter quoted amounts, rounding or ledger behavior.

## Verification

Widget coverage includes 320–430-point phones, landscape, tablets, enlarged text, keyboard insets, focus dismissal on biometric lock, action reachability and exact payment outcomes. Home/review golden references use the pinned Windows/Flutter environment and remain exact-pixel comparisons. Actual Android screenshots and a real sandbox transfer supplement the tests; successful tests alone are not visual approval.
