# Test-Fixture „lizenztest“

Ein Paket **mit Lizenzblock** nur für `test_11_ip_firewall` (`docs/11` Kap. 3.12): Schicht 1 erlaubt einen Lizenzblock
im Repository nur hier, unter `game/tests/fixtures/packs/`, und nur mit dem `holder` „TEST – kein Rechteinhaber“.
Schicht 2 prüft mit ihm die Ausnahme von `ip_words` (nur die IP-Abstandslisten, nie Herkunft und Ton). Die Texte hier
sind harmlos; die Varianten mit Wörtern aus den Sperrlisten baut der Test zur Laufzeit in `user://`.
