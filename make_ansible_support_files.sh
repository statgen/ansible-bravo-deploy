#!/usr/bin/env bash
# Get plan outputs from Terraform Cloud and build files to facilitate running ansible.
# Builds
#  - ssh config
#  - ansible inventory

# Get terraform cloud workspace name from env or use default
WORKSPACE_NAME="${WORKSPACE_NAME:=bravo_staging}"

# Ansible group names can't have -, substitute _
ANSIBLE_GROUP_NAME=$(echo "${WORKSPACE_NAME}" | tr '-' '_')

# Get terraform cloud token from credentials file 
JQ_EXP='."credentials"."app.terraform.io"."token"'
TOKEN=$(jq -r ${JQ_EXP} < ~/.terraform.d/credentials.tfrc.json)

# Get Workspace Id from Name
URL_ID="https://app.terraform.io/api/v2/organizations/statgen/workspaces?search%5Bname%5D=${WORKSPACE_NAME}"
WORKSPACE_ID=$(curl -s \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  "${URL_ID}" |\
  jq -r '.data[0].id')

# Get json output from terraform workspace outputs
#   Munge to similar format as terraform output -json  
URL_OUTS="https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/current-state-version?include=outputs"
TERRAFORM_JSON=$(curl -s \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  "${URL_OUTS}" |\
  jq '.included | map( {(.attributes.name) : .attributes.value}) | add')

# Parse json into env variables
BUCKET_NAME=$(echo "${TERRAFORM_JSON}" | jq -r '.bucket_name')
SITE_BUCKET=$(echo "${TERRAFORM_JSON}" | jq -r '.static_site_bucket')
PET_NAME=$(echo "${TERRAFORM_JSON}" | jq -r '.pet_name')
BASTION_PUBLIC_IP=$(echo "${TERRAFORM_JSON}" | jq -r '.bastion_public_ip')
APP_SERVER_PRIVATE_IP=$(echo "${TERRAFORM_JSON}" | jq -r '.app_server_private_ip[0]')
DB_SERVER_PRIVATE_IP=$(echo "${TERRAFORM_JSON}" | jq -r '.db_server_private_ip')
EBS_APP_VOL_ID=$(echo "${TERRAFORM_JSON}" | jq -r '.app_data_ebs_vol_id')


echo "Terraform workspace data:"
echo "${TERRAFORM_JSON}"

# Make inv dir for inventory and ssh config
mkdir -p inv

# Write ssh config
echo "Writing ssh config: inv/ssh-config"
cat << SSHDOC > inv/ssh-config
Host ${PET_NAME}-bastion
  User ec2-user
  Hostname ${BASTION_PUBLIC_IP}
  TCPKeepAlive yes
  ServerAliveInterval 240
  Port 22

Host ${PET_NAME}-app
  User ubuntu
  Hostname ${APP_SERVER_PRIVATE_IP}
  ProxyJump ${PET_NAME}-bastion
  TCPKeepAlive yes
  ServerAliveInterval 240
  Port 22

Host ${PET_NAME}-db
  User ubuntu
  Hostname ${DB_SERVER_PRIVATE_IP}
  ProxyJump ${PET_NAME}-bastion
  TCPKeepAlive yes
  ServerAliveInterval 240
  Port 22
SSHDOC

# Write Inventory
#   Include IPs so that playbook can access them.
echo "Writing inventory: inv/servers"
cat << INVENTORYDOC > inv/servers
[bastion]
${PET_NAME}-bastion
site_bucket=${SITE_BUCKET}

[app]
${PET_NAME}-app data_bucket=${BUCKET_NAME} private_ip=${APP_SERVER_PRIVATE_IP} ebs_vol_id=${EBS_APP_VOL_ID}

[mongo]
${PET_NAME}-db private_ip=${DB_SERVER_PRIVATE_IP} fs_type=xfs ebs_vol_id=${EBS_APP_VOL_ID}

[${ANSIBLE_GROUP_NAME}:children]
bastion
app
mongo
INVENTORYDOC

echo -e "To run ansible playbook:\n\
ansible-playbook --ssh-common-args='-F inv/ssh-config' -i 'inv/servers' playbook.yml\n"
