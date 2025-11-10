#!/bin/bash
# GitLab Runner Installation Script
# Uses Ansible from kubespray venv (v2.16.14)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ansible path (from kubespray venv)
ANSIBLE_PLAYBOOK="/Users/kirylputseyeu/Desktop/practice-task/task_2/kubespray/venv/bin/ansible-playbook"
INVENTORY="../task_2/inventory.ini"

# Check if Ansible exists
if [ ! -f "$ANSIBLE_PLAYBOOK" ]; then
    echo -e "${RED}Error: ansible-playbook not found at $ANSIBLE_PLAYBOOK${NC}"
    exit 1
fi

echo -e "${GREEN}Using Ansible:${NC}"
$ANSIBLE_PLAYBOOK --version

# Check if GITLAB_RUNNER_TOKEN is set
if [ -z "$GITLAB_RUNNER_TOKEN" ]; then
    echo -e "${YELLOW}Warning: GITLAB_RUNNER_TOKEN environment variable not set!${NC}"
    echo "You need to set it before running:"
    echo "  export GITLAB_RUNNER_TOKEN=\"glrt_XXXXXXXXXXXXX\""
    exit 1
fi

echo -e "${GREEN}Runner Registration Token is set${NC}"

# Check if inventory exists
if [ ! -f "$INVENTORY" ]; then
    echo -e "${RED}Error: Inventory not found at $INVENTORY${NC}"
    exit 1
fi

echo -e "${GREEN}Inventory file found at $INVENTORY${NC}"

# Run playbook
echo -e "${GREEN}Starting GitLab Runner installation...${NC}"
$ANSIBLE_PLAYBOOK -i "$INVENTORY" install-runner.yml -v

echo -e "${GREEN}Installation completed!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Check runner status in GitLab UI: http://gitlab.test.local/admin/runners"
echo "2. Test with a CI/CD pipeline"
echo "3. View logs: ssh to worker nodes and check: sudo journalctl -u gitlab-runner -f"
