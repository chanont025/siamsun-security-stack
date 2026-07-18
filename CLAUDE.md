# SiamSun Security Stack — Wazuh SIEM

> Wazuh SIEM for monitoring SiamSun Auto Sales
> Hosted on rookief-linux (172.16.0.200)

## Stack

| Component | Version | Service |
|-----------|---------|---------|
| Manager | 4.14.6 | wazuh.manager |
| Indexer | 4.14.6 | wazuh.indexer |
| Dashboard | 4.14.6 | wazuh.dashboard |

## Network

- Mode: host (docker-proxy bug — HTTP/HTTPS both affected)
- Dashboard: http://localhost:5601
- Tailscale: 100.67.145.15
- Agent ports: 1514/TCP, 1515/TCP

## SSL

- Verification: none (cert SAN=wazuh.indexer, connection=localhost)
- Certs in .secrets/*/certs/
- Root CA: .secrets/root-ca/certs/root-ca.pem

## Agent Enrollment

Password in /var/ossec/etc/authd.pass inside manager container.
Or generate key via manage_agents.

## Known Issues

1. docker-proxy bug: Dashboard hangs via port mapping — must use host networking
2. 4.14 cert path: /usr/share/wazuh-indexer/certs/ -> /config/certs/
3. Cert generator 0.0.4 fails inside Docker — run wazuh-certs-tool.sh on host
4. Key-cert mismatch: always copy key+cert together, verify modulus
