---
description: >-
  OPA Gatekeeper cluster-admin prevention template. Block cluster-admin role assignments to prevent privilege escalation attacks.
tags:
  - opa
  - gatekeeper
  - rbac
  - cluster-admin
  - kubernetes
  - templates
---

# OPA Cluster-Admin Prevention Template

Prevents assignment of cluster-admin role through RoleBindings and ClusterRoleBindings. Cluster-admin grants unrestricted cluster access and is the most common privilege escalation target.

!!! danger "Cluster-Admin = Full Cluster Control"
    The cluster-admin role bypasses all RBAC checks and grants complete control over the cluster. Attackers exploit cluster-admin bindings to compromise entire clusters.

---

## Template 3: Cluster-Admin Prevention

Blocks creation of RoleBindings and ClusterRoleBindings that reference the cluster-admin ClusterRole. Requires explicit approval process for cluster-admin access.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblockcluseteradmin
spec:
  crd:
    spec:
      names:
        kind: K8sBlockClusterAdmin
      validation:
        openAPIV3Schema:
          properties:
            allowedSubjects:
              type: array
              items:
                type: object
                properties:
                  kind:
                    type: string
                  name:
                    type: string
                  namespace:
                    type: string
              description: "Subjects allowed to receive cluster-admin role"
            blockedRoles:
              type: array
              items:
                type: string
              description: "Role names that are blocked from being assigned"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockcluseteradmin

        violation[{"msg": msg, "details": {}}] {
          binding_kind := input.review.kind.kind
          binding_kind in ["RoleBinding", "ClusterRoleBinding"]
          roleref := input.review.object.roleRef
          is_blocked_role(roleref.name)
          subject := input.review.object.subjects[_]
          not is_allowed_subject(subject)
          msg := sprintf("%v %v assigns blocked role %v to %v %v/%v",
            [binding_kind, input.review.object.metadata.name, roleref.name,
             subject.kind, object.get(subject, "namespace", "cluster"), subject.name])
        }

        is_blocked_role(role_name) {
          blocked := input.parameters.blockedRoles[_]
          role_name == blocked
        }

        is_allowed_subject(subject) {
          allowed := input.parameters.allowedSubjects[_]
          allowed.kind == subject.kind
          allowed.name == subject.name
          allowed_namespace := object.get(allowed, "namespace", "")
          subject_namespace := object.get(subject, "namespace", "")
          allowed_namespace == subject_namespace
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockClusterAdmin
metadata:
  name: block-cluster-admin-role
spec:
  enforcementAction: deny  # Use 'dryrun' for testing
  match:
    kinds:
      - apiGroups: ["rbac.authorization.k8s.io"]
        kinds: ["RoleBinding", "ClusterRoleBinding"]
  parameters:
    blockedRoles:
      - cluster-admin
      - system:masters  # Legacy admin group
    allowedSubjects:
      # Emergency break-glass account
      - kind: ServiceAccount
        name: break-glass-admin
        namespace: kube-system
      # Platform team service accounts
      - kind: ServiceAccount
        name: platform-admin
        namespace: platform-ops
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `blockedRoles` | `["cluster-admin", "system:masters"]` | Roles that cannot be assigned |
| `allowedSubjects` | Break-glass accounts | Subjects exempt from blocking |
| `enforcementAction` | `deny` | Use `dryrun` to audit existing bindings |

### Validation Commands

```bash
# Apply constraint template and constraint
kubectl apply -f opa-block-cluster-admin.yaml

# Verify installation
kubectl get constrainttemplates k8sblockcluseteradmin
kubectl get k8sblockcluseteradmin

# Test with cluster-admin binding (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: test-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: my-app
    namespace: default
EOF

# Test with allowed subject (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: break-glass-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: break-glass-admin
    namespace: kube-system
EOF

# Check violations
kubectl get k8sblockcluseteradmin block-cluster-admin-role -o yaml

# Audit existing cluster-admin bindings
kubectl get clusterrolebindings -o json | jq -r '
  .items[] |
  select(.roleRef.name == "cluster-admin") |
  "\(.metadata.name): \(.subjects[]?.kind) \(.subjects[]?.name)"
'
```

### Use Cases

1. **Privilege Escalation Prevention**: Block most common cluster compromise vector
2. **Least Privilege Enforcement**: Force teams to use scoped permissions
3. **Break-Glass Process**: Require approval workflow for emergency admin access
4. **Compliance Requirements**: Demonstrate restricted privileged access (SOC 2, PCI-DSS)
5. **Multi-tenant Security**: Prevent tenant escape through admin role abuse

---

## Understanding Cluster-Admin Risk

### Why Cluster-Admin is Dangerous

The `cluster-admin` ClusterRole grants unrestricted permissions across the entire cluster:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
```

**Attack scenarios:**

| Action | Impact |
|--------|--------|
| Read all secrets | Steal API keys, database passwords, certificates |
| Create privileged pods | Container breakout to host |
| Modify admission controllers | Disable security policies |
| Delete namespaces | Complete service disruption |
| Modify RBAC | Grant permissions to other attackers |

### Real-World Attack Example

```yaml
# Step 1: Attacker creates ClusterRoleBinding (if policy is disabled)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backdoor-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: compromised-app
    namespace: default

# Step 2: Extract service account token
kubectl get secret -n default $(kubectl get sa compromised-app -n default -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d

# Step 3: Dump all secrets from cluster
kubectl get secrets -A -o json

# Step 4: Create privileged pod for host access
kubectl run backdoor --image=alpine --overrides='
{
  "spec": {
    "hostNetwork": true,
    "hostPID": true,
    "containers": [{
      "name": "backdoor",
      "image": "alpine",
      "securityContext": {"privileged": true},
      "command": ["sleep", "infinity"]
    }]
  }
}'
```

---

## Break-Glass Access Pattern

Instead of granting permanent cluster-admin, implement time-limited emergency access:

### GitHub Actions Break-Glass Workflow

```yaml
name: Break-Glass Admin Access
on:
  workflow_dispatch:
    inputs:
      justification:
        description: 'Reason for break-glass access'
        required: true
      duration_hours:
        description: 'Duration in hours (max 4)'
        required: true
        default: '1'

jobs:
  grant-emergency-access:
    runs-on: ubuntu-latest
    permissions:
      issues: write
    steps:
      - name: Validate Request
        run: |
          if [ "${{ github.event.inputs.duration_hours }}" -gt 4 ]; then
            echo "Error: Max duration is 4 hours"
            exit 1
          fi

      - name: Create Audit Issue
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Break-Glass Access: ${context.actor}`,
              body: `**Requested by:** ${context.actor}\n**Justification:** ${{ github.event.inputs.justification }}\n**Duration:** ${{ github.event.inputs.duration_hours }}h\n**Timestamp:** ${new Date().toISOString()}`
            });

      - name: Grant Temporary Access
        run: |
          cat <<EOF | kubectl apply -f -
          apiVersion: rbac.authorization.k8s.io/v1
          kind: ClusterRoleBinding
          metadata:
            name: breakglass-${GITHUB_ACTOR}-$(date +%s)
            annotations:
              expires-at: "$(date -u -d '+${{ github.event.inputs.duration_hours }} hours' +%Y-%m-%dT%H:%M:%SZ)"
              justification: "${{ github.event.inputs.justification }}"
          roleRef:
            apiGroup: rbac.authorization.k8s.io
            kind: ClusterRole
            name: cluster-admin
          subjects:
            - kind: User
              name: ${GITHUB_ACTOR}
              apiGroup: rbac.authorization.k8s.io
          EOF

      - name: Schedule Cleanup
        run: |
          sleep $(( ${{ github.event.inputs.duration_hours }} * 3600 ))
          kubectl delete clusterrolebinding -l creator=${GITHUB_ACTOR}
```

### CronJob for Expired Binding Cleanup

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-expired-breakglass
  namespace: kube-system
spec:
  schedule: "*/15 * * * *"  # Every 15 minutes
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: breakglass-cleanup
          containers:
            - name: cleanup
              image: bitnami/kubectl:latest
              command:
                - /bin/bash
                - -c
                - |
                  NOW=$(date -u +%s)
                  kubectl get clusterrolebindings -o json | jq -r '
                    .items[] |
                    select(.metadata.annotations."expires-at" != null) |
                    select((.metadata.annotations."expires-at" | fromdateiso8601) < '$NOW') |
                    .metadata.name
                  ' | xargs -r kubectl delete clusterrolebinding
          restartPolicy: OnFailure
```

---

## Related Resources

- **[OPA RBAC Templates →](overview.md)** - Service account and namespace restrictions
- **[OPA Privileged Verbs Templates →](privileged-verbs.md)** - Block dangerous RBAC verbs
- **[OPA Wildcard Templates →](wildcards.md)** - Prevent wildcard resource permissions
- **[OPA Pod Security Templates →](../opa-pod-security/overview.md)** - Privileged containers and host namespaces
- **[Decision Guide →](../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
