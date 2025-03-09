![image](https://github.com/user-attachments/assets/364861be-2ba7-4236-8434-711e25481402)


# Scoutberry

A bash automation script for operational network reconnaissance, checking for known vulnerabilities and misconfigurations by simply connecting raspberry pi. Just connect the raspberry to the network it will receive an IP address and start testing.

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
  sudo go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
  sudo go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
  sudo apt install netexec
## Install

To install and automatically run a script at system startup, you must do the following:
 ```bash
git clone https://github.com/Sh7yk/scoutberry.git
cd scoutberry
sudo cp scoutberry /usr/local/bin
sudo chmod +x /usr/local/bin/scoutberry
sudo nano /etc/systemd/system/scoutberry.service
```
**Filling the configuration:**
```bash
[Unit]
Description=Automated Pentest Scanner
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/scoutberry
Restart=on-failure
RestartSec=30s
Environment="INTERFACE=eth0"
Environment="USER="
Environment="PASS="
StandardOutput=file:/var/log/scoutberry.log
StandardError=file:/var/log/scoutberry-error.log

[Install]
WantedBy=multi-user.target
```
## Activate the service
```bash
sudo systemctl daemon-reload
sudo systemctl enable scoutberry.service
```
## Usage

The scoutberry script simply waits for the ethernet cable to be connected and starts checking. The lanscout script can be run manually by specifying the network adapter and credentials with which the testing will be performed. We can say that this is a desktop analogue:
```bash
sudo lanscout.sh -i wlan0 -u root -p test
```
## Result

You can find results of recon in /root/results
## I am not responsible for the actions you will perform using this tool. Stay ethical and law abiding!
