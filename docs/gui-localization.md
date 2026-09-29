# GUI localization

The fork supports 17 languages: English (`en`), Simplified Chinese (`zh-Hans`), Traditional Chinese (`zh-Hant`), Japanese (`ja`), Korean (`ko`), German (`de`), French (`fr`), Spanish (`es`), Italian (`it`), Brazilian Portuguese (`pt-BR`), Russian (`ru`), Ukrainian (`uk`), Polish (`pl`), Dutch (`nl`), Turkish (`tr`), Vietnamese (`vi`) and Indonesian (`id`). The Language picker lists each under its own name. It defaults to Follow System, which resolves the first supported entry in the ordered system language list by its base language code (any Portuguese uses `pt-BR`; Chinese uses script, then region) and falls back to English. Explicit selections persist as `guiLanguage`; switching updates the retained SwiftUI view without rebuilding AppState, restarting its monitor or changing fan commands. Unknown, missing, empty or malformed individual translations fall back to the English source text.

## Adding or updating copy

1. Keep the official English copy as the `language.text(...)` key. Add the same key/value to `Sources/MacFanProLocalization/Resources/en.json`.
2. Translate `zh-Hans.json` and every other table. Keep named placeholders such as `{version}` and `{rpm}` unchanged. Dynamic values are substituted once and remain literal. A button named in a hint (such as Default in "Press Default below") must use the button's own translation.
3. Run `swift Scripts/update-traditional.swift` from the repository root. Traditional Chinese is exactly the same wording converted with Foundation's `Simplified-Traditional` transform; do not add regional vocabulary or rewrite meanings.
4. Run `bash Scripts/test.sh` and `bash Scripts/check-localization-package.sh`. The tests check key/token completeness, exact script conversion, language preference ordering, English fallback, isolated preference persistence and retained panel rendering in every language and warning state.
5. Check the layout: `MACFANPRO_PREVIEW_DIR=/some/dir swift test --filter LocalizedPanelTests` writes a PNG for every language and state. The panel is 260 pt wide. Look for truncated buttons ("…") and words broken mid-word; where a translation is too long, use a shorter term with the same meaning (for example, the Spanish Default button is "Restablecer", and several languages label the update button with just the verb because the row is already labelled "Updates").

## Adding a language

1. Add a case to `AppLanguage` with its BCP 47 code as the raw value, its native name in `AppLanguageStore.title(for:)`, and its base code in `AppLanguage.byLanguageCode`.
2. Add `Sources/MacFanProLocalization/Resources/<code>.json` with every English key. The catalog, the app's `CFBundleLocalizations` and the packaging check all derive from `AppLanguage.allCases`, so nothing else lists languages.
3. Add a system-preference case to `LocalizationTests.preferredLanguages`, then run steps 4 and 5 above.

Right-to-left languages (Arabic, Hebrew) are not supported yet; they need the panel's layout checked in mirrored form.

Profile IDs, commands, daemon protocol fields, JSON, CLI help, log text and numeric formats remain upstream contracts. Translate only their GUI presentation. The localization module has no dependency on MacFanProCore. The `AppState(startServices: false)` hook exists only for offscreen presentation tests; production initialization and actions use the upstream path.

## Packaging and upstream synchronization

`swift build` creates `MacFanPro_MacFanProLocalization.bundle` beside the app executable. The shared `macfanpro build-app` assembler, including the path used by `setup.sh`, validates and copies it into `Contents/Resources`. Binary distributions must include that adjacent bundle, pass `--localization-resources`, or ship the already assembled app. Missing/invalid resources fail before replacing an existing destination. CI checks both correct copying and that failure path.

At runtime a packaged app loads its own resource bundle, never a SwiftPM build-machine fallback. If installed resources cannot be read, English source text remains available. The app declares English as its development region and every supported localization. Sign the completed app after assembly, so resource signatures cover the translations.

When updating from official main, preserve upstream control code and layout. Wrap new GUI copy, extend every table (regenerating Traditional), and repeat the tests, layout check and packaging check. Existing original English text is still readable while a translation is pending.
