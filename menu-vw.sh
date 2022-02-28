#!/bin/bash

# Menedżer instalacji Vaultwarden na CT8.PL
##------------------##
# ALIASY DO ŚCIEŻEK  #
##------------------##
# - Vaultwarden
    APP="vaultwarden"
    WEB="web-vault"
    WORK_DIR="$HOME"
    APP_DIR="$WORK_DIR/$APP"
    DATA_DIR="$APP_DIR/data"
    GIT_DIR="$APP_DIR/app"
    GIT_URL="https://github.com/dani-garcia/vaultwarden.git"
    BIN_DIR="$GIT_DIR/target/release"
    WEB_DIR="$BIN_DIR/web-vault"
    BINARY="$BIN_DIR/vaultwarden"

# - Cargo i Rustup
    RUSTUP_DIR="$APP/programs/rustup"
    CARGO_DIR="$APP/programs/cargo"
    RUSTUP_BIN="$APP_DIR/programs/cargo/bin/rustup"
    CARGO_BIN="$APP_DIR/programs/cargo/bin/cargo"
    CARGO_ENV="$APP_DIR/programs/cargo/env"

# - Supervisor Daemon (work in progress)
    SV_DIRNAME="supervisor"
    SV_DIR="$WORK_DIR/$SV_DIRNAME"
    SV_CONF="$SV_DIR/supervisor.conf"
    SV_SOCK="$SV_DIR/supervisor.sock"
    GET_SV_CONF="https://gist.githubusercontent.com/Daviteusz/425dba601a4cc2c32f572762d49bc5ae/raw/6f25077ed5f2f55a47656bcfba41353998ac2147/supervisor.conf"

##------------------##
# FUNKCJE DODATKOWE  #
##------------------##
# - Kompatybilność systemu
    function system_compatiblity_check () {
        if [[ $(uname -n) =~ ct8.pl ]]; then
            menu
        else
            echo "Skrypt działa wyłącznie na ct8.pl"
            sleep 2
            exit
        fi
    }

# - Cargo i Rustup - Instalacja
    function cargo_rustup_install () {
        if [[ -f "$RUSTUP_BIN" && -f "$CARGO_BIN" ]]; then
            . "$CARGO_ENV"
        else
            echo "- Rust i Cargo - Instalacja (Może to chwilę potrwać)... "
            curl -s https://sh.rustup.rs -sSf \
            | RUSTUP_HOME=$RUSTUP_DIR CARGO_HOME=$CARGO_DIR \
            sh -s -- -y -q --no-modify-path --profile minimal --default-toolchain nightly &> /dev/null
            sleep 2
            if [[ -f "$RUSTUP_BIN" && -f "$CARGO_BIN" ]];then
                . "$CARGO_ENV"
                echo "  > Instalacja ukończona"
                sleep 2
            else
                echo "  > Instalacja nie powiodła się. Kończenie..."
                sleep 2 
                menu
            fi
        fi
    }

# - Konfiguracja katalogów
    function dirs_config () {
        if [[ -d $APP_DIR && -d $DATA_DIR ]]; then
            sleep 0
        else
            echo "- Konfiguracja katalogów..."
            mkdir -p "$APP_DIR"
            sleep 1
            mkdir -p "$DATA_DIR"
            sleep 2
        fi
    }

# - Vaultwarden - Sprawdzenie najnowszej wersji
    function git_latest_tag () {
        cd "$GIT_DIR" || exit
        git fetch -q --tags \
        | git describe --tags "$(git rev-list --tags --max-count=1)"
    }

# - Vaultwarden - Sprawdzenie zainstalowanej wersji
    function binary_version () {
        $BINARY --version \
        | cut -d ' ' -f2-
    }
# - Vaultwarden - Kompilacja
    function vw_build () {
        read -rp "Naciśnij enter, aby rozpocząć kompilację."
        sleep 2
        clear
        echo "
        ##---------------------------------------##
        # Vaultwarden - instalacja / aktualizacja #
        ##---------------------------------------##"
        cd "$GIT_DIR" || exit
        if [ -f "$BINARY" ]; then
            cargo update
            cargo build --features sqlite --release -j1 \
            | CARGO_INCREMENTAL=1
            if [ -f "$BINARY" ]; then
                sv_restart
                echo "- Aktualizacja ukończona"
            else
                echo "- Aktualizacja nie powiodła się. Kończenie..."
                sleep 3
                menu
            fi
        else
            cargo update
            cargo clean && cargo build --features sqlite --release -j1
            if [ -f "$BINARY" ]; then
                sv_restart
                echo "- Kompilacja ukończona"
            else
                echo "- Kompilacja nie powiodła się. Kończenie..."
                sleep 3
                menu
            fi
        fi
        read -rp "- Naciśnij enter, aby wyczyścić terminal"
        clear
    }

# - Vaultwarden - Status
    function sv_status () {
        if [ -S "$SV_SOCK" ]; then
            supervisorctl -c "$SV_CONF" status vaultwarden
        else
            Najpierw uruchom supervisor, aby sprawdzić status
            sleep 2
            menu
        fi
    }
# - Web Vault - Główny - weryfikacja i przywołanie instalatora
    function web-vault_main() {
        sleep 2
        if [ -f "$WEB_DIR/vw-version.json" ];then
            if [[ "$(web_curl_version)" == "$(web_installed_version)" ]]; then
                echo "- Web-Vault jest aktualny. Powrót do Menu..."
                sleep 3
                menu
            else
                web-vault_install
            fi
        else    
            web-vault_install
        fi
    }
# - Web Vault - Podrzędny, Instalacja
    function web-vault_install() {
        echo "- Web-Vault - Instalacja/Aktualizacja..."
        sleep 2
        rm -rf "$WEB_DIR"
        cd "$BIN_DIR" || exit
        echo "  > Pobieranie najnowszej wersji..."
        web_download
        sleep 2
        echo "  > Rozpakowywanie $WEB..."
        tarball="$(find . -name "*.tar.gz")"
        tar -xf "$tarball"
        rm "$tarball"
        sleep 2
        echo "  > Instalacja ukończona"
    }
# - Web Vault - Sprawdzenie najnowszej wersji
    function web_curl_version () {
        curl -s \
        https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest \
        | grep 'browser_download_url.*tar.gz"' \
        | cut -d v -f 2 \
        | cut -d / -f 1
    }
# - Web Vault - Sprawdzenie zainstalowanej wersji
    function web_installed_version () {
        cat "$WEB_DIR/vw-version.json" \
        | grep 'version' \
        | cut -d '"' -f 4
    }

# - Web Vault - Pobieranie najnowszej wersji
    function web_download () {
        curl -s https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest \
        | grep 'browser_download_url.*tar.gz"' \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | xargs -n 1 curl -O -sSL 
    }

# - Supervisor - Sprawdzenie, czy jest wygenerowany port
    function ifct8port() {
        devil port list \
        | grep -o 'Vaultwarden'
    }
# - Supervisor - Uzyskanie wygenerowanego portu
    function ct8port_get() {
        devil port list \
        | grep 'Vaultwarden' \
        | grep -o '[0-9]*'
    }
# - Supervisor - Sprawdzdenie, czy jest domena
    function ifct8www() {
        devil www list \
        | grep -o "$DNAME"
    }
# - Supervisor - Status Devil BinExec
    function statusbinexec () {
        devil info account \
        | grep "Binexec:" \
        | awk '{print $3}'
    }
# - Supervisor - Skrypt konfiguracji
    function sv_config () {
        if [[ "$(statusbinexec)" != Włączony ]]; then
            sleep 2
            echo "- Włączanie uprawnienia: BinExec..."
            devil binexec on &>/dev/null
            sleep 2
            echo "  > Przeloguj się, aby zastosować zmiany."
            sleep 2
            exit
        fi
        cd "$WORK_DIR" || exit
        if [ ! -d "$SV_DIR" ]; then
            echo "- Konfiguracja katalogów..."
            mkdir "$SV_DIRNAME"
            cd "$SV_DIR" || exit
            mkdir tmp
        fi
        cd "$SV_DIR" || exit
        echo "- Pobieranie szablonu konfiguracji..."
        wget -q -O supervisor.conf "$GET_SV_CONF" 2>/dev/null
        if [ -f "$SV_CONF" ]; then
            sleep 2
            echo "- Konfigurowanie supervisor..."
            sed -i -e "s/@@/$(id -un)/g" "$SV_CONF"
            sleep 2
            if [[ $(ifct8port) != Vaultwarden ]]; then
                echo "  > Rezerwacja portu..."
                devil port add tcp random Vaultwarden
            fi
            sed -i -e "s/##/$(ct8port_get)/g" "$SV_CONF"
            DNAME=""
            read -rp "  > Wpisz swoją domenę, np. bw.domena.xyz: " DNAME
            sed -i -e "s/&&/$DNAME/g" "$SV_CONF"
            if [[ $(ifct8www) == "$DNAME" ]]; then
                echo "  > Ta domena jest już skonfigurowana..."
            else
                echo "  > Trwa dodawanie strony, może to chwilę potrwać..."
                devil www add "$DNAME" proxy localhost "$(ct8port_get)" &>/dev/null
                devil www options "$DNAME" waf 2 &>/dev/null
                echo "  > Strona została dodana pomyślnie."
            fi
                sleep 2
            if [ ! -S "$SV_SOCK" ]; then
                echo "- Uruchamianie usługi Supervisor..."
                supervisord -c "$SV_CONF"
                sleep 2
                if [ -S "$SV_SOCK" ]; then
                    echo "  > Supervisor został uruchomiony."
                    sleep 3
                    menu
                else
                    echo "  > Nie można uruchomić Supervisor. Kończenie..."
                    supervisorctl -c "$SV_CONF" shutdown &>/dev/null
                    sleep 2
                    menu
                fi
            fi
        else
            echo "- Nie można pobrać pliku konfiguracji. Kończenie..."
            sleep 3
            menu
        fi
            # Missing
            # Something
    }
# - Supervisor - Restart
    function sv_restart () {
        if [ -S "$SV_SOCK" ]; then
            supervisorctl -c "$SV_CONF" restart vaultwarden
        fi
    }
##-------------------------------##
# FUNKCJE GŁÓWNEGO SKRYPTU (MENU) #
##-------------------------------##
# - Budowa i instalacja Vaultwarden
    function vw_main() {
        echo "
        ##---------------------------------------##
        # Vaultwarden - instalacja / aktualizacja #
        ##---------------------------------------##"
        if [ -d "$GIT_DIR" ]; then
            if [ -f "$BINARY" ]; then 
                if [[ "$(git_latest_tag)" == "$(binary_version)" ]]; then
                    sleep 1
                    echo "- Vaultwarden jest aktualny."
                    sleep 2
                    web-vault_main
                fi
            fi
        fi
        if [ -S "$SV_SOCK" ]; then
            supervisorctl -c "$SV_CONF" stop vaultwarden &>/dev/null
        fi
        sleep 2
        dirs_config
        sleep 2
        cargo_rustup_install
        sleep 2
        if [ -d "$GIT_DIR" ]; then
            cd "$GIT_DIR" || exit
            if [ -f "$BINARY" ]; then
                sleep 2
                if [[ "$(git_latest_tag)" != "$(binary_version)" ]]; then
                    echo "- Uaktualnienie kodu źródłowego..."
                    git checkout -q "$(git_latest_tag)"
                    sleep 2
                    vw_build
                fi
            else
                sleep 2
                vw_build
            fi
        else
            echo -e "- Pobieranie kodu źródłowego $APP..."
            sleep 2
            git clone -q "$GIT_URL" "$GIT_DIR" 
            cd "$GIT_DIR" || exit
            git checkout -q "$(git_latest_tag)"
            sleep 2
            vw_build
            sleep 3
            web-vault_main
        fi
        echo
    }
# - Sprawdzanie aktualizacji
    function check_updates () {
        echo "
        ##------------------------##
        # Wyszukiwanie uaktualnień #
        ##------------------------##"   
        sleep 2
        if [ -f "$BINARY" ]; then
            cd "$GIT_DIR" || exit
            if [[ "$(git_latest_tag)" == "$(binary_version)" ]]; then
                echo "- Vaultwarden jest aktualny."
                sleep 2
            else
                echo "- Vaultwarden..."
                sleep 2
                echo "  > Najnowsza wersja: $(ColorGreen "$(git_latest_tag)")"
                sleep 2
                echo "  > Zainstalowana wersja: $(ColorBlue "$(binary_version)")"
                sleep 2
                read -r -p "  Chcesz zaktualizować Vaultwarden? [y/N] " response
                if [[ "$response" =~ ^([yY])$ ]]; then
                    vw_main
                else
                    if [[ "$response" =~ ^([nN])$ ]]; then
                        menu
                    else
                        echo "Naciśnięto błędny klawisz, kończenie..."
                        menu
                    fi
                fi  
            fi
        else
            echo "- Vaultwarden jeszcze nie zainstalowano."
            read -r -p "  Chcesz zainstalować Vaultwarden? [y/N] " response
            if [[ "$response" =~ ^([yY])$ ]]; then
                vw_main
            else
                if [[ "$response" =~ ^([nN])$ ]]; then
                    menu
                else
                    echo "Naciśnięto błędny klawisz, kończenie..."
                    menu
                fi
            fi  
        fi
        sleep 2
        if [ -d "$WEB_DIR" ]; then
            if [[ "$(web_curl_version)" == "$(web_installed_version)" ]]; then
                echo "- web-vault jest aktualny."
                sleep 2
                menu
            else
                echo "- web-vault..."
                sleep 2
                echo "  > Najnowsza wersja: $(ColorGreen "$(web_curl_version)")"
                sleep 2
                echo "  > Zainstalowana wersja: $(ColorBlue "$(web_installed_version)")"
                sleep 2
                read -r -p "  Chcesz zaktualizować web-vault? [y/N] " response
                if [[ "$response" =~ ^([yY])$ ]]; then
                    web-vault_main
                else
                    if [[ "$response" =~ ^([nN])$ ]]; then
                        menu
                    else
                        echo "Naciśnięto błędny klawisz, kończenie..."
                        menu
                    fi
                fi  
            fi
        else
            echo "  $WEB jeszcze nie zainstalowano"
            sleep 2
            read -r -p "  Chcesz pobrać web-vault? [y/N] " response
            if [[ "$response" =~ ^([yY])$ ]]; then
                web-vault_main
            else
                if [[ "$response" =~ ^([nN])$ ]]; then
                    menu
                else
                    echo "Naciśnięto błędny klawisz, kończenie..."
                    menu
                fi
            fi  
        fi
    }

# - Konfiguracja Supervisor
    function sv_main () {
        echo "
        ##-----------------------##
        # Konfiguracja Supervisor #
        ##-----------------------##"
        if [ -f "$SV_CONF" ]; then
            echo "- Supervisor jest już skonfigurowany..."
            sleep 2
            echo "  Chcesz ponownie go skonfigurować?"
            sleep 2
            read -r -p "  UWAGA: Plik zostanie usunięty. [y/N] " response
            if [[ "$response" =~ ^([yY])$ ]]; then
                echo "- Zatrzymywanie usługi Supervisor..."
                supervisorctl -c "$SV_CONF" shutdown &>/dev/null
                sv_config
            else
                if [[ "$response" =~ ^([nN])$ ]]; then
                    menu
                else
                    echo "  > Naciśnięto błędny klawisz, kończenie..."
                    sleep 2
                    menu
                fi
            fi  
        else
            sv_config
        fi
    }

##---------------------##
#  KONFIGURACJE (MENU)  #
##---------------------##
# - Aliasy kolorów
    green='\e[32m'
    blue='\e[34m'
    clear='\e[0m'
    yellow='\e[33m'
    whitex='\e[30;1m'

# - FUNKCJE KOLORÓW
    ColorGreen(){
        echo -ne "$green""$1""$clear"
    }
    ColorBlue(){
        echo -ne "$blue""$1""$clear"
    }
    ColorYellow(){
        echo -ne "$yellow""$1""$clear"
    }
    ColorWhitex(){
        echo -ne "$whitex""$1""$clear"
    }
# - Supervisor - Menu
    sv-submenu(){
            echo -ne "
                Menedżer Supervisor
    --------------------------------------------
    $(ColorGreen '1)') Stan (status vaultwarden)
    $(ColorGreen '2)') Uruchom (start vaultwarden)
    $(ColorGreen '3)') Zatrzymaj (stop vaultwarden)
    $(ColorGreen '4)') Uruchom ponownie (restart vaultwarden)
    $(ColorGreen '5)') Wyłącz (shutdown supervisord)
    $(ColorYellow '6)') Skonfiguruj
    $(ColorWhitex '9)') Powrót do menu
    $(ColorWhitex '0)') Wyjście
    $(ColorBlue '- Wybierz opcję:') "
        read -r a
        case $a in
            1) sv_status ; sv-submenu ;;
            2) sv_on ; sv-submenu ;;
            3) sv_off ; sv-submenu ;;
            4) sv_shutdown ; sv-submenu ;;
            5) sv_main ; sv-submenu ;;
            9) menu ;;
            0) exit 0 ;;
            *) echo -e "Nieprawidłowy wybór.""$clear"; WrongCommand;;
        esac
        }
# - Vaultwarden - MENU
    menu(){
        echo -ne "
                Menedżer Vaultwarden
    --------------------------------------------
    $(ColorGreen '1)') Instaluj / Aktualizuj
    $(ColorGreen '2)') Sprawdź aktualizacje
    $(ColorYellow '3)') Menedżer Supervisor
    $(ColorWhitex '0)') Wyjście
    $(ColorBlue '- Wybierz opcję:') "
        read -r a
        case $a in
            1) vw_main ; menu ;;
            2) check_updates ; menu ;;
            3) sv-submenu ; menu ;;
            0) exit 0 ;;
            *) echo -e "Nieprawidłowy wybór.""$clear"; WrongCommand;;
        esac
    }
    # Call the menu function
    system_compatiblity_check
    menu
