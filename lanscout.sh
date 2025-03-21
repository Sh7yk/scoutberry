#!/bin/bash

NUCLEI_TEMPLATES="/root/nuclei-templates/http/misconfiguration"
LOG_DIR="/root/results/$(date +"%Y-%m-%d_%H-%M-%S")"
WEB_DIR="$LOG_DIR/web"
INTERFACE="eth0"  
PORTS="80,443,8080,8443,8000,8008,8888,8081,8444,8082"
NMAP_PARAMS="-T4 --open --script=ftp-anon,ftp-vuln*,http-iis-short-name-brute,http-iis-webdav-vuln,http-robots.txt,http-shellshock,krb5-enum-users,ldap-search,msrpc-enum,ms-sql-info,mysql-vuln*,rdp-vuln-ms12-020,rtsp-url-brute,smb-enum*,smb-vuln*,smb-webexec-exploit,vnc*,xmlrpc-methods"
USER=""  
PASS=""  


while getopts "i:u:p:" opt; do
  case $opt in
    i) INTERFACE="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 [-i interface] [-u username] [-p password]" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

mkdir -p "$LOG_DIR"
mkdir -p "$WEB_DIR/screenshots"

# ================================================
# Base func
# ================================================

check_dependencies() {
    local deps=("httpx" "nuclei" "jq" "nmap")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Error: $dep must be installed! do: sudo apt install $dep"
            exit 1
        fi
    done
}

wait_for_ip() {
    echo "[*] Waiting IPv4 on $INTERFACE..."
    until [ -n "$(get_ipv4)" ]; do sleep 1; done
    echo "[+] IP received: $(get_ipv4)"
}

get_ipv4() {
    ip -o -4 addr show "$INTERFACE" | awk '{print $4}' | cut -d'/' -f1
}

discover_hosts() {
    echo "[*] Search alive hosts..."
    NETWORK=$(ip -o -4 addr show "$INTERFACE" | awk '{print $4}')
    
    nmap -sn -T4 -oG "$LOG_DIR/hosts.gnmap" "$NETWORK"
    grep "Status: Up" "$LOG_DIR/hosts.gnmap" | awk '{print $2}' > "$LOG_DIR/live_hosts.txt"
    echo "[+] Alive hosts: $(wc -l < "$LOG_DIR/live_hosts.txt")"
}

port_scan() {
    echo -e "\n[*] Port scanning..."
    while read -r TARGET; do
        echo "[+] $TARGET:"
        nmap $NMAP_PARAMS -sV -oN "$LOG_DIR/nmap_$TARGET.txt" "$TARGET"
    done < "$LOG_DIR/live_hosts.txt"
}

# ================================================
# Web-services scan
# ================================================

find_web_services() {
    echo -e "\n[*] Search web-services..."
    
    httpx -l "$LOG_DIR/live_hosts.txt" -fr -rhsts -fhr -ports "$PORTS" -title -status-code -web-server -screenshot -silent -json -o "$WEB_DIR/web_services.json"
    [ -s "$WEB_DIR/web_services.json" ] && {
        jq -r '.url' "$WEB_DIR/web_services.json" > "$WEB_DIR/web_urls.txt"
        find . -name "*.png" -exec mv {} "$WEB_DIR/screenshots/" \; 2>/dev/null
        echo "[+] Found web-services: $(jq -s 'length' "$WEB_DIR/web_services.json")"
    } || echo "[-] Web-services not found"
}

run_nuclei() {
    
    [ -s "$LOG_DIR/live_hosts.txt" ] && {
        echo -e "\n[*] Start Nuclei..."
        nuclei -list "$LOG_DIR/live_hosts.txt" -nc -t $NUCLEI_TEMPLATES -severity info,low,medium,high,critical -je "$WEB_DIR/nuclei_results.json" >> "$WEB_DIR/nuclei_results.txt"
    }
}

# ================================================
# Services scan
# ================================================

vuln_scan() {
    echo -e "\n[*] Check vulns..."
    
    # SMB
    grep -rl "445/tcp" "$LOG_DIR" | while read -r FILE; do
        TARGET=$(basename "$FILE" | cut -d'_' -f2- | cut -d'.' -f1,2,3,4)
        echo "[+] SMB check: $TARGET"
        netexec smb "$TARGET" -u "$USER" -p "$PASS" --users -M ms17-010 -M zerologon -M printnightmare | tee -a "$LOG_DIR/smb_audit.log"
    done

    # MSSQL
    grep -rl "1433/tcp" "$LOG_DIR" | while read -r FILE; do
        TARGET=$(basename "$FILE" | cut -d'_' -f2- | cut -d'.' -f1,2,3,4)
        echo "[+] MSSQL check: $TARGET"
        netexec mssql "$TARGET" -u "$USER" -p "$PASS" -M mssql_priv | tee -a "$LOG_DIR/mssql_audit.log"
    done
    
    # LDAP
    grep -rl "389/tcp" "$LOG_DIR" | while read -r FILE; do
        TARGET=$(basename "$FILE" | cut -d'_' -f2- | cut -d'.' -f1,2,3,4)
        echo "[+] LDAP check: $TARGET"
        netexec ldap "$TARGET" -u "$USER" -p "$PASS" --bloodhound --collection All -M adcs | tee -a "$LOG_DIR/ldap_audit.log"
    done
    
    # FTP
    grep -rl "21/tcp" "$LOG_DIR" | while read -r FILE; do
        TARGET=$(basename "$FILE" | cut -d'_' -f2- | cut -d'.' -f1,2,3,4)
        echo "[+] FTP check: $TARGET"
        netexec ftp "$TARGET" -u "$USER" -p "$PASS"  | tee -a "$LOG_DIR/ftp_audit.log"
    done
    
    # SSH
    grep -rl "22/tcp" "$LOG_DIR" | while read -r FILE; do
        TARGET=$(basename "$FILE" | cut -d'_' -f2- | cut -d'.' -f1,2,3,4)
        echo "[+] SSH check: $TARGET"
        netexec ssh "$TARGET" -u "$USER" -p "$PASS"  | tee -a "$LOG_DIR/ssh_audit.log"
    done
}

# ================================================
# Reports
# ================================================

format_text_report() {
    echo -e "\n[Final report]"
    echo "========================"
    echo -e "\n### Open ports ###"
    for nmap_file in "$LOG_DIR"/nmap_*.txt; do
        ip_from_file=$(basename "$nmap_file" | sed 's/nmap_//;s/.txt//')
        ip_from_content=$(grep "Nmap scan report for" "$nmap_file" | awk '{print $NF}')
        target_ip=${ip_from_content:-$ip_from_file}
        grep -E "^[0-9]+/tcp" "$nmap_file" | while read -r line; do
            port=$(echo "$line" | awk -F/ '{print $1}')
            service=$(echo "$line" | awk '{
                for(i=4;i<=NF;i++) printf "%s ", $i;
                print ""
            }' | sed 's/  */ /g; s/ $//')
            printf "[%-15s] %5s -> %s\n" "$target_ip" "$port" "$service"
        done
    done | sort -u

    echo -e "\n### Web-services ###"
    [ -f "$WEB_DIR/web_services.json" ] && 
        jq -r '"\(.url) [\(.status_code)] \(.title)"' "$WEB_DIR/web_services.json"

    echo -e "\n### Nuclei Findings ###"
    [ -f "$WEB_DIR/nuclei_results.json" ] && 
        grep -E "info|low|medium|high|critical" "$WEB_DIR/nuclei_results.txt"

    echo -e "\n### Vulnerabilities ###"
    for log in "$LOG_DIR"/*_audit.log; do
        [ -f "$log" ] && {
            echo -e "\n# ${log##*/} #"
            grep -E 'VULERABLE|[\+\]' "$log"
        }
    done
}

# ================================================
# Main process
# ================================================

main() {
    check_dependencies
    wait_for_ip
    discover_hosts
    port_scan
    find_web_services
    run_nuclei
    vuln_scan
    format_text_report | tee "$LOG_DIR/final_report.txt"
    echo -e "\n[+] Reports saved:"
    echo -e " - Text: $LOG_DIR/final_report.txt"
    echo -e " - Screenshots: $WEB_DIR/screenshots/"
}

# Run
main
