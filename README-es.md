[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# lip

![Portada de lip](lip-cover.webp)

[![Versión](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/lip/releases/tag/v2.0.0)
[![Licencia](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requisitos)
[![Plataforma](https://img.shields.io/badge/platform-Linux%20%7C%20cPanel-lightgrey.svg)](#requisitos)

**CLI forense multiprotocolo para rastrear las últimas IPs de inicio de sesión en Linux y cPanel.**

`lip.sh` inspecciona logs de **cPanel/WHM** (`access_log` y `login_log`), **SSH** (`/var/log/secure`, `auth.log`, `journalctl`), **FTP** (Pure-FTPd, ProFTPD, vsftpd) y **Mail** (Dovecot IMAP/POP3) — incluidos archivos comprimidos `.gz` — mostrando las últimas `N` IPs y marcas de tiempo de acceso de un usuario.

> **Inspiración Histórica:** Reimplementación clean-room en Bash + Python 3.6+ `v2.0.0` inspirada en el clásico `lip` (2011–2013, eechter / HostGator).

---

## Requisitos

- Linux con Bash 4.0+ y Python 3.6+
- Privilegios de `root` recomendados para leer `/usr/local/cpanel/logs/` y `/var/log/secure`

---

## Uso

```bash
# Últimos 5 inicios de sesión por protocolo
./lip.sh -u percio

# Últimos 10 accesos incluyendo logs archivados .gz
./lip.sh percio -l 10 -a

# Agrupar IPs únicas con conteo en cPanel y SSH
./lip.sh -u percio --proto cpanel,ssh --unique

# Exportar en JSON o CSV
./lip.sh -u root -l 10 -o json
./lip.sh -u percio -l 20 -a -o csv
```

---

## Ejecución Directa

Ejecuta directamente sin clonar el repositorio:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/lip/main/lip.sh) -u root -l 5
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/lip/main/lip.sh) percio -l 10 -a --unique
```

---

## Autor y Licencia

- **Autor:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Página del Proyecto:** [perciocastelo.com.br/projetos/en/lip.html](https://perciocastelo.com.br/projetos/en/lip.html)
- **Licencia:** [Apache-2.0](LICENSE)
