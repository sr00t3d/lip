[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# lip

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/lip/releases/tag/v2.0.0)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requirements)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20cPanel-lightgrey.svg)](#requirements)

**Multi-Protocol Last Login IP Forensics CLI for Linux & cPanel Servers.**

`lip.sh` searches across **cPanel/WHM** (`access_log` & `login_log`), **SSH** (`/var/log/secure`, `auth.log`, `journalctl`), **FTP** (Pure-FTPd, ProFTPD, vsftpd), and **Mail** (Dovecot IMAP/POP3) — including rotated `.gz` archives — to surface the last `N` login IP addresses and timestamps for a user in seconds.

> **Historical Inspiration:** Clean-room Bash + Python 3.6+ `v2.0.0` reimplementation inspired by `lip` (2011–2013, eechter / HostGator). Fixes legacy `getopts` bugs, replaces unsafe `eval`/`ls` pipelines, adds `/var/log/secure`, `journalctl`, cPanel `login_log`, Dovecot mail logs, `--unique` IP aggregation, and `table`/`json`/`csv` outputs.

---

## Protocols & Log Sources

| Protocol | Default Log Sources |
|---|---|
| `cpanel` | `/usr/local/cpanel/logs/access_log`, `/usr/local/cpanel/logs/login_log` (+ `archive/*.gz` with `-a`) |
| `ssh` | `/var/log/secure`, `/var/log/auth.log`, `/var/log/messages`, `journalctl -u sshd` |
| `ftp` | Pure-FTPd / vsftpd / ProFTPD in `/var/log/messages`, `/var/log/syslog`, `/var/log/vsftpd.log` |
| `mail` | Dovecot IMAP/POP3 in `/var/log/maillog`, `/var/log/mail.log` |

---

## Requirements

- Linux with Bash 4.0+ and Python 3.6+
- Root privileges recommended for reading `/usr/local/cpanel/logs/` and `/var/log/secure`

---

## Usage

```bash
# Show last 5 logins per protocol for a cPanel user
./lip.sh -u percio

# Show last 10 logins including rotated .gz archives
./lip.sh percio -l 10 -a

# Aggregate unique IPs with hit counts for cPanel and SSH only
./lip.sh -u percio --proto cpanel,ssh --unique

# Export JSON or CSV for incident-response reports
./lip.sh -u root -l 10 -o json
./lip.sh -u percio -l 20 -a -o csv

# Analyze offline forensic log dumps (plain or .gz)
./lip.sh -u percio --no-user-check --cpanel-log ./access_log.gz --ssh-log ./secure.gz
```

### Options

| Flag | Description |
|---|---|
| `-u, --user <user>` | Target username (or email user for mail logs) |
| `-l, --last <N>` | Max entries per protocol (default: `5`) |
| `-a, --archives` | Include rotated and `.gz` archived logs |
| `--proto <list>` | Comma-separated protocols: `cpanel,ssh,ftp,mail` (default: all) |
| `--unique` | Deduplicate by `(protocol, IP)` with hit count and latest timestamp |
| `--cpanel-log <path>` | Custom cPanel log file (`.log` or `.gz`) |
| `--ssh-log <path>` | Custom SSH log file (`.log` or `.gz`) |
| `--ftp-log <path>` | Custom FTP log file (`.log` or `.gz`) |
| `--mail-log <path>` | Custom Mail log file (`.log` or `.gz`) |
| `--no-user-check` | Skip local `/etc/passwd` user existence check |
| `-o, --output <fmt>` | Output format: `table` (default), `json`, `csv` |
| `-q, --quiet` | Suppress header banner |
| `--no-color` | Disable ANSI colors |
| `-V, --version` | Show version and exit |
| `-h, --help` | Show help and exit |

---

## Direct Execution

Run directly without cloning the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/lip/main/lip.sh) -u root -l 5
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/lip/main/lip.sh) percio -l 10 -a --unique
```

---

## Real Output Example

```text
================================================================================================
 lip.sh v2.0.0 | Last Login IP Forensics | User: percio | Last: 5 | 2026-11-22T04:05:00Z
================================================================================================
PROTO    IP ADDRESS           TIMESTAMP                    HITS   SOURCE             DETAIL
-------- -------------------- ---------------------------- ------ ------------------ --------------------
cpanel   203.0.113.42         11/21/2026:21:11:05 -0000    3      access_log.gz      HTTP 200
ssh      198.51.100.10        Nov 21 21:05:12              2      secure.gz          Accepted publickey
ftp      203.0.113.42         Nov 21 20:55:01              1      messages.gz        Pure-FTPd
mail     192.0.2.55           Nov 21 20:40:19              1      maillog.gz         imap-login (percio@example.com)

Summary: 4 entry(ies) | 3 unique IP(s): 192.0.2.55, 198.51.100.10, 203.0.113.42
```

---

## Author & License

- **Author:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Project Page:** [perciocastelo.com.br/projetos/en/lip.html](https://perciocastelo.com.br/projetos/en/lip.html)
- **License:** [Apache-2.0](LICENSE)
