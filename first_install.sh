#!/bin/bash

# Farben für die Ausgabe
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0m'
nc='\033[0m' # Kein Farbcode

# Funktion zum Ausgeben eines Schritts
show_step() {
    echo -e "${yellow}[$1/$2] $3...${nc}"
}

# Funktion zum Anzeigen, dass ein Schritt abgeschlossen ist
step_done() {
    echo -e "${green}✓ $1 abgeschlossen${nc}"
}

# Gesamtschritte für das Skript festlegen
total_steps=20
current_step=1

# Setze das Arbeitsverzeichnis auf das Verzeichnis, in dem das Skript liegt
show_step $current_step $total_steps "Setze Arbeitsverzeichnis"
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd "$SCRIPT_DIR" || exit
step_done "Arbeitsverzeichnis gesetzt"
((current_step++))

# Überprüfen, ob das Skript mit Root-Rechten ausgeführt wird
show_step $current_step $total_steps "Überprüfen von Root-Rechten"
if [ "$EUID" -ne 0 ]; then
  echo -e "${red}Bitte führe das Skript mit Root-Rechten aus.${nc}"
  exit 1
fi
step_done "Root-Rechte überprüft"
((current_step++))

# Benutzer ermitteln, der das Skript mit sudo gestartet hat
if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ]; then
  echo -e "${red}Bitte starte das Skript als normaler Benutzer mit sudo:${nc}"
  echo "sudo ./first_install.sh"
  exit 1
fi
install_user="$SUDO_USER"
install_group="$(id -gn "$install_user")"
if ! id -nG "$install_user" | grep -qw docker; then
  echo -e "${red}Der Benutzer $install_user gehört nicht zur Gruppe docker.${nc}"
  echo "Füge ihn zunächst hinzu:"
  echo "sudo usermod -aG docker $install_user"
  exit 1
fi
step_done "Benutzer ermittelt"
((current_step++))

# Überprüfen, ob Docker installiert ist
show_step $current_step $total_steps "Überprüfen von Docker"
if ! command -v docker &> /dev/null; then
  echo -e "${red}Docker ist nicht installiert. Bitte folge der Anleitung unter: https://docs.docker.com/engine/install/${nc}"
  exit 1
fi
step_done "Docker installiert"
((current_step++))

# Überprüfen, ob Docker Compose installiert ist
show_step $current_step $total_steps "Überprüfen von Docker Compose"
if ! command -v docker compose &> /dev/null; then
  echo -e "${red}Docker Compose ist nicht installiert. Bitte folge der Anleitung unter: https://docs.docker.com/engine/install/${nc}"
  exit 1
fi
step_done "Docker Compose installiert"
((current_step++))

# Installiere apache2-utils, falls nicht vorhanden
show_step $current_step $total_steps "Installiere apache2-utils, falls erforderlich"
command -v htpasswd >/dev/null 2>&1 || { sudo apt update && sudo apt install -y apache2-utils; }
step_done "apache2-utils installiert"
((current_step++))

# Überprüfen, ob Container laufen
show_step $current_step $total_steps "Überprüfen von laufenden Containern"
containers=("crowdsec" "socket-proxy" "traefik")
for container in "${containers[@]}"; do
  if [ "$(docker ps -q -f name=$container)" ]; then
    echo -e "${red}Der Docker-Container '$container' läuft bereits. Das Skript wird abgebrochen.${nc}"
    exit 1
  fi
done
step_done "Keine laufenden Container gefunden"
((current_step++))

# Netzwerke überprüfen
show_step $current_step $total_steps "Überprüfen von Netzwerken"
networks=("proxy" "socket_proxy" "crowdsec")
for network in "${networks[@]}"; do
  if [ "$(docker network ls -q -f name=^${network}$)" ]; then
    echo -e "${red}Das Docker-Netzwerk '$network' existiert bereits. Das Skript wird abgebrochen.${nc}"
    exit 1
  fi
done
step_done "Keine bestehenden Netzwerke gefunden"
((current_step++))

# Dateien kopieren
show_step $current_step $total_steps "Kopiere erforderliche Dateien"
files_to_copy=(
  ".env.sample .env"
  "data/crowdsec/.env.sample data/crowdsec/.env"
  "data/crowdsec/appsec.yaml.sample data/crowdsec/appsec.yaml"
  "data/socket-proxy/.env.sample data/socket-proxy/.env"
  "data/traefik/.env.sample data/traefik/.env"
  "data/traefik/.htpasswd.sample data/traefik/.htpasswd"
  "data/traefik/traefik.yml.sample data/traefik/traefik.yml"
  "data/traefik/certs/acme_letsencrypt.json.sample data/traefik/certs/acme_letsencrypt.json"
  "data/traefik/certs/acme_cloudflare.json.sample data/traefik/certs/acme_cloudflare.json"
  "data/traefik/certs/acme_desec.json.sample data/traefik/certs/acme_desec.json"
  "data/traefik/certs/tls_letsencrypt.json.sample data/traefik/certs/tls_letsencrypt.json"
  "data/traefik/dynamic_conf/http.middlewares.default.yml.sample data/traefik/dynamic_conf/http.middlewares.default.yml"
  "data/traefik/dynamic_conf/http.middlewares.default-security-headers.yml.sample data/traefik/dynamic_conf/http.middlewares.default-security-headers.yml"
  "data/traefik/dynamic_conf/http.middlewares.gzip.yml.sample data/traefik/dynamic_conf/http.middlewares.gzip.yml"
  "data/traefik/dynamic_conf/http.middlewares.traefik-dashboard-auth.yml.sample data/traefik/dynamic_conf/http.middlewares.traefik-dashboard-auth.yml"
  "data/traefik/dynamic_conf/tls.yml.sample data/traefik/dynamic_conf/tls.yml"
)

# Dateien kopieren oder das Skript beenden, wenn eine .sample Datei fehlt
for file_pair in "${files_to_copy[@]}"; do
  src=$(echo $file_pair | awk '{print $1}')
  dst=$(echo $file_pair | awk '{print $2}')

  src_path="${SCRIPT_DIR}/${src}"
  dst_path="${SCRIPT_DIR}/${dst}"

  if [ -f "$src_path" ]; then
    cp "$src_path" "$dst_path"
    echo "Kopiere ${src_path} nach ${dst_path}"
  else
    echo -e "${red}Die Datei ${src_path} existiert nicht. Das Skript wird abgebrochen.${nc}"
    exit 1
  fi
done

chmod 600 data/traefik/.htpasswd
chmod 600 data/traefik/.env
chmod 600 data/traefik/certs/acme_letsencrypt.json
chmod 600 data/traefik/certs/acme_cloudflare.json
chmod 600 data/traefik/certs/acme_desec.json
chmod 600 data/traefik/certs/tls_letsencrypt.json

step_done "Dateien kopiert und Rechte gesetzt"
((current_step++))

# Benutzerabfrage mit y/n und Standardwert 'n' für das CrowdSec-Repository
show_step $current_step $total_steps "Überprüfung: CrowdSec-Repository"

# Frage den Benutzer, ob das CrowdSec-Repository bereits installiert ist, Standardwert 'n'
read -p "Ist das CrowdSec-Repository bereits in deinen Paketquellen vorhanden? [y/n, Standard: n]: " has_crowdsec_repo
has_crowdsec_repo=${has_crowdsec_repo:-n}  # Standardwert n setzen
has_crowdsec_repo=$(echo "$has_crowdsec_repo" | tr '[:upper:]' '[:lower:]')  # Eingabe in Kleinbuchstaben umwandeln

# Prüfen, ob das Repository installiert werden muss
if [ "$has_crowdsec_repo" == "y" ]; then
  echo "Das CrowdSec-Repository ist bereits vorhanden. Installation wird übersprungen."
else
  echo "Das CrowdSec-Repository wird installiert..."
  curl -s https://install.crowdsec.net | sudo sh
  echo "CrowdSec-Repository erfolgreich installiert."
fi

# Schritt abgeschlossen
step_done "CrowdSec-Repository überprüft und ggf. installiert"
((current_step++))

# Installiere openssl, falls nicht vorhanden
show_step $current_step $total_steps "Überprüfen von OpenSSL"
command -v openssl >/dev/null 2>&1 || { sudo apt update && sudo apt install -y openssl; }
step_done "OpenSSL überprüft"
((current_step++))

# API-Schlüssel generieren. Die produktive Middleware-Datei wird aus der
# versionierten Vorlage erzeugt und bleibt durch .gitignore unveröffentlicht.
show_step $current_step $total_steps "Generiere CrowdSec-API-Schlüssel"
BOUNCER_KEY_TRAEFIK_PASSWORD=$(openssl rand -hex 32)
BOUNCER_KEY_FIREWALL_PASSWORD=$(openssl rand -hex 32)
sed -i "s/^BOUNCER_KEY_TRAEFIK=.*/BOUNCER_KEY_TRAEFIK=$BOUNCER_KEY_TRAEFIK_PASSWORD/" "${SCRIPT_DIR}/.env"
sed -i "s/^BOUNCER_KEY_FIREWALL=.*/BOUNCER_KEY_FIREWALL=$BOUNCER_KEY_FIREWALL_PASSWORD/" "${SCRIPT_DIR}/.env"

crowdsec_middleware_template="${SCRIPT_DIR}/data/traefik/dynamic_conf/http.middlewares.crowdsec.yml.sample"
crowdsec_middleware_config="${SCRIPT_DIR}/data/traefik/dynamic_conf/http.middlewares.crowdsec.yml"

umask 077
sed "s/__BOUNCER_KEY_TRAEFIK__/$BOUNCER_KEY_TRAEFIK_PASSWORD/" \
  "$crowdsec_middleware_template" > "$crowdsec_middleware_config"
chmod 600 "$crowdsec_middleware_config"

if grep -q "__BOUNCER_KEY_TRAEFIK__" "$crowdsec_middleware_config"; then
  echo -e "${red}Der CrowdSec-LAPI-Key konnte nicht in die Middleware-Konfiguration eingesetzt werden.${nc}"
  exit 1
fi
step_done "CrowdSec-API-Schlüssel generiert"
((current_step++))

# E-Mail-Adresse für SSL-Zertifikate
show_step $current_step $total_steps "Frage nach E-Mail-Adresse für SSL-Zertifikate"

# Funktion zur E-Mail-Validierung
validate_email() {
  local email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
  if [[ $1 =~ $email_regex ]]; then
    return 0  # gültige E-Mail
  else
    return 1  # ungültige E-Mail
  fi
}

# Benutzer nach E-Mail-Adresse fragen und diese bestätigen
while true; do
  read -p "Bitte gib deine E-Mail-Adresse für die SSL-Zertifikate ein: " ssl_email
  if validate_email "$ssl_email"; then
    echo "Gültige E-Mail-Adresse eingegeben: $ssl_email"

    # Bestätigung der E-Mail-Adresse mit y/n (Standard: y)
    read -p "Möchtest du diese E-Mail-Adresse verwenden? ($ssl_email) [y/n, Standard: y]: " confirm_email
    confirm_email=${confirm_email:-y}  # Standardwert auf 'y' setzen
    confirm_email=$(echo "$confirm_email" | tr '[:upper:]' '[:lower:]')  # In Kleinbuchstaben umwandeln

    if [ "$confirm_email" == "y" ]; then
      echo "E-Mail-Adresse wurde bestätigt: $ssl_email"
      break
    else
      echo -e "\e[31mE-Mail-Adresse wurde nicht bestätigt. Bitte gib eine neue E-Mail-Adresse ein.\e[0m"
    fi
  else
    echo -e "\e[31mUngültige E-Mail-Adresse. Bitte versuche es erneut.\e[0m"
  fi
done

# Überprüfen, ob die Traefik-Konfigurationsdatei existiert
traefik_config_file="data/traefik/traefik.yml"
if [ ! -f "$traefik_config_file" ]; then
  echo -e "\e[31mDie Datei $traefik_config_file existiert nicht. Das Skript wird abgebrochen.\e[0m"
  exit 1
fi

# E-Mail-Adresse in der traefik.yml Datei setzen
sed -i "s/email: \".*\"/email: \"$ssl_email\"/g" "$traefik_config_file"

# Schritt abgeschlossen
step_done "SSL-Zertifikat E-Mail-Adresse gesetzt"
((current_step++))

# Domains, Zertifikatsresolver und optionale Cloudflare-Proxy-Netze konfigurieren
show_step $current_step $total_steps "Konfiguriere Domains und Zertifikatsresolver"

env_file="${SCRIPT_DIR}/.env"
traefik_env_file="${SCRIPT_DIR}/data/traefik/.env"
traefik_config_file="${SCRIPT_DIR}/data/traefik/traefik.yml"

for required_file in "$env_file" "$traefik_env_file" "$traefik_config_file"; do
  if [ ! -f "$required_file" ]; then
    echo -e "${red}Die Datei $required_file existiert nicht. Das Skript wird abgebrochen.${nc}"
    exit 1
  fi
done

validate_domain() {
  local domain_regex="^([a-zA-Z0-9][-a-zA-Z0-9]*\\.)+[a-zA-Z]{2,}$"
  [[ $1 =~ $domain_regex ]]
}

while true; do
  read -p "Bitte gib die Wunsch-Domain für dein Traefik-Dashboard ein (ohne http/https): " dashboard_domain
  dashboard_domain=$(echo "$dashboard_domain" | sed -e 's|^http[s]\\?://||' -e 's|/$||')

  if validate_domain "$dashboard_domain"; then
    read -p "Möchtest du diese Domain verwenden? ($dashboard_domain) [Y/n]: " confirm_domain
    confirm_domain=${confirm_domain:-y}
    confirm_domain=$(echo "$confirm_domain" | tr '[:upper:]' '[:lower:]')
    [ "$confirm_domain" = "y" ] && break
  else
    echo -e "${red}Ungültiges Domain-Format. Bitte versuche es erneut.${nc}"
  fi
done

sed -i 's|^SERVICES_TRAEFIK_LABELS_TRAEFIK_HOST=.*|SERVICES_TRAEFIK_LABELS_TRAEFIK_HOST=HOST(`'"$dashboard_domain"'`)|' "$env_file"

echo "Welcher Zertifikatsresolver soll verwendet werden?"
echo "1) tls_resolver        (TLS-ALPN-01, kein API-Token, keine Wildcards)"
echo "2) cloudflare_resolver (DNS-01, Cloudflare API-Token, Wildcards möglich)"
echo "3) desec_resolver      (DNS-01, deSEC Domain-Token, Wildcards möglich)"
while true; do
  read -p "Bitte wähle den Resolver [1-3]: " resolver_choice
  case "$resolver_choice" in
    1) selected_resolver="tls_resolver"; break ;;
    2) selected_resolver="cloudflare_resolver"; break ;;
    3) selected_resolver="desec_resolver"; break ;;
    *) echo -e "${red}Ungültige Auswahl. Bitte wähle 1, 2 oder 3.${nc}" ;;
  esac
done

sed -i "s/^SERVICES_TRAEFIK_LABELS_TRAEFIK_CERTRESOLVER=.*/SERVICES_TRAEFIK_LABELS_TRAEFIK_CERTRESOLVER=$selected_resolver/" "$env_file"

# Nicht gewählte Provider-Credentials bleiben leer.
sed -i "s|^CF_DNS_API_TOKEN=.*|CF_DNS_API_TOKEN=|" "$traefik_env_file"
sed -i "s|^DESEC_TOKEN=.*|DESEC_TOKEN=|" "$traefik_env_file"

case "$selected_resolver" in
  tls_resolver)
    # TLS-ALPN-01 unterstützt keine Wildcard-Zertifikate.
    sed -i "s/^TRAEFIK_CERT_DOMAIN=.*/TRAEFIK_CERT_DOMAIN=$dashboard_domain/" "$env_file"
    sed -i "s/^TRAEFIK_CERT_WILDCARD=.*/TRAEFIK_CERT_WILDCARD=$dashboard_domain/" "$env_file"
    ;;
  cloudflare_resolver|desec_resolver)
    while true; do
      read -p "Bitte gib die Hauptdomain für das Wildcard-Zertifikat ein (z. B. example.com): " cert_domain
      cert_domain=$(echo "$cert_domain" | sed -e 's|^http[s]\\?://||' -e 's|^\\*\\.||' -e 's|/$||')
      if validate_domain "$cert_domain"; then
        read -p "Zertifikat für $cert_domain und *.$cert_domain konfigurieren? [Y/n]: " confirm_cert_domain
        confirm_cert_domain=${confirm_cert_domain:-y}
        confirm_cert_domain=$(echo "$confirm_cert_domain" | tr '[:upper:]' '[:lower:]')
        [ "$confirm_cert_domain" = "y" ] && break
      else
        echo -e "${red}Ungültiges Domain-Format. Bitte versuche es erneut.${nc}"
      fi
    done
    sed -i "s/^TRAEFIK_CERT_DOMAIN=.*/TRAEFIK_CERT_DOMAIN=$cert_domain/" "$env_file"
    sed -i "s/^TRAEFIK_CERT_WILDCARD=.*/TRAEFIK_CERT_WILDCARD=*.$cert_domain/" "$env_file"

    if [ "$selected_resolver" = "cloudflare_resolver" ]; then
      credential_label="Cloudflare DNS API-Token"
      credential_variable="CF_DNS_API_TOKEN"
    else
      credential_label="deSEC Domain-Token"
      credential_variable="DESEC_TOKEN"
    fi

    while true; do
      read -rsp "Bitte gib den $credential_label ein: " dns_api_token
      echo
      if [[ "$dns_api_token" =~ ^[A-Za-z0-9._-]+$ ]]; then
        read -p "$credential_label übernehmen? [Y/n]: " confirm_dns_token
        confirm_dns_token=${confirm_dns_token:-y}
        confirm_dns_token=$(echo "$confirm_dns_token" | tr '[:upper:]' '[:lower:]')
        [ "$confirm_dns_token" = "y" ] && break
      else
        echo -e "${red}Der Token ist leer oder enthält ungültige Zeichen.${nc}"
      fi
    done

    sed -i "s|^$credential_variable=.*|$credential_variable=$dns_api_token|" "$traefik_env_file"
    unset dns_api_token
    ;;
esac

read -p "Sollen die offiziellen Cloudflare-IP-Netze als trustedIPs für Forwarded Headers eingetragen werden? [y/N]: " add_cloudflare_trusted_ips
add_cloudflare_trusted_ips=${add_cloudflare_trusted_ips:-n}
add_cloudflare_trusted_ips=$(echo "$add_cloudflare_trusted_ips" | tr '[:upper:]' '[:lower:]')

if [ "$add_cloudflare_trusted_ips" = "y" ]; then
  cloudflare_headers_tmp=$(mktemp)
  cat > "$cloudflare_headers_tmp" <<'EOF'
    forwardedHeaders:
      trustedIPs:
        - "173.245.48.0/20"
        - "103.21.244.0/22"
        - "103.22.200.0/22"
        - "103.31.4.0/22"
        - "141.101.64.0/18"
        - "108.162.192.0/18"
        - "190.93.240.0/20"
        - "188.114.96.0/20"
        - "197.234.240.0/22"
        - "198.41.128.0/17"
        - "162.158.0.0/15"
        - "104.16.0.0/13"
        - "104.24.0.0/14"
        - "172.64.0.0/13"
        - "131.0.72.0/22"
        - "2400:cb00::/32"
        - "2606:4700::/32"
        - "2803:f800::/32"
        - "2405:b500::/32"
        - "2405:8100::/32"
        - "2a06:98c0::/29"
        - "2c0f:f248::/32"
EOF
  sed -i "/# __CLOUDFLARE_FORWARDED_HEADERS_WEB__/r $cloudflare_headers_tmp" "$traefik_config_file"
  sed -i "/# __CLOUDFLARE_FORWARDED_HEADERS_WEBSECURE__/r $cloudflare_headers_tmp" "$traefik_config_file"
  rm -f "$cloudflare_headers_tmp"
fi

sed -i '/# __CLOUDFLARE_FORWARDED_HEADERS_WEB__/d' "$traefik_config_file"
sed -i '/# __CLOUDFLARE_FORWARDED_HEADERS_WEBSECURE__/d' "$traefik_config_file"
chmod 600 "$env_file" "$traefik_env_file"

step_done "Domains und Zertifikatsresolver konfiguriert"
((current_step++))

# CrowdSec und Firewall-Konfiguration
show_step $current_step $total_steps "CrowdSec initialisieren und Bouncer registrieren"

if ! docker compose up -d crowdsec; then
  echo -e "${red}CrowdSec konnte nicht gestartet werden.${nc}"
  exit 1
fi

# cscli benötigt eine vollständig initialisierte CrowdSec-Datenbank. Deshalb
# warten wir nicht nur auf den Container-Start, sondern auf den erfolgreichen
# Datenbankzugriff über cscli innerhalb des Containers.
crowdsec_ready=false
for _ in {1..30}; do
  if docker compose exec -T crowdsec cscli bouncers list >/dev/null 2>&1; then
    crowdsec_ready=true
    break
  fi
  sleep 2
done

if [ "$crowdsec_ready" != "true" ]; then
  echo -e "${red}CrowdSec wurde nicht rechtzeitig betriebsbereit.${nc}"
  docker compose logs crowdsec
  docker compose down
  exit 1
fi

# Die zufällig erzeugten Schlüssel müssen zusätzlich in der CrowdSec-LAPI
# registriert werden. Vorhandene Einträge werden ersetzt, damit die in den
# Bouncer-Konfigurationen hinterlegten Schlüssel garantiert übereinstimmen.
if ! docker compose exec -T crowdsec cscli bouncers delete TRAEFIK FIREWALL --ignore-missing \
  || ! docker compose exec -T crowdsec cscli bouncers add TRAEFIK --key "$BOUNCER_KEY_TRAEFIK_PASSWORD" \
  || ! docker compose exec -T crowdsec cscli bouncers add FIREWALL --key "$BOUNCER_KEY_FIREWALL_PASSWORD"; then
  echo -e "${red}Die CrowdSec-Bouncer konnten nicht registriert werden.${nc}"
  docker compose down
  exit 1
fi

echo "Registrierte CrowdSec-Bouncer:"
docker compose exec -T crowdsec cscli bouncers list
docker compose down

step_done "CrowdSec initialisiert und Bouncer registriert"
((current_step++))

show_step $current_step $total_steps "CrowdSec Konfiguration anpassen"
acquis_file="${SCRIPT_DIR}/data/crowdsec/config/acquis.yaml"
if [ ! -f "$acquis_file" ]; then
  echo -e "${red}Die Datei $acquis_file existiert nicht. Das Skript wird abgebrochen.${nc}"
  exit 1
fi

cat <<EOL > "$acquis_file"
filenames:
  - /var/log/auth.log
  - /var/log/syslog
labels:
  type: syslog
---
filenames:
  - /var/log/traefik/access.log
labels:
  type: traefik
---
EOL

# AppSec läuft ausschließlich im CrowdSec-Docker-Netzwerk. Port 7422 wird
# bewusst nicht auf dem Host veröffentlicht.
cp "${SCRIPT_DIR}/data/crowdsec/appsec.yaml.sample" "${SCRIPT_DIR}/data/crowdsec/appsec.yaml"

step_done "acquis.yaml und appsec.yaml bearbeitet"
((current_step++))

# Firewall-Auswahl
show_step $current_step $total_steps "Firewall-Bouncer installieren"
echo "Welche Firewall verwendest du?"
echo "1) UFW"
echo "2) iptables"
echo "3) nftables"
read -p "Bitte wähle die Nummer deiner Firewall (1-3): " firewall_choice

case $firewall_choice in
  1)
    echo "UFW erkannt. Installiere crowdsec-firewall-bouncer-iptables..."
    sudo apt install -y crowdsec-firewall-bouncer-iptables
    ;;
  2)
    echo "iptables erkannt. Installiere crowdsec-firewall-bouncer-iptables..."
    sudo apt install -y crowdsec-firewall-bouncer-iptables
    ;;
  3)
    echo "nftables erkannt. Installiere crowdsec-firewall-bouncer-nftables..."
    sudo apt install -y crowdsec-firewall-bouncer-nftables
    ;;
  *)
    echo -e "${red}Ungültige Auswahl. Das Skript wird abgebrochen.${nc}"
    exit 1
    ;;
esac
step_done "Firewall-Bouncer installiert"
((current_step++))

show_step $current_step $total_steps "Firewall-Bouncer Konfiguration anpassen"
firewall_bouncer_config="/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml"
if [ ! -f "$firewall_bouncer_config" ]; then
  echo -e "${red}Die Datei $firewall_bouncer_config existiert nicht. Das Skript wird abgebrochen.${nc}"
  exit 1
fi

# Setze die api_url und den api_key in der crowdsec-firewall-bouncer.yaml
sudo sed -i "s#api_url: .*#api_url: http://172.31.127.254:8080/#g" "$firewall_bouncer_config"
sudo sed -i "s#api_key: .*#api_key: $BOUNCER_KEY_FIREWALL_PASSWORD#g" "$firewall_bouncer_config"
sudo systemctl enable crowdsec-firewall-bouncer
sudo systemctl restart crowdsec-firewall-bouncer
step_done "Firewall-Bouncer angepasst"
((current_step++))

# Dashboard-Benutzer erstellen
show_step $current_step $total_steps "Erstelle Benutzer für Traefik-Dashboard"
htpasswd_file="${SCRIPT_DIR}/data/traefik/.htpasswd"

# Ein von Docker irrtümlich angelegtes, leeres Bind-Mount-Verzeichnis entfernen.
if [ -d "$htpasswd_file" ]; then
  if ! rmdir "$htpasswd_file"; then
    echo -e "${red}$htpasswd_file ist ein nicht leeres Verzeichnis und kann nicht als htpasswd-Datei verwendet werden.${nc}"
    exit 1
  fi
fi

while true; do
  read -p "Bitte gib den gewünschten Benutzernamen für das Dashboard ein: " dashboard_user
  if [[ "$dashboard_user" =~ ^[A-Za-z0-9._-]+$ ]]; then
    break
  fi
  echo -e "${red}Der Benutzername darf nur Buchstaben, Zahlen, Punkt, Unterstrich und Bindestrich enthalten.${nc}"
done

echo "Bitte gib das Passwort zweimal ein:"
if ! htpasswd -cB "$htpasswd_file" "$dashboard_user"; then
  echo -e "${red}Die htpasswd-Datei konnte nicht erstellt werden.${nc}"
  exit 1
fi

chmod 600 "$htpasswd_file"
if [ ! -s "$htpasswd_file" ] || [ ! -f "$htpasswd_file" ]; then
  echo -e "${red}$htpasswd_file wurde nicht als gültige Datei erstellt.${nc}"
  exit 1
fi
step_done "Dashboard-Benutzer erstellt"
((current_step++))

# Eigentümer der vom Installer erzeugten Projektdateien korrigieren
show_step $current_step $total_steps "Setze Eigentümer der Projektdateien"

chown -R "$install_user:$install_group" \
  "${SCRIPT_DIR}/data"

chown "$install_user:$install_group" \
  "${SCRIPT_DIR}/.env"

step_done "Eigentümer der Projektdateien gesetzt"
((current_step++))

# Letzter Hinweis und Stack starten
show_step $current_step $total_steps "Finale Überprüfung der Firewall und Domain"
read -p "Hast du die Ports und die Domain überprüft und sind sie korrekt? [y/n, Standard: n]: " confirmation
confirmation=${confirmation:-n}  # Setzt Standardwert auf 'n', wenn keine Eingabe erfolgt

if [[ "$confirmation" =~ ^[Yy]$ ]]; then
  echo "Starte den Stack..."
  sudo -u "$install_user" docker compose \
    --project-directory "$SCRIPT_DIR" \
    up -d --remove-orphans
  step_done "Stack gestartet"
else
  echo -e "${red}Bitte überprüfe die Firewall und die Domain-Einstellungen, bevor du den Stack startest.${nc}"
fi
