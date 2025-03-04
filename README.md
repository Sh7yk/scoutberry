# Scoutberry

A bash automation script for operational network reconnaissance, checking for known vulnerabilities and misconfigurations by simply connecting raspberry pi.

## Features

- **Network Discovery**  
  Automatically detects active hosts in the local network using `nmap`.
  
- **Port Scanning**  
  Identifies open ports and services with version detection (`nmap`).

- **Web Service Enumeration**  
  Discovers web services using `httpx` with screenshots and metadata collection.

- **Vulnerability Scanning**  
  Executes `nuclei` with custom templates to detect misconfigurations and vulnerabilities.

- **Service-Specific Checks**  
  Tests for vulnerabilities in:
  - SMB (MS17-010, Zerologon, PrintNightmare)
  - MSSQL (Privilege escalation)
  - LDAP (BloodHound integration)
  - FTP/SSH (Weak credentials)
  
- **Reporting**  
  Generates text and structured reports with:
  - Open ports mapping
  - Web service details
  - Vulnerability findings
  - Screenshots of web interfaces

## Requirements

- Linux-based OS (Kali Linux recommended)
- Bash 4.0+
- Required tools:
  ```bash
  sudo apt install nmap jq
  go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
  go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
  pip install netexec

