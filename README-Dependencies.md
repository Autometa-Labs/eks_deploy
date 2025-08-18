# Ansible Dependencies Setup for macOS

This playbook installs the required Python packages for running Ansible playbooks that use AWS modules.

## Prerequisites

- Ansible installed (via pipx, homebrew, or pip)
- macOS system
- Internet connection

## Usage

Run the dependency installation playbook:

```bash
ansible-playbook setup-dependencies.yml
```

## What it installs

The playbook installs the following Python packages:

- **boto3**: AWS SDK for Python
- **botocore**: Low-level AWS SDK core library
- **passlib**: Password hashing library
- **bcrypt**: Encryption backend for password hashing

## Verification

The playbook automatically verifies that all packages are installed correctly by importing each module.

## Troubleshooting

If you encounter issues:

1. **Permission errors**: The playbook uses `--user` flag to install packages in user space
2. **Python interpreter issues**: The playbook automatically detects the Python interpreter used by Ansible
3. **Network issues**: Ensure you have internet connectivity for package downloads

## After Installation

Once dependencies are installed, you can run the main Ansible playbooks:

```bash
# Deploy monitoring stack
cd environments/dev/app_deploy
ansible-playbook -i inventory/hosts.yml site.yml --tags "prometheus,grafana"

# Deploy specific components
ansible-playbook -i inventory/hosts.yml site.yml --tags "prometheus"
ansible-playbook -i inventory/hosts.yml site.yml --tags "grafana"
```

## Notes

- This playbook only needs to be run once per system
- Dependencies are installed in the same Python environment that Ansible uses
- The playbook is idempotent - safe to run multiple times
