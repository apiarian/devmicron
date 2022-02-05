#! /bin/bash

set -euxo pipefail

sudo ansible-galaxy collection install ansible.posix

sudo ansible-pull -U https://github.com/apiarian/devmicron.git ansible/main.yml
