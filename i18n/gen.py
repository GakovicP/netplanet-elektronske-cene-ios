# Generise L.java (Android) i L.swift (iOS) iz en.tsv (+ crnogorski iz me.py) i privacy-*.txt.
#   python3 gen.py java > .../L.java     python3 gen.py swift > .../L.swift
import os, sys
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, D)
from me import conv

def plines(lang):
    return [l.rstrip('\n').replace('\\', '\\\\').replace('"', '\\"') for l in open(os.path.join(D, 'privacy-%s.txt' % lang), encoding='utf-8') if l.strip()]

rows = []
for line in open(os.path.join(D, 'en.tsv'), encoding='utf-8'):
    line = line.rstrip('\n')
    if not line.strip(): continue
    k, v = line.split('\t')
    kind = '='
    if k[0] in '~^': kind = k[0]; k = k[1:]
    rows.append((kind, k, v))

def table(lang):
    if lang == 'en':
        r = rows
    else:  # me: samo tekstovi koji se razlikuju od srpskog
        r = [(t, k, conv(k)) for t, k, _ in rows if conv(k) != k]
    ex = [x for x in r if x[0] == '=']
    fr = sorted([x for x in r if x[0] != '='], key=lambda x: -len(x[1]))
    return ex, fr

def q(s): return '"' + s + '"'
LANGS = ['en', 'me']

if sys.argv[1] == 'java':
    out = ['package rs.netplanet.esllink;', '', 'import android.content.Context;', 'import android.content.SharedPreferences;',
           'import java.util.HashMap;', 'import java.util.Locale;', '',
           '/** Jezik aplikacije (sr / me / en) i prevod tekstova. GENERISANO iz i18n/ (gen.py) - ne menjati rucno. */',
           'public final class L {', '    private static String lang = null;']
    for lg in LANGS:
        ex, fr = table(lg)
        U = lg.upper()
        out += ['    private static final HashMap<String, String> %s = new HashMap<String, String>();' % U,
                '    // [tip, sr, prevod]: "~" = deo teksta bilo gde, "^" = pocetak teksta',
                '    private static final String[][] FRAG_%s = {' % U]
        out += ['        {%s, %s, %s},' % (q(r[0]), q(r[1]), q(r[2])) for r in fr]
        out += ['    };', '    static {']
        out += ['        %s.put(%s, %s);' % (U, q(r[1]), q(r[2])) for r in ex]
        out += ['    }']
    out += ['    /** Politika privatnosti: redovi, "# " = naslov. */']
    for lg in ['sr', 'me', 'en']:
        out += ['    public static final String[] PRIVACY_%s = {' % lg.upper()] + ['        %s,' % q(x) for x in plines(lg)] + ['    };']
    out += ['''
    private static SharedPreferences p(Context c) { return c.getApplicationContext().getSharedPreferences("ui", Context.MODE_PRIVATE); }

    public static void init(Context c) {
        String l = p(c).getString("lang", "");
        if (l.isEmpty()) {
            String sys = Locale.getDefault().getLanguage();
            String cty = Locale.getDefault().getCountry();
            if ("cnr".equals(sys) || "ME".equals(cty)) l = "me";
            else if ("sr".equals(sys) || "hr".equals(sys) || "bs".equals(sys) || "sh".equals(sys)) l = "sr";
            else l = "en";
        }
        lang = l;
    }

    public static String lang() { return lang == null ? "sr" : lang; }

    public static boolean en() { return "en".equals(lang); }

    /** Kodovi, zastavice i nazivi jezika za izbor. */
    public static final String[] CODES = {"sr", "me", "en"};
    public static final String[] FLAGS = {"\\uD83C\\uDDF7\\uD83C\\uDDF8", "\\uD83C\\uDDF2\\uD83C\\uDDEA", "\\uD83C\\uDDEC\\uD83C\\uDDE7"};
    public static final String[] NAMES = {"Srpski", "Crnogorski", "English"};

    public static int index() {
        for (int i = 0; i < CODES.length; i++) if (CODES[i].equals(lang())) return i;
        return 0;
    }

    public static String[] privacy() { return "en".equals(lang) ? PRIVACY_EN : "me".equals(lang) ? PRIVACY_ME : PRIVACY_SR; }

    public static void set(Context c, String l) {
        lang = l;
        p(c).edit().putString("lang", l).apply();
    }

    /** Prevod na izabrani jezik; nepoznat tekst ostaje isti. */
    public static String t(String s) {
        if (s == null || s.isEmpty()) return s;
        HashMap<String, String> m;
        String[][] fr;
        if ("en".equals(lang)) { m = EN; fr = FRAG_EN; }
        else if ("me".equals(lang)) { m = ME; fr = FRAG_ME; }
        else return s;
        String x = m.get(s);
        if (x != null) return x;
        String r = s;
        for (String[] f : fr) {
            if ("^".equals(f[0])) { if (r.startsWith(f[1])) r = f[2] + r.substring(f[1].length()); }
            else if (r.contains(f[1])) r = r.replace(f[1], f[2]);
        }
        return r;
    }
}''']
    print('\n'.join(out))
else:
    out = ['import Foundation', '', '/// Jezik aplikacije (sr / me / en) i prevod. GENERISANO iz i18n/ (gen.py) - ne menjati rucno.', 'enum L {']
    for lg in LANGS:
        ex, fr = table(lg)
        U = lg.upper()
        out += ['    static let %s: [String: String] = [' % U] + ['        %s: %s,' % (q(r[1]), q(r[2])) for r in ex] + ['    ]']
        out += ['    // (tip, sr, prevod): "~" = deo teksta bilo gde, "^" = pocetak teksta',
                '    static let FRAG_%s: [(String, String, String)] = [' % U] + ['        (%s, %s, %s),' % (q(r[0]), q(r[1]), q(r[2])) for r in fr] + ['    ]']
    out += ['    /// Politika privatnosti: redovi, "# " = naslov.']
    for lg in ['sr', 'me', 'en']:
        out += ['    static let PRIVACY_%s: [String] = [' % lg.upper()] + ['        %s,' % q(x) for x in plines(lg)] + ['    ]']
    out += ['''
    static var lang: String = {
        if let l = UserDefaults.standard.string(forKey: "ui.lang"), !l.isEmpty { return l }
        let p = Locale.preferredLanguages.first ?? "sr"
        if p.hasPrefix("cnr") || p.hasSuffix("-ME") { return "me" }
        return ["sr", "hr", "bs", "sh"].contains(String(p.prefix(2))) ? "sr" : "en"
    }()

    static var en: Bool { lang == "en" }

    /// Kodovi, zastavice i nazivi jezika za izbor.
    static let LANGS: [(code: String, flag: String, name: String)] = [
        ("sr", "\\u{1F1F7}\\u{1F1F8}", "Srpski"),
        ("me", "\\u{1F1F2}\\u{1F1EA}", "Crnogorski"),
        ("en", "\\u{1F1EC}\\u{1F1E7}", "English"),
    ]

    static var current: (code: String, flag: String, name: String) { LANGS.first { $0.code == lang } ?? LANGS[0] }

    static var privacy: [String] { lang == "en" ? PRIVACY_EN : lang == "me" ? PRIVACY_ME : PRIVACY_SR }

    static func set(_ l: String) {
        lang = l
        UserDefaults.standard.set(l, forKey: "ui.lang")
    }

    /// Prevod na izabrani jezik; nepoznat tekst ostaje isti.
    static func t(_ s: String) -> String {
        if s.isEmpty { return s }
        let m: [String: String]
        let fr: [(String, String, String)]
        if lang == "en" { m = EN; fr = FRAG_EN } else if lang == "me" { m = ME; fr = FRAG_ME } else { return s }
        if let x = m[s] { return x }
        var r = s
        for f in fr {
            if f.0 == "^" { if r.hasPrefix(f.1) { r = f.2 + r.dropFirst(f.1.count) } }
            else if r.contains(f.1) { r = r.replacingOccurrences(of: f.1, with: f.2) }
        }
        return r
    }
}''']
    print('\n'.join(out))
