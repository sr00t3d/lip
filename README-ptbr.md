[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# lip

![Capa do lip](lip-cover.webp)

[![Versão](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/lip/releases/tag/v2.0.0)
[![Licença](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requisitos)
[![Plataforma](https://img.shields.io/badge/platform-Linux%20%7C%20cPanel-lightgrey.svg)](#requisitos)

**CLI forense multiprotocolo para rastrear os últimos IPs de login em servidores Linux e cPanel.**

O `lip.sh` analisa os logs de **cPanel/WHM** (`access_log` e `login_log`), **SSH** (`/var/log/secure`, `auth.log`, `journalctl`), **FTP** (Pure-FTPd, ProFTPD, vsftpd) e **Mail** (Dovecot IMAP/POP3) — incluindo arquivos rotacionados `.gz` — para listar os últimos `N` IPs e timestamps de acesso de um usuário em segundos.

> **Inspiração Histórica:** Reimplementação clean-room em Bash + Python 3.6+ `v2.0.0` inspirada no clássico `lip` (2011–2013, eechter / HostGator). Corrige bugs do `getopts` legado, elimina `eval`/`ls` inseguros, adiciona `/var/log/secure`, `journalctl`, `login_log`, Dovecot IMAP/POP3, agregação `--unique` e saídas `table`/`json`/`csv`.

---

## Protocolos e Fontes de Log

| Protocolo | Fontes Padrão |
|---|---|
| `cpanel` | `/usr/local/cpanel/logs/access_log`, `/usr/local/cpanel/logs/login_log` (+ `archive/*.gz` com `-a`) |
| `ssh` | `/var/log/secure`, `/var/log/auth.log`, `/var/log/messages`, `journalctl -u sshd` |
| `ftp` | Pure-FTPd / vsftpd / ProFTPD em `/var/log/messages`, `/var/log/syslog`, `/var/log/vsftpd.log` |
| `mail` | Dovecot IMAP/POP3 em `/var/log/maillog`, `/var/log/mail.log` |

---

## Requisitos

- Linux com Bash 4.0+ e Python 3.6+
- Privilégios de `root` recomendados para leitura de `/usr/local/cpanel/logs/` e `/var/log/secure`

---

## Como Usar

```bash
# Últimos 5 logins por protocolo de um usuário cPanel
./lip.sh -u percio

# Últimos 10 logins incluindo logs arquivados .gz
./lip.sh percio -l 10 -a

# Agrupar IPs únicos com contagem de acessos em cPanel e SSH
./lip.sh -u percio --proto cpanel,ssh --unique

# Exportar em JSON ou CSV para resposta a incidentes
./lip.sh -u root -l 10 -o json
./lip.sh -u percio -l 20 -a -o csv

# Analisar dumps forenses offline (.log ou .gz)
./lip.sh -u percio --no-user-check --cpanel-log ./access_log.gz --ssh-log ./secure.gz
```

---

## Execução Direta

Execute diretamente sem clonar o repositório:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/lip/main/lip.sh) -u root -l 5
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/lip/main/lip.sh) percio -l 10 -a --unique
```

---

## Autor e Licença

- **Autor:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Página do Projeto:** [perciocastelo.com.br/projetos/br/lip.html](https://perciocastelo.com.br/projetos/br/lip.html)
- **Licença:** [Apache-2.0](LICENSE)
