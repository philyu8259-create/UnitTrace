# UnitTrace / 房况留证

Offline-first rental condition evidence reports for iOS and Android.

## MVP

- Create a property and start move-in, move-out, or general inspections.
- Use default room templates for structured photo and note capture.
- Store evidence locally with timestamps, optional location, and SHA-256 hashes.
- Capture tenant/landlord signatures and export a watermarked PDF plus JSON manifest.
- English and Simplified Chinese UI, following the device locale.
- GPT Image generated assets are stored under `assets/`.

## Verify

```bash
flutter test
flutter analyze
flutter build ios --simulator --debug
flutter build apk --debug
```

## Public Pages

The iOS "More" tab opens language-specific GitHub Pages URLs. Before App Store
submission, enable GitHub Pages for this repository or replace these URLs with
the production support domain:

- Privacy Policy (English): `https://philyu8259-create.github.io/UnitTrace/privacy-policy-en.html`
- Privacy Policy (Chinese): `https://philyu8259-create.github.io/UnitTrace/privacy-policy-zh.html`
- Support (English): `https://philyu8259-create.github.io/UnitTrace/support-en.html`
- Support (Chinese): `https://philyu8259-create.github.io/UnitTrace/support-zh.html`
