`nbg-rates-2026-11-03.json` is the unchanged response retrieved on 3 November 2026
from the National Bank of Georgia's undated official feed:
https://nbg.gov.ge/gw/api/ct/monetarypolicy/currencies/en/json/

Its rates become effective on 4 November. The fixture intentionally retains the
publication timestamp and per-entry `validFromDate`, plus currencies such as JPY
whose rate is quoted per 100 units. Tests read this saved file, never the network.
