---
title: Notifications & Badges
description: Implement real-time Slack notifications and public security badges to drive immediate feedback and build visible recognition systems across engineering teams.
---
# Notifications & Badges

Real-time feedback and public recognition drive behavior change.

---

## Tactic 1: Slack Notifications & Alerts

!!! warning "Alert Fatigue Kills Security Culture"
    Too many notifications cause Slack muting. Only alert on truly actionable items. Aim for >80% of alerts resulting in action. Noise destroys signal.

Real-time notifications in Slack where developers work ensure issues get immediate attention.

### Implementation Steps

1. **Configure GitHub to Slack notifications:**

   ```bash
   # Install GitHub app in Slack workspace
   # Subscribe to channels for security events
   /github subscribe adaptive-enforcement-lab/repo code_scanning
   /github subscribe adaptive-enforcement-lab/repo secret_scanning
   /github subscribe adaptive-enforcement-lab/repo dependabot
   ```

2. **Build custom Slack bot for security events:**

   ```python
   from slack_sdk import WebClient
   from github import Github

   def notify_security_issue(repo, issue):
       client = WebClient(token=SLACK_TOKEN)

       blocks = [
           {
               "type": "header",
               "text": {
                   "type": "plain_text",
                   "text": f"🔒 {issue['severity'].upper()}: {issue['title']}",
                   "emoji": True
               }
           },
           {
               "type": "section",
               "text": {
                   "type": "mrkdwn",
                   "text": f"*Repo:* {repo}\n*File:* `{issue['file']}`\n*Lines:* {issue['lines']}"
               }
           },
           {
               "type": "section",
               "text": {
                   "type": "mrkdwn",
                   "text": f"```{issue['snippet']}```"
               }
           },
           {
               "type": "actions",
               "elements": [
                   {
                       "type": "button",
                       "text": {"type": "plain_text", "text": "View PR"},
                       "url": issue['pr_url']
                   },
                   {
                       "type": "button",
                       "text": {"type": "plain_text", "text": "Review"},
                       "url": issue['review_url'],
                       "style": "danger"
                   }
               ]
           }
       ]

       client.chat_postMessage(
           channel="#security-alerts",
           blocks=blocks
       )
   ```

3. **Set notification thresholds:**
   - **Instant**: Critical secrets, hardcoded credentials
   - **Daily Digest**: High-severity vulnerabilities (grouped by priority)
   - **Weekly Summary**: Team scorecard changes, trend analysis

4. **Route alerts to on-call engineer:**

   ```yaml
   # Example: alert routing
   critical:
     - channel: "#security-incidents"
     - @on-call-security via PagerDuty
     - Slack thread notifications

   high:
     - channel: "#security-alerts"
     - Daily digest at 9 AM
     - Team scorecard dashboard

   medium:
     - Weekly summary email
     - Dashboard only
   ```

### Metrics to Track

- **Notification Engagement**: % of Slack alerts that receive a reaction/reply
- **Time to Acknowledge**: Median time from alert to developer acknowledgment
- **Resolution Rate**: % of alerts resolved within SLA (critical: 4h, high: 24h)
- **Alert Noise**: Ratio of actionable alerts to total alerts (target: >80%)

### Common Pitfalls

- **Alert Fatigue**: Too many notifications cause Slack muting. Only alert on truly actionable items.
- **Duplicate Alerts**: GitHub + custom bot + integrations equals noise. Consolidate into single channel.
- **No Action Path**: Alert with no next step gets ignored. Every alert must include severity, impact, remediation, responsible person.
- **Always-On Notifications**: Developers turn off notifications. Use escalation rules instead.

### Success Criteria

- >70% of critical alerts acknowledged within 1 hour
- >90% of alerts are genuinely actionable
- Teams report using notifications to prioritize work
- No developer has muted security channels

---

## Tactic 2: Public Badges & Recognition

!!! tip "Badges Must Be Accurate"
    Fake compliance destroys badge credibility. If teams game metrics to maintain green badges, the system is broken. Weight multiple indicators. Audit badge accuracy monthly.

Visible recognition drives behavior change. Public badges on repositories and READMEs signal security investment to users and teams.

### Implementation Steps

1. **Create security badges in README:**

   ```markdown
   # Project Name

   [![Security Score](https://api.example.com/badge/critical-issues?repo=api-gateway)](https://dashboard.example.com/api-gateway)
   [![SAST Coverage](https://api.example.com/badge/sast-coverage?repo=api-gateway)](https://sonar.example.com/api-gateway)
   [![Dependencies](https://img.shields.io/librariesio/release/npm/express)](https://deps.example.com)
   [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
   ```

2. **Generate badges programmatically:**

   ```python
   from PIL import Image, ImageDraw
   import requests

   def generate_badge(label, value, status):
       """Generate SVG badge for security metrics"""
       colors = {
           "critical": "#d62728",  # red
           "high": "#ff7f0e",      # orange
           "medium": "#ffbb78",    # light orange
           "low": "#2ca02c",       # green
       }

       svg = f"""
       <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
            width="120" height="20">
           <linearGradient id="b" x2="0" y2="100%">
               <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
               <stop offset="1" stop-opacity=".1"/>
           </linearGradient>
           <clipPath id="a">
               <rect width="120" height="20" rx="3"/>
           </clipPath>
           <g clip-path="url(#a)">
               <path fill="#555" d="M0 0h100v20H0z"/>
               <path fill="{colors[status]}" d="M100 0h20v20H100z"/>
               <path fill="url(#b)" d="M0 0h120v20H0z"/>
           </g>
           <g>
               <text x="50" y="14" fill="#fff" font-size="11" font-family="DejaVu Sans">{label}</text>
               <text x="110" y="14" fill="#fff" font-size="11" font-family="DejaVu Sans" text-anchor="middle">{value}</text>
           </g>
       </svg>
       """
       return svg
   ```

3. **Display on team portal/README:**
   - Team dashboard with project badges
   - Monthly "Security Excellence" announcement
   - Internal blog post highlighting achievements

### Metrics to Track

- **Badge Views**: Downloads of badge image per week
- **README Updates**: % of projects with security badges
- **Team Awareness**: Survey on recognition effectiveness
- **Contribution Correlation**: Do badge-prominent projects have faster issue resolution?

### Common Pitfalls

- **Fake Compliance**: Team adds badge but doesn't improve security. Badge loses credibility.
- **Metric Gaming**: Teams suppress issues to maintain high score. Weight multiple indicators.
- **Recognition Ignore**: Public badges mean nothing if org doesn't celebrate success. Announce winners.

### Success Criteria

- >80% of projects display security badges
- >50% of team can articulate their project's security posture
- Security metrics correlate with deployment velocity (secure code ships faster)

---

## Related Resources

- [Scorecards & Dashboards](scorecards-dashboards.md) - Source data for notifications and badges
- [Recognition & Rewards](recognition-rewards.md) - Public recognition programs
- [Automated PR Reviews](automated-reviews.md) - Generating notifications from CI/CD

---

## Integration: Making Notifications Actionable

Security notifications and badges drive behavior when:

1. **Alerts are actionable** - Every notification includes severity, impact, and remediation
2. **Noise is minimized** - >80% of alerts are genuinely actionable
3. **Badges are credible** - Metrics are fresh and correlate with actual security posture
4. **Recognition follows** - Public badges lead to team celebration and career impact

The goal: Make security feedback immediate, visible, and impossible to ignore.
