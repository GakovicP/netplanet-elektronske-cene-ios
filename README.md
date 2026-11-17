# NetPlanet Elektronske cene (iOS)

iPhone verzija Android aplikacije **NetPlanet Elektronske cene 1.7** (`rs.netplanet.elektronskecene`) za BOWTZ ESL servere.

- Ugrađena lista servera + potpisan `servers.json` sa interneta (`ServerList.DEFAULT_URL`, potpis `servers.json.sig`,
  ECDSA P-256 / SHA-256, javni ključ u `ServerList.PUBLIC_KEY`). Nepotpisana lista se odbacuje.
- Prijava: nalog upisan u `"accounts"` ide pravo na taj server; inače poslednji server naloga, pa svi paralelno.
  Pogrešna lozinka ili zaključan nalog zaustavljaju dalje pokušaje; zaštita naloga (2 greške -> 5 min pauze).
- Serveri: „Automatski izbor” ili ručno uneti server.
- Podrška: klik na logo (prijava i početni ekran); telefoni i mail iz dela `"support"` u `servers.json`.
- Swift / SwiftUI, iOS 16+, bez spoljnih biblioteka. Xcode projekat se pravi iz `project.yml` (XcodeGen).
- GitHub Actions (`.github/workflows/build.yml`, macOS) pravi nepotpisan `.ipa` i build za simulator i objavljuje ih u Releases.
- Instalacija na telefon: [docs/iPhone-install.md](docs/iPhone-install.md).
