# CTFd HA — Documentation du Projet

## Résumé

Déploiement automatisé de CTFd en haute disponibilité sur Proxmox avec Packer + Ansible.

---

## Architecture

```
Machine 1 — Master (DHCP vmbr1)          Machine 2 — Replica (DHCP vmbr1)
┌─────────────────────────────────┐       ┌───────────────────────────────┐
│  ctfd_ctfd_1      :8000         │       │  ctfd_app_2       :8001       │
│  ctfd_db_master   :3307 ────────┼──────▶│  ctfd_db_replica  :3308       │
│  ctfd_cache_1     :6380 ◀───────┼───────┤  (Redis Machine 1)            │
│  blackbox_exp     :9115         │       │                               │
│  node_exporter    :9100         │       │  node_exporter    :9100       │
└─────────────────────────────────┘       └───────────────────────────────┘
         │ binlog replication
         ▼
   Slave_IO=Yes
   Slave_SQL=Yes
```

---

## Structure du projet

```
ctfd-ha/
├── deploy.sh                          # Script d'orchestration complet
├── ansible/
│   ├── inventory.ini                  # Pour tests manuels uniquement
│   ├── site.yml                       # Orchestre machine1 + machine2
│   ├── machine1.yml                   # Playbook Machine 1 (Master)
│   ├── machine2.yml                   # Playbook Machine 2 (Replica)
│   ├── group_vars/
│   │   └── all.yml                    # Toutes les variables
│   ├── files/
│   │   └── my_custom_plugin/
│   │       ├── __init__.py            # Plugin scoring/PDF/speed bonus
│   │       └── assets/inject.js       # JS injecté dans CTFd
│   └── templates/
│       ├── docker-compose-master.yml.j2
│       ├── docker-compose-replica.yml.j2
│       ├── init-replica.sql.j2        # Binlog injecté dynamiquement
│       └── ldap_auth_init.py.j2       # Settings LDAP
└── packer/
    ├── ctfd-master/
    │   ├── provider.pkr.hcl
    │   ├── variable.pkr.hcl
    │   └── ctfd-master.pkr.hcl
    └── ctfd-replica/
        ├── provider.pkr.hcl
        ├── variable.pkr.hcl
        └── ctfd-replica.pkr.hcl
```

---

## Flux de déploiement complet

```
./deploy.sh
    │
    ├── [1] packer build ctfd-master/
    │         ├── Clone template 128 → VM 201
    │         ├── DHCP → IP via qemu-guest-agent
    │         └── ansible machine1.yml
    │               ├── OS + Docker + docker-compose
    │               ├── Clone CTFd + plugins (host)
    │               ├── docker-compose up (CTFd + MariaDB + Redis)
    │               ├── Setup CTFd admin (avant LDAP)
    │               ├── Token API via SQL direct
    │               ├── Créer challenges + flags
    │               ├── docker cp plugins → restart (LDAP actif)
    │               ├── docker commit + save ctfd_custom.tar
    │               ├── SHOW MASTER STATUS → binlog_info.json
    │               └── Node Exporter + Blackbox Exporter
    │
    ├── [2] Récupérer IP Machine 1 via API Proxmox
    │
    ├── [3] Lire binlog_info.json depuis Machine 1 via SSH
    │
    └── [4] packer build ctfd-replica/
              ├── Clone template 128 → VM 202
              ├── DHCP → IP via qemu-guest-agent
              └── ansible machine2.yml
                    ├── OS + Docker + docker-compose
                    ├── Fetch ctfd_custom.tar depuis Machine 1
                    ├── docker load ctfd_custom
                    ├── MariaDB replica + init-replica.sql (binlog auto)
                    ├── Dump + restore depuis Machine 1
                    ├── Vérifier Slave_IO=Yes + Slave_SQL=Yes
                    ├── docker run ctfd_app_2
                    └── Node Exporter
```

---

## Prérequis

### Sur le control node
```bash
# Packer
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install -y packer

# Ansible + sshpass
sudo apt install -y ansible sshpass python3-pip

# Initialiser les plugins Packer
cd packer/ctfd-master  && packer init .
cd packer/ctfd-replica && packer init .
```

### Template Proxmox (ID 128)
- Ubuntu 22.04 LTS
- User `bob` / password `123456`
- `qemu-guest-agent` installé et actif
- Option QEMU Guest Agent activée dans Proxmox

---

## Utilisation

### Production — déploiement complet automatisé
```bash
# Exporter le token secret
export PKR_VAR_proxmox_api_token_secret="fb6f11c7-5acd-41d2-8de3-758256f7951e"

# Tout déployer en une commande
./deploy.sh
```

### Tests manuels — Ansible seul
```bash
cd ansible/

# Tester la connexion
ansible -i inventory.ini all -m ping

# Déployer les deux machines
ansible-playbook -i inventory.ini site.yml

# Déployer seulement Machine 1
ansible-playbook -i inventory.ini machine1.yml

# Déployer seulement Machine 2 (après Machine 1)
ansible-playbook -i inventory.ini machine2.yml
```

---

## Variables importantes (group_vars/all.yml)

| Variable | Valeur | Description |
|---|---|---|
| `machine1_ip` | `10.0.30.99` | IP Machine 1 (tests manuels) |
| `machine2_ip` | `10.0.30.100` | IP Machine 2 (tests manuels) |
| `mariadb_root_password` | `rootpass` | Password root MariaDB |
| `mariadb_replica_password` | `replica_password` | Password user replica |
| `ctfd_admin_name` | `admin` | Nom admin CTFd |
| `ctfd_admin_password` | `adminpass` | Password admin CTFd |
| `ctfd_secret_key` | `AAAA...` | Clé secrète CTFd |
| `ldap_host` | `10.0.30.93` | IP serveur LDAP |
| `node_exporter_version` | `1.8.2` | Version Node Exporter |

---

## Plugins CTFd déployés

### my_custom_plugin
- Scoring avec speed bonus (20pts pour les 5 premiers solvers)
- Rapport PDF par utilisateur (`/report/user/<id>/pdf`)
- API bonus (`/report/bonus/<challenge_id>`)
- Injection JS dans le dashboard

### ldap_auth
- Authentification via LDAP (serveur `10.0.30.93`)
- Création automatique du compte CTFd au premier login LDAP
- Désactivation de l'inscription classique et OAuth

---

## Challenges CTFd créés automatiquement

| Nom | Catégorie | Points | Flag |
|---|---|---|---|
| ftp exploitation | Exploitation | 10 | FLAG{FTP_123} |
| smb exploitation | Exploitation | 10 | FLAG{SMB_FLAG} |
| telnet exploitation | Exploitation | 10 | FLAG{TELNET_FLAG_DONE} |
| ssh exploitation | Exploitation | 20 | FLAG{SSH_FLAG_CONGRATS} |
| mysql exploitation | Exploitation | 20 | FLAG{MYSQL_FLAG_MYSQL} |
| postgres exploitation | Exploitation | 20 | FLAG{POSTGRES_FLAG_DONE} |
| http exploitation | Exploitation | 30 | FLAG{HTTP_HARD_MODE} |
| Connexion légitime | Blue Team | 50 | 10.0.30.75 |
| Wazuh agents | Blue Team | 50 | 2 |
| Statut Wazuh agent | Blue Team | 50 | active |
| Faux positifs | Blue Team | 75 | 10.0.30.23 |
| Événement de sécurité | Blue Team | 75 | 1134 |
| Attaque | Blue Team | 100 | 10.0.30.92 |

---

## Monitoring

| Exporter | Machine | Port | Description |
|---|---|---|---|
| node_exporter | Machine 1 + 2 | 9100 | Métriques système |
| blackbox_exporter | Machine 1 | 9115 | Disponibilité services |

---

## Problèmes rencontrés et solutions

### 1. LDAP remplace /login — impossible de créer l'admin
**Problème** : Le plugin LDAP remplace la page `/login` dès son chargement.
**Solution** : Copier les plugins dans le conteneur **après** le setup CTFd et la création des challenges.

### 2. Token API CTFd — 403 FORBIDDEN
**Problème** : L'endpoint `/api/v1/tokens` nécessite une session authentifiée avec CSRF token.
**Solution** : Insérer le token directement dans MariaDB via SQL.
```sql
INSERT INTO ctfd.tokens (type, user_id, created, expiration, value, description)
SELECT 'user', id, NOW(), DATE_ADD(NOW(), INTERVAL 1 YEAR),
'ctfd_ansible_TOKEN', 'Ansible deploy token'
FROM ctfd.users WHERE name='admin' LIMIT 1;
```

### 3. Réplication — replica affiche setup page
**Problème** : La base replica était vide donc CTFd demandait un nouveau setup.
**Solution** : Dump + restore depuis Machine 1 avant de lancer CTFd replica.

### 4. docker-compose non trouvé sur Ubuntu 22.04
**Problème** : `docker-compose` via apt utilise Python 3.12 sans `distutils`.
**Solution** : Installer le binaire directement depuis GitHub releases v1.29.2.

### 5. IP DHCP inconnue pour Packer
**Problème** : Packer ne connaît pas l'IP DHCP attribuée à la VM.
**Solution** : Installer `qemu-guest-agent` dans le template — Packer récupère l'IP automatiquement via l'API Proxmox.

### 6. Transfert ctfd_custom.tar lent via control node
**Problème** : 175MB transférés via control node → très lent.
**Solution** : Transfert direct Machine 1 → Machine 2 via SCP avec bastion.

### 7. Binlog position non disponible pour Machine 2
**Problème** : `set_fact` de Machine 1 non disponible dans un build Packer séparé.
**Solution** : Sauvegarder le binlog dans `/home/bob/binlog_info.json` et le lire via SSH dans `deploy.sh`.

---

## Vérifications post-déploiement

```bash
# Machine 1
sudo docker ps
curl -s -o /dev/null -w "%{http_code}" http://MACHINE1_IP:8000
sudo docker exec ctfd_db_master mysql -uroot -prootpass \
  -e "SHOW MASTER STATUS;"
curl http://MACHINE1_IP:9100/metrics | head -3
curl http://MACHINE1_IP:9115/metrics | head -3

# Machine 2
sudo docker ps
curl -s -o /dev/null -w "%{http_code}" http://MACHINE2_IP:8001
sudo docker exec ctfd_db_replica mysql -uroot -prootpass \
  -e "SHOW SLAVE STATUS\G" | grep -E "Running|Error"
sudo docker exec ctfd_db_replica mysql -uroot -prootpass \
  -e "USE ctfd; SELECT COUNT(*) FROM users; SELECT COUNT(*) FROM challenges;"
curl http://MACHINE2_IP:9100/metrics | head -3
```
