---
title: Network Isolation and Credential Protection
description: >-
  Network isolation, firewall configuration, and credential protection patterns
---

### Firewall Configuration (UFW)

Configure deny-by-default firewall rules with explicit allow-lists.

```bash
#!/bin/bash
# UFW firewall configuration for GitHub Actions runner

set -euo pipefail

echo "==> Configuring firewall for runner network isolation"

# Reset to clean state
ufw --force reset

# Default policies: deny all incoming and outgoing
ufw default deny incoming
ufw default deny outgoing
ufw default deny routed

# Allow outbound to GitHub (required for runner operation)
# GitHub IP ranges: https://api.github.com/meta
ufw allow out to 140.82.112.0/20 port 443 proto tcp comment 'GitHub API'
ufw allow out to 143.55.64.0/20 port 443 proto tcp comment 'GitHub API'
ufw allow out to 185.199.108.0/22 port 443 proto tcp comment 'GitHub Pages/Assets'
ufw allow out to 192.30.252.0/22 port 443 proto tcp comment 'GitHub API'

# Allow outbound DNS
ufw allow out to any port 53 proto udp comment 'DNS'

# Allow outbound NTP (if time sync required)
ufw allow out to any port 123 proto udp comment 'NTP'

# Allow outbound to package registries (add as needed)
# Example: PyPI
ufw allow out to any port 443 proto tcp comment 'PyPI'

# Deny outbound to cloud metadata endpoints
ufw deny out to 169.254.169.254 comment 'Block AWS/GCP metadata'
ufw deny out to fd00:ec2::254 comment 'Block AWS IMDSv2 IPv6'

# Deny outbound to private networks (prevent internal reconnaissance)
ufw deny out to 10.0.0.0/8 comment 'Block RFC1918 10.0.0.0/8'
ufw deny out to 172.16.0.0/12 comment 'Block RFC1918 172.16.0.0/12'
ufw deny out to 192.168.0.0/16 comment 'Block RFC1918 192.168.0.0/16'

# Enable firewall
ufw --force enable

# Display rules
ufw status verbose

echo "==> Firewall configured with deny-by-default policies"
```

### Network Namespace Isolation

Use Linux network namespaces to isolate runner network access (advanced).

```bash
#!/bin/bash
# Create isolated network namespace for runner jobs

set -euo pipefail

NAMESPACE="runner-isolated"
VETH_HOST="veth-runner0"
VETH_NS="veth-runner1"

# Create network namespace
ip netns add "$NAMESPACE"

# Create veth pair
ip link add "$VETH_HOST" type veth peer name "$VETH_NS"

# Move one end to namespace
ip link set "$VETH_NS" netns "$NAMESPACE"

# Configure host side
ip addr add 10.200.1.1/24 dev "$VETH_HOST"
ip link set "$VETH_HOST" up

# Configure namespace side
ip netns exec "$NAMESPACE" ip addr add 10.200.1.2/24 dev "$VETH_NS"
ip netns exec "$NAMESPACE" ip link set "$VETH_NS" up
ip netns exec "$NAMESPACE" ip link set lo up

# Set default route in namespace
ip netns exec "$NAMESPACE" ip route add default via 10.200.1.1

# Enable NAT for outbound traffic
iptables -t nat -A POSTROUTING -s 10.200.1.0/24 -j MASQUERADE

# Run runner in isolated namespace
ip netns exec "$NAMESPACE" sudo -u github-runner /opt/github-runner/bin/Runner.Listener
```

### Cloud Metadata Endpoint Blocking

Prevent workflows from stealing cloud credentials via metadata endpoints.

#### iptables Rules

```bash
#!/bin/bash
# Block access to cloud metadata endpoints

set -euo pipefail

# AWS IMDSv1 (169.254.169.254)
iptables -A OUTPUT -d 169.254.169.254 -j REJECT --reject-with icmp-port-unreachable

# AWS IMDSv2 IPv6 (fd00:ec2::254)
ip6tables -A OUTPUT -d fd00:ec2::254/128 -j REJECT --reject-with icmp6-port-unreachable

# GCP metadata endpoint (metadata.google.internal)
iptables -A OUTPUT -d 169.254.169.254 -p tcp --dport 80 -j REJECT --reject-with tcp-reset
iptables -A OUTPUT -d 169.254.169.254 -p tcp --dport 8080 -j REJECT --reject-with tcp-reset

# Azure metadata endpoint (169.254.169.254)
iptables -A OUTPUT -d 169.254.169.254 -p tcp --dport 80 -j REJECT --reject-with tcp-reset

# Make persistent
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
```

#### IMDSv2 Enforcement (AWS)

If runners must access AWS metadata, enforce IMDSv2 with token requirement.

```bash
# Force IMDSv2 on EC2 instance (requires session token)
aws ec2 modify-instance-metadata-options \
  --instance-id i-1234567890abcdef0 \
  --http-tokens required \
  --http-put-response-hop-limit 1
```

**IMDSv2 protection**: Requires HTTP PUT to obtain session token before metadata access. Prevents SSRF-based credential theft.

## Credential Protection

Eliminate long-lived credentials. Use short-lived tokens with minimal scope.

### OIDC Federation (Recommended)

Use OpenID Connect federation to mint temporary credentials per job. No stored secrets.

```yaml
# .github/workflows/deploy-with-oidc.yml
# Secretless authentication using OIDC

name: Deploy with OIDC
on:
  push:
    branches: [main]

permissions:
  id-token: write  # Required for OIDC token
  contents: read

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Authenticate to GCP
        uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: 'projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'github-runner@my-project.iam.gserviceaccount.com'

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy myapp \
            --image gcr.io/my-project/myapp:${{ github.sha }} \
            --region us-central1
```

**Security benefits**:

- No stored secrets in repository or runner
- Short-lived credentials (1 hour maximum)
- Subject claim validation prevents token reuse
- Audit trail via cloud IAM logs

See [OIDC Federation Patterns](../secrets/oidc.md) for complete setup.

### Environment Variable Injection

If secrets are required, inject via environment variables with minimal lifetime.

```yaml
# Secure secret injection pattern

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - name: Deploy with secret
        env:
          # Secret available only during this step
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: |
          # Use secret directly from environment
          curl -H "Authorization: Bearer $DEPLOY_TOKEN" https://api.example.com/deploy

      # Secret no longer available in subsequent steps
      - name: Cleanup
        run: echo "Secret was never written to disk"
```

**Avoid**:

- Writing secrets to files (persists on disk, leaks to logs)
- Exporting secrets to shell environment (accessible to subprocesses)
- Passing secrets as command arguments (visible in process list)

### Secrets Masking Verification

Verify GitHub masks secrets in logs automatically.

```yaml
# Test secrets masking

jobs:
  test-masking:
    runs-on: self-hosted
    steps:
      - name: Verify secret masking
        env:
          TEST_SECRET: ${{ secrets.TEST_SECRET }}
        run: |
          # This will appear as *** in logs
          echo "Secret value: $TEST_SECRET"

          # This will also be masked
          echo "$TEST_SECRET" | base64

          # Verify masking works
          if echo "$TEST_SECRET" | grep -q "secret-value"; then
            echo "::error::Secret masking failed!"
