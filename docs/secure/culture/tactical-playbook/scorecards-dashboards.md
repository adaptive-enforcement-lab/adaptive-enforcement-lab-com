---
description: Build automated security scorecards that aggregate metrics from code scanning, SAST, dependency alerts, and test coverage into a single visibility dashboard.
---

# Scorecards & Dashboards

What gets measured gets managed. Make security metrics impossible to ignore.

---

## Tactic 1: Security Scorecard & Dashboards

A security scorecard gives every team member visibility into their project's security posture.

### Implementation Steps

1. **Aggregate metrics from multiple sources:**

   ```yaml
   # Example: dashboards/security-scorecard.yaml
   projects:
     - name: "api-gateway"
       metrics:
         - type: "code_scanning"
           source: "github"
           query: "state:open severity:critical"
           weight: 40
         - type: "dependency_scanning"
           source: "github"
           query: "state:open severity:critical"
           weight: 30
         - type: "sast"
           source: "sonarqube"
           metric: "security_hotspots_reviewed"
           target: 100
           weight: 20
         - type: "test_coverage"
           source: "codecov"
           metric: "coverage"
           target: 80
           weight: 10
   ```

2. **Build or integrate a dashboard:**
   - **GitHub**: Use GitHub Projects with custom views
   - **Self-hosted**: Grafana + Prometheus exporters
   - **SaaS**: Dashboards from Snyk, Checkmarx, or Lacework

3. **Calculate composite score (0-100):**

   ```python
   def calculate_scorecard(project_metrics):
       """
       Scorecard = (critical_issues_count * -5) +
                   (high_issues_count * -2) +
                   (test_coverage * 0.5) +
                   (sast_review_rate * 10)
       """
       score = 100
       score -= project_metrics['critical_issues'] * 5
       score -= project_metrics['high_issues'] * 2
       score += project_metrics['coverage'] * 0.5
       score += project_metrics['sast_review_rate'] * 10
       return max(0, min(100, score))
   ```

4. **Display in multiple contexts:**
   - Project README badge: `![Security Score](https://api.example.com/scorecard/api-gateway.svg)`
   - Team dashboard view (ranked by score)
   - Slack notifications (weekly digest)

### Metrics to Track

- **Average Team Score**: Org-wide security posture (target: >75)
- **Score Improvement Rate**: Weeks score increases (target: +2 points/week)
- **Critical Issues**: Count and MTTR (target: 0 open for >7 days)
- **Dashboard Engagement**: Views per week, actions from dashboard

### Common Pitfalls

- **Gamification Perverse Incentives**: Teams reduce scope or hide issues to improve score. Weight metrics carefully.
- **Stale Data**: Dashboards with outdated metrics lose credibility. Refresh every 6 hours.
- **Too Complex**: Scorecards with 20+ metrics confuse teams. Keep to 5-7 key indicators.
- **No Context**: A score of 72 means nothing without historical trend or peer comparison.

!!! warning "Metrics Can Mislead"
    Teams will optimize for whatever you measure. If you measure "issues closed," they'll close issues without fixing them. If you measure "score," they'll game the score. Always pair quantitative metrics with qualitative validation.

### Success Criteria

- >90% of teams regularly check scorecard (weekly)
- Org average score improves by ≥2 points per week
- Scorecard directly correlates with reduced incidents
- Teams can explain their score in <2 minutes

---

## Related Resources

- [Notifications & Badges](notifications-badges.md) - Real-time alerts and public recognition
- [Recognition & Rewards](recognition-rewards.md) - Using scorecard data for team recognition
- [Automated PR Reviews](automated-reviews.md) - Enforcement mechanisms that feed scorecard data

---

## Integration: Making Scorecards Actionable

Security scorecards drive behavior when:

1. **Data is fresh** - Real-time or near real-time updates (refresh every 6 hours max)
2. **Context is clear** - Scores include historical trends and peer comparisons
3. **Actions are obvious** - Every metric surfaces what to do next
4. **Recognition follows** - High scores and improvements are celebrated publicly

The goal: Make security status impossible to ignore and improvements impossible to miss.
