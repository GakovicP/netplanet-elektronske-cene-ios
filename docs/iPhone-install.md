# NetPlanet Elektronske cene na iPhone-u (besplatan Apple ID)

Bez App Store-a i bez plaćenog Apple Developer naloga. Besplatan Apple ID daje **Personal Team**
koji može da potpiše aplikaciju za tvoje uređaje.

**Ograničenja besplatnog naloga (Apple, ne ova aplikacija):**
- Instalirana aplikacija radi **7 dana**, posle toga je samo ponovo instaliraš (podaci ostaju).
- Najviše 3 ovako instalirane aplikacije na telefonu.

## Način A: gotov .ipa + Sideloadly (Windows ili Mac, bez Xcode-a)

Svaki build na `main` grani objavljuje na stranici **Releases** ovog repozitorijuma:
- `NetPlanet-Elektronske-Cene-1.7-bN-iPhone-unsigned.ipa` – za pravi iPhone
- `NetPlanet-Elektronske-Cene-1.7-bN-iOS-simulator.zip` – za simulator / Appetize.io

1. Instaliraj **Sideloadly** (https://sideloadly.io). Na Windows-u su potrebni i iTunes i iCloud sa Apple sajta (ne iz Microsoft Store-a).
2. Poveži iPhone kablom i potvrdi **Trust This Computer**. Uključi **Settings → Privacy & Security → Developer Mode** (iOS 16+).
3. Prevuci `.ipa` u Sideloadly, upiši Apple ID, klikni **Start**.
4. Na iPhone-u: **Settings → General → VPN & Device Management → tvoj Apple ID → Trust**.
5. Na prvom otvaranju dozvoli kameru i pristup lokalnoj mreži (server u radnji).
6. Ponovi na svakih 7 dana (Sideloadly može automatski da osvežava preko Wi‑Fi-ja).

## Način B: Xcode na Mac-u

```bash
git clone https://github.com/GakovicP/netplanet-elektronske-cene-ios.git
cd netplanet-elektronske-cene-ios
./setup-iphone.sh          # ili ./setup-iphone.sh TEAMID rs.netplanet.elektronskecene.pavle
```

U Xcode-u: šema **ESLLink**, odredište **tvoj iPhone**, Signing & Capabilities → Team = *Personal Team*, pa **Product → Run** (⌘R).
Ako bundle id `rs.netplanet.elektronskecene` nije dostupan, pokreni `./setup-iphone.sh TEAMID rs.netplanet.elektronskecene.nesto`.

## Napomene
- Server na `http://` (npr. port 8085) radi – aplikacija dozvoljava nešifrovane veze, kao Android verzija.
- Ugrađeni PDA skener ne postoji na iPhone-u; skenira se kamerom ili Bluetooth skenerom u režimu tastature (Enter na kraju koda).
