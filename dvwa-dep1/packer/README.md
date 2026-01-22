DVWA Image Build with Packer
📌 Overview
This folder contains the Packer configuration used to build a golden image of the Damn Vulnerable Web Application (DVWA) on Hetzner Cloud.
The image includes Apache, MySQL, PHP, and DVWA pre‑installed, ready to be deployed via Terraform.

📂 Structure
Code
packer/
├── dvwa.pkr.hcl              # Main Packer build file
├── provider.pkr.hcl          # Provider configuration (Hetzner Cloud plugin)
├── variable.pkr.hcl          # Variables (HCLOUD_TOKEN)
├── files/
│   └── config.inc.php        # DVWA configuration file
└── scripts/
    └── install-dvwa.sh       # Shell script to install DVWA + dependencies
⚙️ Prerequisites
Hetzner Cloud account and API token.

Packer installed locally (packer version to verify).

Environment variable set:

bash
export HCLOUD_TOKEN=<your_token>

🚀 Build Steps
Validate the configuration: packer validate dvwa.pkr.hcl

Build the image: packer build dvwa.pkr.hcl

Check the image in Hetzner Cloud: hcloud image list
(You should see an image named dvwa-image-v1)

🛠️ Notes
- The network configuration (gateway, DNS, NAT) is handled in Terraform, not baked into the image.

- The image is lightweight and modular: only DVWA + dependencies are installed.

- Security hardening (Fail2ban, SSH port changes) is applied at the bastion host level, not inside this image.
