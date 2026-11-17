import sys
def plines(lang):
    return [l.rstrip('\n').replace('\\','\\\\').replace('"','\\"') for l in open('/home/user/i18n/privacy-%s.txt'%lang,encoding='utf-8') if l.strip()]
rows=[]
for line in open('/home/user/i18n/en.tsv',encoding='utf-8'):
    line=line.rstrip('\n')
    if not line.strip(): continue
    k,v=line.split('\t')
    kind='='
    if k[0] in '~^': kind=k[0]; k=k[1:]
    rows.append((kind,k,v))
ex=[r for r in rows if r[0]=='=']
fr=sorted([r for r in rows if r[0]!='='],key=lambda r:-len(r[1]))
def q(s): return '"'+s+'"'
if sys.argv[1]=='java':
    out=['package rs.netplanet.esllink;','','import android.content.Context;','import android.content.SharedPreferences;','import java.util.HashMap;','import java.util.Locale;','',
    '/** Jezik aplikacije (sr/en) i prevod tekstova na engleski. GENERISANO iz i18n/en.tsv. */',
    'public final class L {','    private static String lang = null;','    private static final HashMap<String, String> EN = new HashMap<String, String>();',
    '    // [tip, sr, en]: "~" = deo teksta bilo gde, "^" = pocetak teksta','    private static final String[][] FRAG = {']
    out+=['        {%s, %s, %s},'%(q(r[0]),q(r[1]),q(r[2])) for r in fr]
    out+=['    };','    static {']
    out+=['        EN.put(%s, %s);'%(q(r[1]),q(r[2])) for r in ex]
    out+=['    }','    /** Politika privatnosti: redovi, "# " = naslov. */','    public static final String[] PRIVACY_SR = {']+['        %s,'%q(x) for x in plines('sr')]+['    };','    public static final String[] PRIVACY_EN = {']+['        %s,'%q(x) for x in plines('en')]+['    };','',
'''    private static SharedPreferences p(Context c) { return c.getApplicationContext().getSharedPreferences("ui", Context.MODE_PRIVATE); }

    public static void init(Context c) {
        String l = p(c).getString("lang", "");
        if (l.isEmpty()) {
            String sys = Locale.getDefault().getLanguage();
            l = ("sr".equals(sys) || "hr".equals(sys) || "bs".equals(sys) || "sh".equals(sys) || "cnr".equals(sys) || "me".equals(sys)) ? "sr" : "en";
        }
        lang = l;
    }

    public static String lang() { return lang == null ? "sr" : lang; }

    public static boolean en() { return "en".equals(lang); }

    public static void set(Context c, String l) {
        lang = l;
        p(c).edit().putString("lang", l).apply();
    }

    /** Prevod (samo kad je izabran engleski); nepoznat tekst ostaje isti. */
    public static String t(String s) {
        if (s == null || !en() || s.isEmpty()) return s;
        String x = EN.get(s);
        if (x != null) return x;
        String r = s;
        for (String[] f : FRAG) {
            if ("^".equals(f[0])) { if (r.startsWith(f[1])) r = f[2] + r.substring(f[1].length()); }
            else if (r.contains(f[1])) r = r.replace(f[1], f[2]);
        }
        return r;
    }
}''']
    print('\n'.join(out))
else:
    out=['import Foundation','','/// Jezik aplikacije (sr/en) i prevod na engleski. GENERISANO iz i18n/en.tsv.','enum L {',
    '    static let EN: [String: String] = [']
    out+=['        %s: %s,'%(q(r[1]),q(r[2])) for r in ex]
    out+=['    ]','    /// Politika privatnosti: redovi, "# " = naslov.','    static let PRIVACY_SR: [String] = [']+['        %s,'%q(x) for x in plines('sr')]+['    ]','    static let PRIVACY_EN: [String] = [']+['        %s,'%q(x) for x in plines('en')]+['    ]']
    out+=['    // (tip, sr, en): "~" = deo teksta bilo gde, "^" = pocetak teksta','    static let FRAG: [(String, String, String)] = [']
    out+=['        (%s, %s, %s),'%(q(r[0]),q(r[1]),q(r[2])) for r in fr]
    out+=['    ]',
'''
    static var lang: String = {
        if let l = UserDefaults.standard.string(forKey: "ui.lang"), !l.isEmpty { return l }
        let sys = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "sr"
        return ["sr", "hr", "bs", "sh", "me"].contains(sys) || (Locale.preferredLanguages.first ?? "").hasPrefix("cnr") ? "sr" : "en"
    }()

    static var en: Bool { lang == "en" }

    static func set(_ l: String) {
        lang = l
        UserDefaults.standard.set(l, forKey: "ui.lang")
    }

    /// Prevod (samo kad je izabran engleski); nepoznat tekst ostaje isti.
    static func t(_ s: String) -> String {
        if !en || s.isEmpty { return s }
        if let x = EN[s] { return x }
        var r = s
        for f in FRAG {
            if f.0 == "^" { if r.hasPrefix(f.1) { r = f.2 + r.dropFirst(f.1.count) } }
            else if r.contains(f.1) { r = r.replacingOccurrences(of: f.1, with: f.2) }
        }
        return r
    }
}''']
    print('\n'.join(out))
