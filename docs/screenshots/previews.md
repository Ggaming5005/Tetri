# README UI previews

The four README images render the current Flutter widgets at 360 × 800 logical pixels with bundled Inter and Phosphor fonts. They use deterministic demonstration data; they are not evidence that a live exchange-rate conversion has completed.

| Image | Source and data |
| --- | --- |
| `home-light.png` | Exact copy of the Home light-mode golden reference. Demo accounts and stored test rates produce the displayed GEL total. |
| `transfer-review-light.png` | Exact copy of the Send review light-mode golden reference, showing a 25.00 GEL transfer to `@nino`. |
| `convert-dark.png` | Current Convert screen with a controlled 100.00 USD quote at 2.7 GEL/USD: gross 270.00 GEL, net 268.65 GEL, fee 1.35 GEL. The rate is illustrative. |
| `sent-dark.png` | Current bounded StatusView showing the completed 25.00 GEL transfer, with the summary centered and Done at the bottom. |

The phone's native keyboard is provided by Android/iOS and is not drawn in Flutter UI snapshots. The separate `native-keyboard.png` is an Android emulator capture connected to the local API, showing 12.50 USD entered before review; that payment was not confirmed. Physical-device transfer, biometric unlock and native-keyboard checks are recorded in [verification](../verification.md). Earlier gallery images in this directory document Phase 4 and are not the current README previews.
