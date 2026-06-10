#!/bin/bash

set -e

echo "Starting Datadog Agent Installation..."

DD_API_KEY="{{DDAPIKEY}}"
DD_SITE="{{DDSITE}}"
ENVIRONMENT="{{ENVIRONMENT}}"

export DD_API_KEY
export DD_SITE

###########################################
# Install Datadog Agent
###########################################

DD_API_KEY="$DD_API_KEY" \
DD_SITE="$DD_SITE" \
bash -c "$(curl -fsSL https://install.datadoghq.com/scripts/install_script_agent7.sh)"

###########################################
# Backup Existing Configuration
###########################################

cp /etc/datadog-agent/datadog.yaml \
/etc/datadog-agent/datadog.yaml.bak || true

###########################################
# Configure Datadog Agent
###########################################

cat > /etc/datadog-agent/datadog.yaml << EOF
api_key: $DD_API_KEY
site: $DD_SITE

logs_enabled: true

listeners:
  - name: docker

config_providers:
  - name: docker
    polling: true

logs_config:
  container_collect_all: true

process_config:
  process_collection:
    enabled: true

tags:
  - env:$ENVIRONMENT
  - monitoring:datadog
  - managed_by:terraform
EOF

###########################################
# Amazon Linux Log Collection
###########################################

mkdir -p /etc/datadog-agent/conf.d/journald.d

cat > /etc/datadog-agent/conf.d/journald.d/conf.yaml << EOF
logs:
  - type: journald
    service: amazon-linux
    source: systemd
EOF

###########################################
# Docker Monitoring (ALWAYS CREATE)
###########################################

mkdir -p /etc/datadog-agent/conf.d/docker.d

cat > /etc/datadog-agent/conf.d/docker.d/conf.yaml << EOF
init_config:

instances:
  - url: "unix:///var/run/docker.sock"
EOF

# Add Datadog Agent to docker group if present
if getent group docker >/dev/null; then
    usermod -aG docker dd-agent || true
fi

###########################################
# Network Monitoring + Runtime Security
###########################################

cat > /etc/datadog-agent/system-probe.yaml << EOF
system_probe_config:
  enabled: true

network_config:
  enabled: true

runtime_security_config:
  enabled: true
EOF

###########################################
# System Probe Permissions
###########################################

if [ -f /opt/datadog-agent/embedded/bin/system-probe ]; then

    setcap cap_sys_admin,cap_net_admin,cap_net_raw+ep \
    /opt/datadog-agent/embedded/bin/system-probe || true

fi

###########################################
# Enable Services
###########################################

systemctl enable datadog-agent || true
systemctl enable datadog-agent-process || true
systemctl enable datadog-agent-sysprobe || true
systemctl enable datadog-agent-security || true

###########################################
# Restart Services
###########################################

systemctl restart datadog-agent || true
systemctl restart datadog-agent-process || true
systemctl restart datadog-agent-sysprobe || true
systemctl restart datadog-agent-security || true

###########################################
# Validation
###########################################

sleep 20

datadog-agent status || true

echo "Datadog Agent Installation Completed Successfully"
