# Traefik-CrowdSec-Stacks

Dieser Stack kombiniert Traefik mit CrowdSec und dessen AppSec/WAF. Die frühere
`traefik-crowdsec-bouncer`-Sidecar-Anwendung wurde vollständig entfernt. Die
Prüfung übernimmt direkt das
[`crowdsec-bouncer-traefik-plugin`](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin)
in Version `v1.7.1`.

Als Reverse Proxy wird standardmäßig Traefik `v3.7` verwendet. Optional
können Zertifikate über eine Cloudflare-DNS-Challenge ausgestellt und
Cloudflare-Proxy-Verbindungen mit verifizierten Forwarded Headers verarbeitet
werden.

AppSec lauscht auf `crowdsec:7422`. Dieser Port wird nicht auf dem Host
veröffentlicht und ist nur zwischen Traefik und CrowdSec im gemeinsamen
Docker-Netzwerk erreichbar.

Bei einem Update von einer älteren Version entfernt der folgende Startbefehl
auch den nicht mehr definierten Sidecar-Container als Compose-Orphan:

```bash
docker compose up -d --remove-orphans
```

## Voraussetzungen

- Root-Zugriff auf den Server
- Docker und Docker Compose müssen installiert sein
- Apache2 Utils (htpasswd) und OpenSSL müssen installiert sein

## Script
![Ubuntu 20.04 - Testing](https://img.shields.io/badge/Ubuntu_20.04-07--10--2024-orange?logo=ubuntu)
![Ubuntu 22.04 - Testing](https://img.shields.io/badge/Ubuntu_22.04-07--10--2024-orange?logo=ubuntu)
![Ubuntu 24.04 - Testing](https://img.shields.io/badge/Ubuntu_24.04-07--10--2024-orange?logo=ubuntu)
![Debian 11 - Testing](https://img.shields.io/badge/Debian_11_(Bullseye)-07--10--2024-A81D33?logo=debian&logoColor=white)
![Debian 12 - Testing](https://img.shields.io/badge/Debian_12_(Bookworm)-07--10--2024-A81D33?logo=debian&logoColor=white)
### 1. Repository klonen

Als erstes müssen Sie das Repository auf Ihren Server klonen:

```bash
mkdir -p /opt/containers/
git clone https://github.com/happylippo/traefik-crowdsec-stack /opt/containers/traefik-crowdsec-stack
cd /opt/containers/traefik-crowdsec-stack
sudo chmod +x first_install.sh
sudo ./first_install.sh
```

Das Installationsskript fragt interaktiv nach Dashboard-Domain,
Zertifikatsresolver, Zertifikats-Hauptdomain sowie Benutzername und Passwort für
das Traefik-Dashboard. Zur Auswahl stehen `tls_resolver`,
`cloudflare_resolver` und `desec_resolver`. Nur für den gewählten
DNS-Challenge-Resolver wird der zugehörige Token verdeckt abgefragt und
ausschließlich in `data/traefik/.env` gespeichert. Zusätzlich kann ausgewählt
werden, ob die offiziellen Cloudflare-Netze als vertrauenswürdige Forwarded-
Header-Proxys in Traefik eingetragen werden sollen.

## Manuelle Anleitung
![Ubuntu 20.04 - Testing](https://img.shields.io/badge/Ubuntu_20.04-07--10--2024-orange?logo=ubuntu)
![Ubuntu 22.04 - Testing](https://img.shields.io/badge/Ubuntu_22.04-07--10--2024-orange?logo=ubuntu)
![Ubuntu 24.04 - Testing](https://img.shields.io/badge/Ubuntu_24.04-07--10--2024-orange?logo=ubuntu)
![Debian 11 - Testing](https://img.shields.io/badge/Debian_11_(Bullseye)-07--10--2024-A81D33?logo=debian&logoColor=white)
![Debian 12 - Testing](https://img.shields.io/badge/Debian_12_(Bookworm)-07--10--2024-A81D33?logo=debian&logoColor=white)

Die gesamte Anleitung wird als `root`-User durchgeführt!
### 1. Repository klonen
Als erstes müssen Sie das Repository auf Ihren Server klonen:

```bash
sudo su
mkdir -p /opt/containers/
git clone https://github.com/happylippo/traefik-crowdsec-stack /opt/containers/traefik-crowdsec-stack
cd /opt/containers/traefik-crowdsec-stack
```

### 2. Docker und Docker Compose installieren

Falls Docker und Docker Compose noch nicht installiert sind, folgen Sie der offiziellen Anleitung:

- [Docker Installation](https://docs.docker.com/engine/install)
- [Docker Compose Installation](https://docs.docker.com/engine/install)

Verifizieren Sie die Installation mit den folgenden Befehlen:

```bash
docker --version
docker compose version
```

### 3. Apache2 Utils und OpenSSL installieren

Um einen Benutzer für die HTTP-Basic-Authentifizierung zu erstellen, benötigen Sie htpasswd, das in apache2-utils enthalten ist. Sie können es mit folgendem Befehl installieren:

```bash
apt update
apt install -y apache2-utils openssl
```

### 4. Konfigurationsdateien kopieren

Kopieren Sie die erforderlichen Konfigurationsdateien aus den .sample-Vorlagen. Stellen Sie sicher, dass Sie im Arbeitsverzeichnis des Projekts sind:

```bash
cp .env.sample .env
cp data/crowdsec/.env.sample data/crowdsec/.env
cp data/crowdsec/appsec.yaml.sample data/crowdsec/appsec.yaml
cp data/socket-proxy/.env.sample data/socket-proxy/.env
cp data/traefik/.env.sample data/traefik/.env
cp data/traefik/traefik.yml.sample data/traefik/traefik.yml
cp data/traefik/certs/acme_letsencrypt.json.sample data/traefik/certs/acme_letsencrypt.json
chmod 600 data/traefik/certs/acme_letsencrypt.json
cp data/traefik/certs/acme_cloudflare.json.sample data/traefik/certs/acme_cloudflare.json
chmod 600 data/traefik/certs/acme_cloudflare.json
cp data/traefik/certs/acme_desec.json.sample data/traefik/certs/acme_desec.json
chmod 600 data/traefik/certs/acme_desec.json
cp data/traefik/certs/tls_letsencrypt.json.sample data/traefik/certs/tls_letsencrypt.json
chmod 600 data/traefik/certs/tls_letsencrypt.json
cp data/traefik/dynamic_conf/http.middlewares.default.yml.sample data/traefik/dynamic_conf/http.middlewares.default.yml
cp data/traefik/dynamic_conf/http.middlewares.default-security-headers.yml.sample data/traefik/dynamic_conf/http.middlewares.default-security-headers.yml
cp data/traefik/dynamic_conf/http.middlewares.gzip.yml.sample data/traefik/dynamic_conf/http.middlewares.gzip.yml
cp data/traefik/dynamic_conf/http.middlewares.traefik-dashboard-auth.yml.sample data/traefik/dynamic_conf/http.middlewares.traefik-dashboard-auth.yml
cp data/traefik/dynamic_conf/tls.yml.sample data/traefik/dynamic_conf/tls.yml
cp data/traefik/.htpasswd.sample data/traefik/.htpasswd
chmod 600 data/traefik/.htpasswd
```

### 5. SSL-Zertifikate und Domain konfigurieren

Fügen Sie Ihre SSL-Zertifikats-E-Mail-Adresse und die gewünschte Domain für das Traefik-Dashboard in die entsprechenden Konfigurationsdateien ein:

1.	Bearbeiten Sie die `data/traefik/traefik.yml` und ersetzen Sie die E-Mail-Adressen (die Adressen **müssen** identisch sein):
    ```yaml
    certificatesResolvers:
      http_resolver:
        acme:
          email: "deine@email.de"
          storage: "/etc/traefik/acme_letsencrypt.json"
          keyType: EC384
          httpChallenge:
            entryPoint: web
      tls_resolver:
        acme:
          email: "deine@email.de"
          storage: "/etc/traefik/tls_letsencrypt.json"
          keyType: EC384
          tlsChallenge: {}
      cloudflare_resolver:
        acme:
          email: "deine@email.de"
          storage: "/etc/traefik/acme_cloudflare.json"
          keyType: EC384
          dnsChallenge:
            provider: cloudflare
            resolvers:
              - "1.1.1.1:53"
              - "1.0.0.1:53"
      desec_resolver:
        acme:
          email: "deine@email.de"
          storage: "/etc/traefik/acme_desec.json"
          keyType: EC384
          dnsChallenge:
            provider: desec
            resolvers:
              - "1.1.1.1:53"
              - "1.0.0.1:53"
    ```

2.	In der Datei `.env` setzen Sie die gewünschte Domain und das Wildcardzertifikat für das Traefik-Dashboard:

    ```bash
    SERVICES_TRAEFIK_LABELS_TRAEFIK_HOST=HOST(`traefik.yourdomain.com`)
    TRAEFIK_CERT_DOMAIN=example.com
    TRAEFIK_CERT_WILDCARD=*.example.com
    ```

### Zertifikatsresolver auswählen

Der vom Dashboard-Router verwendete Resolver wird in der Hauptdatei `.env`
festgelegt:

```dotenv
SERVICES_TRAEFIK_LABELS_TRAEFIK_CERTRESOLVER=tls_resolver
```

Erlaubte Werte dieses Stacks sind:

- `tls_resolver`: TLS-ALPN-01 über Port 443; benötigt keinen DNS-API-Token,
  unterstützt aber keine Wildcard-Zertifikate. Hauptdomain und SAN werden daher
  beide auf die konkrete Dashboard-Domain gesetzt.
- `cloudflare_resolver`: DNS-01 über Cloudflare; unterstützt Hauptdomain und
  Wildcard-SAN.
- `desec_resolver`: DNS-01 über deSEC; unterstützt Hauptdomain und
  Wildcard-SAN.

Für `tls_resolver` sollte nur die konkrete Dashboard-Domain gesetzt werden:

```dotenv
TRAEFIK_CERT_DOMAIN=traefik.example.com
TRAEFIK_CERT_WILDCARD=traefik.example.com
```

Für einen DNS-Challenge-Resolver können Hauptdomain und Wildcard verwendet
werden:

```dotenv
TRAEFIK_CERT_DOMAIN=example.com
TRAEFIK_CERT_WILDCARD=*.example.com
```

#### Cloudflare DNS-Challenge

Erstellen Sie ein auf die benötigte Zone eingeschränktes API-Token mit:

- `Zone / DNS / Edit`
- `Zone / Zone / Read`

Tragen Sie ausschließlich in `data/traefik/.env` ein:

```dotenv
CF_DNS_API_TOKEN=dein_cloudflare_api_token
DESEC_TOKEN=
```

Und wählen Sie in `.env`:

```dotenv
SERVICES_TRAEFIK_LABELS_TRAEFIK_CERTRESOLVER=cloudflare_resolver
```

#### deSEC DNS-Challenge

Erstellen Sie bei deSEC einen Domain-Token für die betreffende Zone. Der
deSEC-Provider von Traefik beziehungsweise Lego verwendet die Variable
`DESEC_TOKEN`. Tragen Sie ausschließlich in `data/traefik/.env` ein:

```dotenv
CF_DNS_API_TOKEN=
DESEC_TOKEN=dein_desec_domain_token
```

Und wählen Sie in `.env`:

```dotenv
SERVICES_TRAEFIK_LABELS_TRAEFIK_CERTRESOLVER=desec_resolver
```

Für jeden Resolver gilt: Seine ACME-Speicherdatei muss vorhanden sein, mit
`chmod 600` geschützt und in den Traefik-Container gemountet werden. Die
mitgelieferten Compose- und Sample-Dateien berücksichtigen
`tls_letsencrypt.json`, `acme_cloudflare.json` und `acme_desec.json`.

Nach einer Änderung Traefik neu erstellen und das Log kontrollieren:

```bash
docker compose up -d --force-recreate traefik
docker compose logs --tail=100 traefik
```

### Cloudflare als Reverse Proxy

Die Cloudflare-Netze für `forwardedHeaders.trustedIPs` sind in
`data/traefik/traefik.yml.sample` nicht standardmäßig aktiviert. Das
Installationsskript fragt, ob sie in die erzeugte `data/traefik/traefik.yml`
eingetragen werden sollen. Diese Auswahl ist unabhängig vom Zertifikatsresolver:
Cloudflare kann beispielsweise als Proxy verwendet werden, während deSEC die
DNS-Challenge übernimmt.

Für die manuelle Konfiguration fügen Sie unter den EntryPoints `web` und
`websecure` jeweils folgenden Block ein:

```yaml
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
```

Die Netze stammen aus den offiziellen Listen:

- [Cloudflare IPv4 ranges](https://www.cloudflare.com/ips-v4)
- [Cloudflare IPv6 ranges](https://www.cloudflare.com/ips-v6)

Vergleichen Sie die Listen bei Updates mit Ihrer lokalen
`data/traefik/traefik.yml`. Vertrauen in Forwarded Headers verhindert keinen
direkten Zugriff auf die Origin-IP. Soll der Origin ausschließlich über
Cloudflare erreichbar sein, müssen TCP 80/443 und gegebenenfalls UDP 443
zusätzlich in Host- und Provider-Firewall auf Cloudflares Netze beschränkt
werden.

### 6. CrowdSec konfigurieren
1. CrowdSec Konfigurationsdatein erstellen
    ```bash
    cd /opt/containers/traefik-crowdsec-stack/
    docker compose up -d crowdsec && docker compose down
    ```

2.	Acquis.yaml anpassen: Bearbeiten Sie die `/opt/containers/traefik-crowdsec-stack/data/crowdsec/config/acquis.yaml`, löschen Sie alle Zeilen und fügen Sie die folgenden Zeilen hinzu:
    ```yaml
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
    ```

3. API-Schlüssel für das Traefik-Plugin und den optionalen Firewall-Bouncer erzeugen:
    ```bash
    BOUNCER_KEY_TRAEFIK=$(openssl rand -hex 32)
    BOUNCER_KEY_FIREWALL=$(openssl rand -hex 32)
    sed -i "s/^BOUNCER_KEY_TRAEFIK=.*/BOUNCER_KEY_TRAEFIK=$BOUNCER_KEY_TRAEFIK/" .env
    sed -i "s/^BOUNCER_KEY_FIREWALL=.*/BOUNCER_KEY_FIREWALL=$BOUNCER_KEY_FIREWALL/" .env
    umask 077
    sed "s/__BOUNCER_KEY_TRAEFIK__/$BOUNCER_KEY_TRAEFIK/" \
      data/traefik/dynamic_conf/http.middlewares.crowdsec.yml.sample \
      > data/traefik/dynamic_conf/http.middlewares.crowdsec.yml
    chmod 600 data/traefik/dynamic_conf/http.middlewares.crowdsec.yml
    ```
4. Speichern Sie sich den Wert von `BOUNCER_KEY_FIREWALL`; dieser wird für den
   optionalen Firewall-Bouncer benötigt. Der Traefik-Schlüssel wird als
   `crowdsecLapiKey` in die lokale, nicht versionierte Middleware-Datei
   geschrieben. Traefiks File-Provider ersetzt keine Umgebungsvariablen in
   dynamischen YAML-Dateien; deshalb muss die Datei vor dem Start aus der
   Vorlage erzeugt werden. Prüfen Sie vor einem Commit mit `git status`, dass
   `data/traefik/dynamic_conf/http.middlewares.crowdsec.yml` ignoriert bleibt.

5. Die beiden AppSec-Collections sind in `data/crowdsec/.env` bereits aktiviert:

    ```text
    crowdsecurity/appsec-virtual-patching
    crowdsecurity/appsec-generic-rules
    ```

6. `data/crowdsec/appsec.yaml` aktiviert die Standardkonfiguration und den
   internen Listener:

    ```yaml
    appsec_configs:
      - crowdsecurity/appsec-default
    labels:
      type: appsec
    listen_addr: 0.0.0.0:7422
    source: appsec
    ```

### AppSec-Verfügbarkeit und Notfallbetrieb

Die Middleware `data/traefik/dynamic_conf/http.middlewares.crowdsec.yml` ist
standardmäßig für den Produktionsbetrieb auf **fail closed** eingestellt:

```yaml
crowdsecAppsecFailureBlock: true
crowdsecAppsecUnreachableBlock: true
```

Antwortet AppSec mit einem internen Fehler oder ist `crowdsec:7422` nicht
erreichbar, blockiert Traefik daher die Anfrage. Das verhindert ein unbemerktes
Umgehen des WAF, kann bei einem CrowdSec-Ausfall aber auch legitimen Verkehr
stoppen.

Nur für einen zeitlich begrenzten Notfall können beide Werte auf `false` gesetzt
und Traefik anschließend neu geladen werden:

```bash
sed -i 's/crowdsecAppsecFailureBlock: true/crowdsecAppsecFailureBlock: false/' data/traefik/dynamic_conf/http.middlewares.crowdsec.yml
sed -i 's/crowdsecAppsecUnreachableBlock: true/crowdsecAppsecUnreachableBlock: false/' data/traefik/dynamic_conf/http.middlewares.crowdsec.yml
docker compose restart traefik
```

Damit arbeitet das System vorübergehend **fail open**. Nach Behebung des
AppSec-Problems müssen beide Werte wieder auf `true` gesetzt und Traefik erneut
geladen werden.

Die AppSec-Verbindung verwendet innerhalb des Docker-Netzwerks bewusst
`http://crowdsec:7422`. Für diesen Port wird keine TLS- oder mTLS-Konfiguration
vorausgesetzt; insbesondere werden keine Client-Zertifikate benötigt.

### 7. Benutzer und Passwort für das Dashboard erstellen

Erstellen Sie einen Benutzer und ein Passwort für die HTTP-Basic-Authentifizierung im Traefik-Dashboard:

```bash
htpasswd -cB data/traefik/.htpasswd <deinBenutzername>
```

### 8. Firewall Bouncer (optional)
1. Installieren Sie die Repositories von CrowdSec
    ```bash
    curl -s https://install.crowdsec.net | sudo sh
    ```
2. Installieren Sie den Service für Ihre Firewall

    **IPTables und UFW**
    ```bash
    sudo apt install crowdsec-firewall-bouncer-iptables
    ```
    **NFTables**
    ```bash
    sudo apt install crowdsec-firewall-bouncer-nftables
    ```

3.	Firewall-Konfiguration anpassen: Bearbeiten Sie die Datei `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`:
    ```
    api_url: http://172.31.127.254:8080/
    api_key: <BOUNCER_KEY_FIREWALL>
    ```
Der `BOUNCER_KEY_FIREWALL` sollte der Wert sein, den Sie generiert haben (in Schritt 6.3.).

4. Firewall neustarten
    ```
    systemctl enable crowdsec-firewall-bouncer
    systemctl restart crowdsec-firewall-bouncer
    ```
### 9. Firwall UFW-Docker (optional)

Wenn ufw-docker installiert ist kann folgendes freigegeben werden:

```bash
sudo ufw-docker allow traefik 443/tcp proxy
sudo ufw-docker allow traefik 443/tcp crowdsec
sudo ufw-docker allow traefik 443/udp proxy
sudo ufw-docker allow traefik 443/udp crowdsec
```

### 10. Firewall-Ports überprüfen

Stellen Sie sicher, dass die Firewall die Ports 80 (HTTP) und 443 (HTTPS) freigibt.

### 11. Domain überprüfen

Vergewissern Sie sich, dass die von Ihnen gewählte Domain korrekt auf die IP-Adresse des Servers verweist.

### 12. Stack starten

Sobald alle Konfigurationen abgeschlossen sind, können Sie den Stack starten:

```bash
docker compose up -d --remove-orphans
```

### 13. Zugriff auf das Traefik-Dashboard

Das Traefik-Dashboard sollte nun über die von Ihnen konfigurierte Domain erreichbar sein. Sie werden zur Eingabe des HTTP-Basic-Auth-Benutzernamens und Passworts aufgefordert.

https://traefik.yourdomain.com
