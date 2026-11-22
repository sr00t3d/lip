#!/usr/bin/env bash
# ==============================================================================
#  lip.sh — Multi-Protocol Last Login IP Forensics CLI (cPanel / SSH / FTP / Mail)
# ==============================================================================
#  Author  : Percio Castelo <percio@perciocastelo.com.br>
#  Website : https://perciocastelo.com.br
#  Project : https://perciocastelo.com.br/projetos/en/lip.html
#  Repo    : https://github.com/sr00t3d/lip
#  License : Apache-2.0
#  Version : 2.0.0
#  Notes   : Clean-room Bash + Python 3.6+ reimplementation inspired by `lip`
#            (2011-2013, eechter / HostGator). Searches cPanel (`access_log` +
#            `login_log`), SSH (`/var/log/secure`, `auth.log`, `journalctl`),
#            FTP (Pure-FTPd/ProFTPD/vsftpd), and Mail (Dovecot IMAP/POP3) logs
#            — including `.gz` archives — with `--unique`, `--proto`, custom
#            log overrides, and `table`, `json`, `csv` outputs.
# ==============================================================================

set -uo pipefail
export LC_ALL=C

readonly SCRIPT_NAME="lip.sh"
readonly SCRIPT_VERSION="2.0.0"

# Defaults
TARGET_USER=""
NUM_LAST=5
ARCHIVES=0
PROTOS="cpanel,ssh,ftp,mail"
UNIQUE_MODE=0
CPANEL_LOG=""
SSH_LOG=""
FTP_LOG=""
MAIL_LOG=""
SKIP_USER_CHECK=0
FORMAT="table"
QUIET=0
NO_COLOR=0
TIMESTAMP_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Colors
RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""

init_colors() {
  if [[ "$NO_COLOR" -eq 0 && -t 1 && -z "${NO_COLOR:-}" && "$FORMAT" == "table" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
  else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
  fi
}

show_help() {
  cat <<'USAGE'
lip.sh v2.0.0 — Multi-Protocol Last Login IP Forensics CLI (cPanel / SSH / FTP / Mail)

Usage:
  lip.sh -u <username> [options]
  lip.sh <username> [options]

Protocols (--proto):
  cpanel    /usr/local/cpanel/logs/access_log & login_log (+ archive/*.gz with -a)
  ssh       /var/log/secure, /var/log/auth.log, /var/log/messages, journalctl sshd
  ftp       Pure-FTPd, ProFTPD, vsftpd (/var/log/messages, syslog, vsftpd.log)
  mail      Dovecot IMAP/POP3 (/var/log/maillog, /var/log/mail.log)

Options:
  -u, --user <user>        Target username (or email user for mail logs)
  -l, --last <N>           Max entries per protocol (default: 5)
  -a, --archives           Include rotated and .gz archived logs
  --proto <list>           Comma-separated protocols: cpanel,ssh,ftp,mail (default: all)
  --unique                 Deduplicate by (protocol, IP) showing hit count & latest timestamp
  --cpanel-log <path>      Custom cPanel log file (.log or .gz)
  --ssh-log <path>         Custom SSH log file (.log or .gz)
  --ftp-log <path>         Custom FTP log file (.log or .gz)
  --mail-log <path>        Custom Mail log file (.log or .gz)
  --no-user-check          Do not require <user> to exist in local /etc/passwd
  -o, --output <fmt>       Output format: table (default), json, csv
  -q, --quiet              Suppress banner header
  --no-color               Disable ANSI colors
  -V, --version            Show version and exit
  -h, --help               Show this help and exit

Examples:
  lip.sh -u percio
  lip.sh percio -l 10 -a
  lip.sh -u percio --proto cpanel,ssh --unique
  lip.sh -u root -l 5 -o json
USAGE
}

main() {
  command -v python3 >/dev/null 2>&1 || { printf '[ERR] python3 is required.\n' >&2; exit 1; }
  [[ "$#" -eq 0 ]] && { show_help; exit 1; }

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)        show_help; exit 0 ;;
      -V|--version)     printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
      -u|--user)        TARGET_USER="${2:-}"; shift 2 ;;
      -l|--last)        NUM_LAST="${2:-5}"; shift 2 ;;
      -a|--archives)    ARCHIVES=1; shift ;;
      --proto)          PROTOS="${2:-cpanel,ssh,ftp,mail}"; shift 2 ;;
      --unique)         UNIQUE_MODE=1; shift ;;
      --cpanel-log)     CPANEL_LOG="${2:-}"; shift 2 ;;
      --ssh-log)        SSH_LOG="${2:-}"; shift 2 ;;
      --ftp-log)        FTP_LOG="${2:-}"; shift 2 ;;
      --mail-log)       MAIL_LOG="${2:-}"; shift 2 ;;
      --no-user-check)  SKIP_USER_CHECK=1; shift ;;
      -o|--output)      FORMAT="${2:-table}"; shift 2 ;;
      --output=*)       FORMAT="${1#*=}"; shift ;;
      -q|--quiet)       QUIET=1; shift ;;
      --no-color)       NO_COLOR=1; shift ;;
      -*)               printf '[ERR] Unknown option: %s (use -h for help)\n' "$1" >&2; exit 1 ;;
      *)
        if [[ -z "$TARGET_USER" ]]; then
          TARGET_USER="$1"; shift
        else
          printf '[ERR] Unexpected argument: %s\n' "$1" >&2; exit 1
        fi ;;
    esac
  done

  [[ -n "$TARGET_USER" ]] || { printf '[ERR] Missing username. Use -u <user> or -h for help.\n' >&2; exit 1; }
  [[ "$NUM_LAST" =~ ^[0-9]+$ && "$NUM_LAST" -ge 1 ]] || { printf '[ERR] -l/--last must be a positive integer.\n' >&2; exit 1; }

  case "$FORMAT" in
    table|json|csv) ;;
    *) printf '[ERR] Invalid output format: %s (expected table, json, or csv)\n' "$FORMAT" >&2; exit 1 ;;
  esac

  if [[ "$SKIP_USER_CHECK" -eq 0 && -z "$CPANEL_LOG$SSH_LOG$FTP_LOG$MAIL_LOG" && "$TARGET_USER" != *"@"* ]]; then
    if ! getent passwd "$TARGET_USER" >/dev/null 2>&1; then
      printf '[ERR] User "%s" not found in local passwd database (use --no-user-check to scan logs anyway).\n' "$TARGET_USER" >&2
      exit 1
    fi
  fi

  init_colors

  local py_script
  py_script="$(cat <<'PYEOF'
import csv
import glob
import gzip
import json
import os
import re
import shutil
import subprocess
import sys

(
    user, num_last_s, archives_s, protos_s, unique_s,
    cpanel_log, ssh_log, ftp_log, mail_log,
    fmt, quiet_s, script_name, script_version, ts_utc,
    c_red, c_green, c_yellow, c_cyan, c_bold, c_reset
) = sys.argv[1:21]

num_last = int(num_last_s)
archives = archives_s == "1"
unique_mode = unique_s == "1"
quiet = quiet_s == "1"
protos = [p.strip().lower() for p in protos_s.split(",") if p.strip()]
if "all" in protos:
    protos = ["cpanel", "ssh", "ftp", "mail"]

user_esc = re.escape(user)

def open_log_lines(path):
    try:
        if path.endswith(".gz"):
            with gzip.open(path, "rt", encoding="utf-8", errors="ignore") as f:
                for ln in f:
                    yield ln
        else:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for ln in f:
                    yield ln
    except OSError:
        return

def gather_files(custom, primaries, archive_globs):
    if custom:
        return [custom] if os.path.isfile(custom) else []
    files = [p for p in primaries if os.path.isfile(p)]
    if archives:
        extra = []
        for g in archive_globs:
            extra.extend(glob.glob(g))
        extra = sorted(set(extra), key=lambda p: os.path.getmtime(p) if os.path.exists(p) else 0, reverse=True)
        for p in extra:
            if p not in files and os.path.isfile(p):
                files.append(p)
    return files

def scan_cpanel():
    files = gather_files(
        cpanel_log,
        ["/usr/local/cpanel/logs/access_log", "/usr/local/cpanel/logs/login_log"],
        ["/usr/local/cpanel/logs/archive/access_log-*.gz", "/usr/local/cpanel/logs/archive/login_log-*.gz"],
    )
    hits = []
    # access_log: 1.2.3.4 - user [MM/DD/YYYY:HH:MM:SS -0000] "GET ..." 200 ...
    re_acc = re.compile(r'^([0-9a-fA-F:\.]+)\s+-\s+' + user_esc + r'\s+\[([^\]]+)\]\s+"([^"]+)"\s+(\d{3})')
    # login_log: [YYYY-MM-DD HH:MM:SS ...] info [...] 1.2.3.4 - user ...
    re_log = re.compile(r'^\[([^\]]+)\]\s+\S+\s+\[[^\]]+\]\s+([0-9a-fA-F:\.]+)\s+-\s+' + user_esc + r'\b')
    for fp in files:
        file_hits = []
        for ln in open_log_lines(fp):
            if user not in ln:
                continue
            m = re_acc.match(ln)
            if m:
                ip, ts, req, code = m.group(1), m.group(2), m.group(3), m.group(4)
                if code.startswith(("2", "3")):
                    file_hits.append({"protocol": "cpanel", "ip": ip, "timestamp": ts, "source": os.path.basename(fp), "detail": f"HTTP {code}"})
                continue
            m2 = re_log.match(ln)
            if m2:
                ts, ip = m2.group(1), m2.group(2)
                file_hits.append({"protocol": "cpanel", "ip": ip, "timestamp": ts, "source": os.path.basename(fp), "detail": "login_log"})
        hits.extend(reversed(file_hits))
    return hits

def scan_ssh():
    files = gather_files(
        ssh_log,
        ["/var/log/secure", "/var/log/auth.log", "/var/log/messages"],
        ["/var/log/secure-*", "/var/log/secure.*", "/var/log/auth.log.*", "/var/log/messages-*", "/var/log/messages.*"],
    )
    hits = []
    re_ssh = re.compile(r'^([A-Z][a-z]{2}\s+\d+\s+\d{2}:\d{2}:\d{2}|\d{4}-\d{2}-\d{2}T\S+).*Accepted\s+(\S+)\s+for\s+' + user_esc + r'\s+from\s+([0-9a-fA-F:\.]+)')
    for fp in files:
        file_hits = []
        for ln in open_log_lines(fp):
            if "Accepted " not in ln or user not in ln:
                continue
            m = re_ssh.search(ln)
            if m:
                file_hits.append({"protocol": "ssh", "ip": m.group(3), "timestamp": m.group(1), "source": os.path.basename(fp), "detail": f"Accepted {m.group(2)}"})
        hits.extend(reversed(file_hits))
    if not hits and not ssh_log and shutil.which("journalctl"):
        try:
            p = subprocess.run(
                ["journalctl", "-u", "sshd", "-u", "ssh", "--no-pager", "-n", "2000", "--output=short"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=8
            )
            if p.returncode == 0 and p.stdout:
                j_hits = []
                for ln in p.stdout.splitlines():
                    if "Accepted " in ln and user in ln:
                        m = re_ssh.search(ln)
                        if m:
                            j_hits.append({"protocol": "ssh", "ip": m.group(3), "timestamp": m.group(1), "source": "journalctl", "detail": f"Accepted {m.group(2)}"})
                hits.extend(reversed(j_hits))
        except Exception:
            pass
    return hits

def scan_ftp():
    files = gather_files(
        ftp_log,
        ["/var/log/messages", "/var/log/syslog", "/var/log/vsftpd.log", "/var/log/proftpd/proftpd.log"],
        ["/var/log/messages-*", "/var/log/messages.*", "/var/log/syslog.*"],
    )
    hits = []
    # Pure-FTPd: May 25 20:11:40 host pure-ftpd: (?@1.2.3.4) [INFO] user is now logged in
    re_pure = re.compile(r'^([A-Z][a-z]{2}\s+\d+\s+\d{2}:\d{2}:\d{2}|\d{4}-\d{2}-\d{2}T\S+).*?\(\?@([0-9a-fA-F:\.]+)\)\s+\[INFO\]\s+' + user_esc + r'\s+is now logged in')
    # ProFTPD / vsftpd fallback
    re_vs = re.compile(r'^([A-Z][a-z]{2}\s+\d+\s+\d{2}:\d{2}:\d{2}|\d{4}-\d{2}-\d{2}T\S+).*?\[' + user_esc + r'\].*?OK LOGIN:\s+Client\s+"([0-9a-fA-F:\.]+)"')
    for fp in files:
        file_hits = []
        for ln in open_log_lines(fp):
            if user not in ln:
                continue
            m = re_pure.search(ln)
            if m:
                file_hits.append({"protocol": "ftp", "ip": m.group(2), "timestamp": m.group(1), "source": os.path.basename(fp), "detail": "Pure-FTPd"})
                continue
            m2 = re_vs.search(ln)
            if m2:
                file_hits.append({"protocol": "ftp", "ip": m2.group(2), "timestamp": m2.group(1), "source": os.path.basename(fp), "detail": "vsftpd"})
        hits.extend(reversed(file_hits))
    return hits

def scan_mail():
    files = gather_files(
        mail_log,
        ["/var/log/maillog", "/var/log/mail.log"],
        ["/var/log/maillog-*", "/var/log/maillog.*", "/var/log/mail.log.*"],
    )
    hits = []
    # Dovecot: imap-login: Login: user=<user@domain>, method=PLAIN, rip=1.2.3.4, ...
    re_dov = re.compile(r'^([A-Z][a-z]{2}\s+\d+\s+\d{2}:\d{2}:\d{2}|\d{4}-\d{2}-\d{2}T\S+).*(imap-login|pop3-login).*Login:\s+user=<(' + user_esc + r'(?:@[^>]*)?)>.*?rip=([0-9a-fA-F:\.]+)')
    for fp in files:
        file_hits = []
        for ln in open_log_lines(fp):
            if "Login:" not in ln or user not in ln:
                continue
            m = re_dov.search(ln)
            if m:
                file_hits.append({"protocol": "mail", "ip": m.group(4), "timestamp": m.group(1), "source": os.path.basename(fp), "detail": f"{m.group(2)} ({m.group(3)})"})
        hits.extend(reversed(file_hits))
    return hits

scanners = {
    "cpanel": scan_cpanel,
    "ssh": scan_ssh,
    "ftp": scan_ftp,
    "mail": scan_mail,
}

results = []
for pr in protos:
    if pr not in scanners:
        continue
    raw = scanners[pr]()
    if unique_mode:
        seen = {}
        order = []
        for h in raw:
            k = h["ip"]
            if k not in seen:
                seen[k] = dict(h)
                seen[k]["hits"] = 1
                order.append(k)
            else:
                seen[k]["hits"] += 1
        for k in order[:num_last]:
            results.append(seen[k])
    else:
        for h in raw[:num_last]:
            h["hits"] = 1
            results.append(h)

unique_ips = sorted(set(r["ip"] for r in results))

if fmt == "json":
    print(json.dumps({
        "tool": script_name,
        "version": script_version,
        "timestamp": ts_utc,
        "user": user,
        "protocols": protos,
        "archives": archives,
        "unique_mode": unique_mode,
        "total_entries": len(results),
        "unique_ips": unique_ips,
        "entries": results,
    }, indent=2))
elif fmt == "csv":
    w = csv.writer(sys.stdout)
    w.writerow(["protocol", "ip", "timestamp", "hits", "source", "detail"])
    for r in results:
        w.writerow([r["protocol"], r["ip"], r["timestamp"], r["hits"], r["source"], r["detail"]])
else:
    if not quiet:
        print(f"{c_cyan}{'=' * 96}{c_reset}")
        print(f" {c_bold}{script_name} v{script_version}{c_reset} | Last Login IP Forensics | User: {c_bold}{user}{c_reset} | Last: {num_last} | {ts_utc}")
        print(f"{c_cyan}{'=' * 96}{c_reset}")
    if not results:
        print(f"{c_yellow}[INFO]{c_reset} No login entries found for user '{user}' across protocols: {', '.join(protos)}")
    else:
        print(f"{'PROTO':<8} {'IP ADDRESS':<20} {'TIMESTAMP':<28} {'HITS':<6} {'SOURCE':<18} {'DETAIL'}")
        print(f"{'-'*8} {'-'*20} {'-'*28} {'-'*6} {'-'*18} {'-'*20}")
        for r in results:
            print(f"{c_green}{r['protocol']:<8}{c_reset} {c_cyan}{r['ip']:<20}{c_reset} {c_yellow}{r['timestamp']:<28}{c_reset} {str(r['hits']):<6} {r['source']:<18} {r['detail']}")
        print()
        print(f"Summary: {len(results)} entry(ies) | {len(unique_ips)} unique IP(s): {', '.join(unique_ips)}")
PYEOF
)"

  python3 -c "$py_script" \
    "$TARGET_USER" "$NUM_LAST" "$ARCHIVES" "$PROTOS" "$UNIQUE_MODE" \
    "$CPANEL_LOG" "$SSH_LOG" "$FTP_LOG" "$MAIL_LOG" \
    "$FORMAT" "$QUIET" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$TIMESTAMP_UTC" \
    "$RED" "$GREEN" "$YELLOW" "$CYAN" "$BOLD" "$RESET"
}

main "$@"
