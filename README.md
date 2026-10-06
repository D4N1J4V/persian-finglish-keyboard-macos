# Finglish IME – Persian (Farsi) phonetic keyboard for macOS

A native macOS input method for typing Persian with a Latin keyboard (Finglish / Pinglish).
Type `khoshgel` and a candidate bar appears under the cursor with the Persian spellings
(`خوشگل`, `خشگل`, …), most likely first. Also known as a Pinglish / Farsi transliteration keyboard: think "Google Input Tools – Persian", but as a
system input source you switch on and off from the menu bar.

## Features

- Candidate bar under the cursor, drawn by macOS (`IMKCandidates`), so it follows the system look.
- Works for words that don't exist: spellings are generated from transliteration rules
  (س/ص/ث, ز/ذ/ض/ظ, optional short vowels, silent و in خوا…), ranked by likelihood.
- Optional online ranking by Google Input Tools: the most probable real words come first.
- Works offline with the local rules only.
- Remembers what you pick and caches answers locally.
- `?` `,` `;` become `؟` `،` `؛`; optional Persian digits.
- Enable/disable like any keyboard: input source menu in the menu bar, or the input source shortcut.

## Keys

| Key | Action |
| --- | --- |
| Space | commit the highlighted candidate + space |
| Return | commit the highlighted candidate |
| 1–9 | pick that candidate |
| ← → / Tab | move the selection |
| Backspace / Esc | edit / cancel |

The last candidate is always the text you typed, unchanged.

## Install

Requires macOS and the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh install
```

This builds `FinglishIME.app` and copies it to `~/Library/Input Methods/`. Then log out and
back in, and add it in **System Settings → Keyboard → Input Sources → Persian → Finglish**.
To uninstall, remove that input source and delete the app from `~/Library/Input Methods/`.

## Privacy

Privacy matters more than convenience here, so exactly what happens is spelled out:

- **Online lookup (on by default, can be switched off):** while you type a word, that single word
  (the Latin letters of the current word only, never the surrounding text) is sent over HTTPS to
  `https://inputtools.google.com/request`. Nothing is sent when secure input (password fields)
  is active. Redirects are not followed and no other host is ever contacted.
  Turn it off with **Use Google online** in the input method's menu to stay fully local.
- This is an undocumented endpoint used by Google's own Input Tools web page. It may change or
  stop working at any time; the app then falls back to the local rules. This project is not
  affiliated with or endorsed by Google.
- **Local data:** the words you pick and a cache of past answers are stored in
  `~/Library/Application Support/FinglishIME/` as plain JSON. They never leave your machine and
  are not part of this repository. Delete that folder to reset.
- No analytics, no telemetry, no third-party services.

## How it works

- `Sources/Engine.swift` – transliteration rules (beam search over the possible Persian spellings),
  local learning/cache, and the Google Input Tools client.
- `Sources/Controller.swift` – the `IMKInputController`: key handling, composition, candidate window.
- `Sources/main.swift` – starts the `IMKServer`.
- `build.sh` – compiles with `swiftc`, assembles the bundle and Info.plist, ad-hoc signs it.

Before publishing your own build, change the bundle identifier in `build.sh`.

## Limitations

- Offline ranking is rule-based, not a language model, so for rare words the right spelling may
  not be first. No word list is bundled.
- Ad-hoc signed only; macOS may ask you to allow it the first time.

## License

MIT
