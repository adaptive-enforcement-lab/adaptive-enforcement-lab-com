---
title: Credential Protection
description: >-
  OIDC federation and credential protection patterns for GitHub Actions runners
---

          fi

```

## Audit Logging

Comprehensive logging to detect and investigate runner compromise.

### auditd Configuration

Configure Linux audit daemon to log runner security events.

```bash
# /etc/audit/rules.d/99-runner-security.rules
# Audit rules for GitHub Actions runner

# Monitor runner binary execution
-w /opt/github-runner/bin/Runner.Listener -p x -k runner_exec

# Monitor runner configuration changes
-w /opt/github-runner/.runner -p wa -k runner_config
-w /opt/github-runner/.credentials -p wa -k runner_creds

# Monitor runner workspace
-w /opt/github-runner/_work -p wa -k runner_workspace

# Monitor privileged operations
-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged_exec
-a always,exit -F arch=b32 -S execve -F euid=0 -k privileged_exec

# Monitor network connections
-a always,exit -F arch=b64 -S connect -k network_connect
-a always,exit -F arch=b32 -S connect -k network_connect

# Monitor file deletions (cover-up attempts)
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k file_deletion
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -k file_deletion

# Monitor changes to authentication files
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

# Make configuration immutable (prevent tampering)
-e 2
```

```bash
# Apply audit rules
auditctl -R /etc/audit/rules.d/99-runner-security.rules

# Restart auditd
systemctl restart auditd

# Verify rules loaded
auditctl -l
```

### Centralized Log Aggregation

Send logs to centralized system for analysis and retention.

```bash
#!/bin/bash
# Configure rsyslog to forward runner logs

cat > /etc/rsyslog.d/99-runner-logs.conf <<'EOF'
# Forward runner logs to centralized logging

# Runner service logs
:programname, isequal, "Runner.Listener" @@logs.example.com:514

# Audit logs
:programname, isequal, "audispd" @@logs.example.com:514

# UFW firewall logs
:msg, contains, "[UFW" @@logs.example.com:514
EOF

systemctl restart rsyslog
```

### Workflow Job Logging

Capture metadata for every job executed on the runner.

```bash
#!/bin/bash
# /opt/github-runner/log-job-start.sh
# Log job execution metadata

set -euo pipefail

LOG_FILE="/var/log/github-runner-jobs.log"

log_entry() {
    echo "$(date -Iseconds) | $*" >> "$LOG_FILE"
}

log_entry "JOB_START | Repo: ${GITHUB_REPOSITORY:-unknown} | Run: ${GITHUB_RUN_ID:-unknown} | SHA: ${GITHUB_SHA:-unknown} | Actor: ${GITHUB_ACTOR:-unknown}"
```

Call from workflow:

```yaml
jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - name: Log job start
        run: /opt/github-runner/log-job-start.sh
```

### Anomaly Detection

Monitor logs for suspicious patterns indicating compromise.

```bash
#!/bin/bash
# /opt/github-runner/detect-anomalies.sh
# Detect suspicious runner behavior

set -euo pipefail

ALERT_EMAIL="security-team@example.com"

# Check for metadata endpoint access attempts
if ausearch -k network_connect | grep -q "169.254.169.254"; then
    echo "ALERT: Metadata endpoint access detected" | mail -s "Runner Security Alert" "$ALERT_EMAIL"
fi

# Check for privileged command execution
if ausearch -k privileged_exec | grep -q "SUCCESS"; then
    echo "ALERT: Privileged command executed by runner" | mail -s "Runner Security Alert" "$ALERT_EMAIL"
fi

# Check for authentication file modifications
if ausearch -k identity | grep -q "SYSCALL"; then
    echo "ALERT: Authentication files modified" | mail -s "Runner Security Alert" "$ALERT_EMAIL"
fi

# Check for unexpected network destinations
ALLOWED_DESTINATIONS=(
    "140.82.112.0/20"
    "143.55.64.0/20"
    "185.199.108.0/22"
    "192.30.252.0/22"
)

# Parse network connections and alert on unexpected destinations
# Implementation depends on log format
```

Run as cron job:

```bash
# /etc/cron.d/runner-anomaly-detection
*/5 * * * * root /opt/github-runner/detect-anomalies.sh
```

## Quick Reference: Hardening Checklist

Use this checklist when deploying or auditing runner security.

### OS Hardening

- [ ] Minimal OS installation (unnecessary packages removed)
- [ ] Automatic security updates enabled
- [ ] CIS benchmarks applied
- [ ] Dedicated non-root runner user created
- [ ] No sudo access for runner user
- [ ] Restrictive filesystem mount options (noexec, nosuid, nodev)
- [ ] AppArmor profile configured and enforced

### Network Hardening

- [ ] Deny-by-default firewall rules
- [ ] Outbound allow-list for GitHub, package registries
- [ ] Cloud metadata endpoints blocked
- [ ] Private network ranges denied (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- [ ] Network namespace isolation (optional, advanced)
- [ ] IMDSv2 enforced if metadata access required

### Credential Hardening

- [ ] OIDC federation configured (no stored secrets)
- [ ] Environment variable injection for required secrets
- [ ] No secrets written to disk
- [ ] Secrets masking verified
- [ ] Short-lived credentials only (max 1 hour)

### Audit Hardening

- [ ] auditd installed and configured
- [ ] Runner execution logged
- [ ] Network connections logged
- [ ] Privileged operations logged
- [ ] Centralized log aggregation configured
- [ ] Log retention policy enforced (minimum 90 days)
- [ ] Anomaly detection monitoring active
- [ ] Security alerts configured

## Next Steps

- **[Ephemeral Runners](ephemeral.md)**: Deploy VM and container-based ephemeral runners for maximum isolation
- **[Runner Groups](groups.md)**: Organize runners by trust level and security requirements
- **[Runner Security Overview](index.md)**: Review threat model and deployment strategies

## Related Documentation

- [OIDC Federation](../secrets/oidc.md): Secretless authentication patterns
- [Secret Management](../secrets/index.md): Handling credentials securely
- [Workflow Triggers](../workflows/triggers.md): Understanding which events execute on runners
