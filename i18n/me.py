# Ekavica -> ijekavica (crnogorski) za tekstove aplikacije. Rec po rec, sa ocuvanjem velikog pocetnog slova.
import re
W = {
 'bela':'bijela','izmena':'izmjena','izmene':'izmjene','poslednja':'posljednja','promeni':'promijeni','proveri':'provjeri',
 'svetlo':'svjetlo','usmeri':'usmjeri','dela':'dijela','delu':'dijelu','menja':'mijenja','menjaju':'mijenjaju','nalepiti':'nalijepiti',
 'posle':'poslije','podrazumevani':'podrazumijevani','sledeće':'sljedeće','sledeći':'sljedeći','umesto':'umjesto',
 'uspela':'uspjela','uspelo':'uspjelo','uspeo':'uspio','uspešan':'uspješan','vreme':'vrijeme','zameniš':'zamijeniš','zamenu':'zamjenu',
 'osveži':'osvježi','osvežen':'osvježen','uneti':'unijeti','bezbednost':'bezbjednost','gde':'gdje','namenjena':'namijenjena',
 'izmenjenu':'izmijenjenu','cenovnih':'cjenovnih','delimo':'dijelimo',
}
def conv(s):
    def f(m):
        w = m.group(0); r = W.get(w.lower())
        if r is None: return w
        return r[0].upper() + r[1:] if w[0].isupper() else r
    return re.sub(r'[A-Za-zčćšđžČĆŠĐŽ]+', f, s)
