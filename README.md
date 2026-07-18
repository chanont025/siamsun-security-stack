# SiamSun Security Stack

Wazuh SIEM (Manager + OpenSearch Indexer + Dashboard) สำหรับ SME — รองรับ multi-site agent monitoring

## 🚀 Quick Start (First Time)

ต้องการ: Docker, curl, 2 CPU, 4GB RAM

```bash
# 1. Clone
git clone <repo-url> siamsun-security-stack
cd siamsun-security-stack

# 2. ตั้งค่ารหัสผ่าน (แก้ก่อน!)
cp .env.example .env
vim .env   # เปลี่ยน INDEXER_PASSWORD, API_PASSWORD, DASHBOARD_PASSWORD

# 3. สร้าง SSL certificates + secrets
bash setup.sh

# 4. เริ่มระบบ
docker compose up -d

# 5. เข้า Dashboard
# http://<SERVER_IP>:5601
# Username: admin / Password: <INDEXER_PASSWORD>
```

## 📋 Requirements

| Requirement | Minimum | Recommend |
|-------------|---------|-----------|
| CPU | 2 core | 4 core |
| RAM | 4 GB | 8 GB |
| Docker | 24+ | Docker Compose v2 |
| Disk | 20 GB | 50 GB |

## 🏗 Architecture

```
┌─────────────────────────────────────────────────┐
│              rookief-linux (host)               │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Manager  │  │ Indexer  │  │ Dashboard    │  │
│  │ 1514/1515│  │ 9200     │  │ 5601 (HTTP)  │  │
│  │ 55000    │  │          │  │              │  │
│  └──────────┘  └──────────┘  └──────────────┘  │
│  ──────────── network_mode: host ────────────── │
└─────────────────────────────────────────────────┘
         ↕ Tailscale / WireGuard
  ┌──────────────────┐
  │ Windows Server   │ ← Wazuh Agent
  │ Site ลูกค้า       │
  └──────────────────┘
```

### ⚠️ Known: docker-proxy Bug
OpenSearch Dashboards **ไม่สามารถใช้งานผ่าน Docker port mapping** ได้ (connection hang)
→ ใช้ `network_mode: host` — ไม่ต้อง port mapping

## 🔌 Ports

| Port | Service | Protocol | Purpose |
|------|---------|----------|---------|
| 5601 | Dashboard | HTTP | Web UI |
| 1514 | Manager | TCP | Agent communication |
| 1515 | Manager | TCP | Agent enrollment |
| 514 | Manager | UDP | Syslog |
| 55000 | Manager API | HTTPS | REST API |
| 9200 | Indexer | HTTPS | OpenSearch |

## 🔐 SSL Certificates

สร้างอัตโนมัติโดย `setup.sh` (ใช้ `wazuh-certs-tool.sh` official):

| Component | Container Path |
|-----------|---------------|
| Indexer cert | `/usr/share/wazuh-indexer/config/certs/` |
| Manager cert | `/etc/ssl/` |
| Dashboard cert | `/usr/share/wazuh-dashboard/certs/` |

> ⚠️ **Path เปลี่ยนใน 4.14+** — `/usr/share/wazuh-indexer/certs/` → `/config/certs/`

### คู่ Key-Cert

เช็คด้วย:
```bash
openssl x509 -in cert.pem -noout -modulus | md5sum
openssl pkey -in key.pem -pubout | openssl md5
# ต้องตรงกัน
```

## 🌐 Multi-Site: Agent Enrollment

### 1. Connectivity
Site ลูกค้าต้อง connect ถึง Manager ได้ เช่น Tailscale:
```bash
# Site ลูกค้าติดตั้ง Tailscale → ping Manager IP
ping 100.67.145.15
```

### 2. สร้าง Agent Key
```bash
docker exec -i wazuh.manager sh -c "
printf \"A\n<agent-name>\nany\ny\nE\n<ID>\nQ\n\" | /var/ossec/bin/manage_agents
"
```

### 3. ติดตั้ง Agent บน Windows
ดาวน์โหลด Wazuh agent 4.14.6 → ติดตั้ง GUI → ใส่:
- **Manager:** `<MANAGER_TAILSCALE_IP>`
- **Authentication key:** `<KEY_FROM_STEP_2>`

### 4. ตรวจสอบ
```bash
docker exec wazuh.manager sh -c "/var/ossec/bin/agent_control -l"
# ต้องขึ้น status = Active
```

## 📂 Project Structure

```
.
├── config/                   # Git-committed configs
│   ├── certs.yml             # Node definitions for cert gen
│   ├── wazuh_indexer/        # opensearch.yml, internal_users.yml
│   └── wazuh_dashboard/      # opensearch_dashboards.yml
├── .secrets/                 # 🔒 Gitignored (certs + passwords)
│   ├── .env                  # Passwords + version
│   ├── wazuh.yml             # Dashboard API config
│   └── */certs/              # SSL certificates
├── docker-compose.yml
├── setup.sh                  # One-time cert + secrets setup
├── CLAUDE.md                 # Agent instructions
├── AGENTS.md                 # Agent roles
└── .gitignore
```

## 🛠 Maintenance

### View Logs
```bash
docker logs wazuh.manager --tail 50
docker logs wazuh.indexer --tail 50
docker logs wazuh.dashboard --tail 50
```

### Regenerate Certs
```bash
curl -sO https://packages.wazuh.com/4.14/wazuh-certs-tool.sh
bash wazuh-certs-tool.sh -A .secrets/root-ca/certs/root-ca.pem .secrets/root-ca/certs/root-ca-key.pem

## Post-Setup (ครั้งแรก)

หลังจาก "docker compose up -d" รอ 30-60 วินาทีให้ services start แล้ว:

### 1. ตั้งค่า Auth Password
```bash
docker exec wazuh.manager bash -c "echo SiamSunAgent2026 > /var/ossec/etc/authd.pass && chmod 600 /var/ossec/etc/authd.pass"
```

### 2. ตรวจสอบระบบ
```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
# Dashboard: http://localhost:5601
```

### 3. เพิ่ม Agent (Windows/Linux)
```bash
# สร้าง agent key (เปลี่ยนชื่อ agent-name ตามต้องการ)
docker exec -i wazuh.manager sh -c "printf Anagent-namenanynynEn1nQn | /var/ossec/bin/manage_agents"
# ใช้ key ที่ได้ ไปใส่ที่ client ตอนติดตั้ง
```
