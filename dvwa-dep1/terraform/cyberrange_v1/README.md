DVWA Deployment with Terraform

📌 Overview
This folder contains the Terraform configuration used to deploy the DVWA application on Hetzner Cloud.
It provisions two servers:

- Private server → runs DVWA using the golden image built with Packer.

- Jump server (bastion host) → acts as NAT gateway and reverse proxy, secured with Fail2ban and a non‑standard SSH port.

📂 Structure

terraform/
├── main.tf                  # Main infrastructure definition
├── provider.tf              # Hetzner Cloud provider configuration
├── variables.tf             # Input variables (token, server types, etc.)
├── outputs.tf               # Outputs (public IPs, etc.)
├── user_data/               # Cloud-init scripts
│   ├── jump-server.yaml     # NAT + Nginx + Fail2ban + SSH port change
│   └── private-server.yaml  # Network + DNS config
├── keys/                    # SSH keys
│   └── chadha_pubkey.pub
└── README.md                # This documentation

⚙️ Prerequisites

Hetzner Cloud account and API token.

Terraform installed locally (terraform version to verify).

Environment variable set: export HCLOUD_TOKEN=<your_token>

🚀 Deployment Steps
Initialize Terraform: terraform init

Validate configuration: terraform validate

Apply the deployment: terraform apply

Retrieve outputs (public IPs, etc.): terraform output

🛠️ Notes
The DVWA image must be built first with Packer (dvwa-image-v1).

The jump server is hardened:

- SSH port changed from 22 → 2222 (or another non‑standard port).

- Fail2ban installed to block brute force attempts.

- UFW firewall rules can be added to restrict access further.

The private server uses the golden DVWA image and is accessible only through the jump server proxy.
