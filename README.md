# Vaultwarden Menu
Informacje
- Skrypt pozwala w prosty sposób zainstalować vaultwarden na hostingu ct8.pl
- Vaultwarden jest budowany ze źródła, ponieważ nie chciało mi się bawić w gotowe binarki i kombinować jak zasysać najnowsze wersje.
- Budowa trwa około 20 minut. 
- Menedżer umożliwia skonfigurowanie supervisora pod wybraną domenę, sprawdzanie i uaktualnianie do najnowszych wersji web-vault i vaultwarden.
- Skypt sprawdza co zostało wykonane i nie ponawia tych samych czynności.
- Kod skryptu nie jest idealny, czasem może pojawić się jakiś błąd.

Wymagania:
- Konto na hostingu ct8.pl
- domena

Główne ścieżki instalacji (w skrócie)
$HOME/
├── supervisor
│   ├── supervisor.conf
│   ├── supervisor.log
|   ├── supervisor.pid
|   ├── supervisor.sock
|   └── tmp
|       ├── vaultwarden-stderr---supervisor-_8fq1idg.log
|       └── ....
|
└── vaultwarden
    ├── app
    │   └── target
    │       └── release
    │           ├── vaultwarden  (Program)
    │           └── web-vault  (strona internetowa)
    ├── data  (baza danych)
    |   ├── config.json
    |   ├── db.sqlite3
    |   ├── db.sqlite3-shm
    |   └── db.sqlite3-wal
    └── programs
        ├── cargo
        │   └── bin
        |       ├── rustup  
        |       └── cargo (program wymagany do kompilacji)
        └── rustup
            └── ...
