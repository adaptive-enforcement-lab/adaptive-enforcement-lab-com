---
date: 2026-01-02
authors:
  - mark
categories:
  - Cloud Security
  - Kubernetes
  - GCP
description: >-
  When penetration testers give up after 3 days. The GKE hardening guide that turned a cluster into a fortress.
slug: gke-cluster-nobody-could-break
---

# The GKE Cluster That Nobody Could Break

**Day 1 of pentest.** Security firm arrives with methodology, tools, and confidence. The plan is simple: find gaps in the Kubernetes cluster, prove impact, deliver a detailed report of findings.

**Day 2.** They're quiet. Too quiet.

**Day 3.** Meeting request. Not the kind where they show you their findings.

"We found nothing. Well, nothing critical. Actually, we found nothing at all. This is the best-hardened cluster we've tested. Want to know what you did right?"

That's not how pentest reports usually end.

<!-- more -->

## The Default GKE Cluster: An Open Door

By default, GKE clusters expose multiple attack vectors simultaneously:

### Public API Endpoints

- Kubernetes API server accessible from anywhere (without authentication bypass, but still)
- Cluster network open to pod-to-pod communication
- No network policies preventing lateral movement
- kubelet APIs unauthenticated by default

### Pod Privileges

- Pods run with broad service account permissions
- No admission controllers blocking privileged containers
- Host mounts possible without restrictions
- Container escape risks unmitigated

### Image Security

- No image signature verification
- No binary authorization policy
- Container registries trusted implicitly
- No scanning before deployment

### Supply Chain

- No audit logging of cluster modifications
- No immutable audit logs
- RBAC too permissive (cluster-admin easy to grant)
- Secrets stored in etcd unencrypted

Pentesters typically exploit 2-3 of these simultaneously.

!!! warning "The Default: Not Actually Default"
    GKE's out-of-the-box configuration is production-adjacent, not production-hardened. You must actively harden it.

---

## The Hardening Strategy: Eliminate Each Vector

Instead of patching holes, the GKE security hardening guide removes the doors entirely.

### 1. Network Isolation (Deny by Default)

```yaml
# Network policy: deny everything, allow explicitly
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

Result: Pods can't talk to anything unless explicitly allowed. No lateral movement, no cross-namespace explosions.

### 2. Pod Security Standards (No Privileged Containers)

```yaml
# Pod security policy: reject privileged, require security context
apiVersion: pod-security.k8s.io/v1beta1
kind: Pod
metadata:
  name: restricted-example
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsReadOnlyRootFilesystem: true
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

Result: Containers can't escalate, can't write to root filesystem, can't use dangerous capabilities. Container escape leads nowhere.

### 3. Binary Authorization (Trust Nothing)

Enable Kubernetes-native signed image enforcement:

- Only signed container images deploy
- Signing keys managed in Cloud KMS
- CI/CD pipeline signs before pushing
- Clusters verify signatures before admission

Result: Pentesters can't inject unsigned images. Supply chain is locked.

### 4. Encryption at Rest (Default in GKE)

Application-layer Encryption with Customer-Managed Keys (CMEK):

- etcd encrypted with Google-managed or customer-managed keys
- Secrets encrypted before storage
- Keys rotated automatically
- Audit logs show who accessed what

Result: Even if someone breaches etcd, they get ciphertext.

### 5. Comprehensive Audit Logging

```yaml
# GKE cluster created with audit logs enabled
gcloud container clusters create hardened-cluster \
  --enable-cloud-logging \
  --logging=SYSTEM,WORKLOAD,API_SERVER
```

Every API call logged:

- Who made it
- What they did
- Whether it succeeded
- Immutable storage in Cloud Logging

Result: Nothing happens without leaving a trail.

### 6. Workload Identity (Eliminate Static Keys)

```yaml
# Pod uses Workload Identity, not static service account keys
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  annotations:
    iam.gke.io/gcp-service-account: app@project.iam.gserviceaccount.com
```

Result: No service account keys to steal. Credentials are ephemeral, bound to pod identity.

### 7. Private Cluster (No Public API Endpoint)

```bash
gcloud container clusters create hardened-cluster \
  --enable-ip-alias \
  --network custom-network \
  --subnetwork custom-subnet \
  --enable-private-nodes \
  --enable-private-endpoint \
  --master-ipv4-cidr 172.16.0.0/28
```

Result: Kubernetes API not accessible from the internet. Access only through VPN or authorized networks.

---

## The Pentest Report: Nothing to Find

When pentesters checked every attack surface, they found:

| Attack Vector | Status | Why It Failed |
| ------------- | ------ | ------------- |
| Pod escape to host | Blocked | Privileged containers rejected at admission |
| Lateral pod movement | Blocked | Network policies deny by default |
| Unsigned image injection | Blocked | Binary authorization enforces signatures |
| Static credential theft | Blocked | Workload Identity with ephemeral tokens |
| API abuse | Blocked | Private endpoint, no public access |
| etcd breach | Mitigated | Encrypted at rest with CMEK |
| Privilege escalation | Blocked | RBAC restrictive by default |
| Cluster takeover | Audited | Every action logged, immutable audit trail |

Their report read like a security dream: "We have no critical or high-severity findings."

---

## What Made the Difference

This wasn't magic. It was systematic elimination:

1. **Start with deny-by-default**: Network policies, pod security, RBAC
2. **Encrypt everything**: At-rest, in-transit, keys managed separately
3. **Log everything**: Immutable audit trails, searchable, long retention
4. **Trust nothing**: Signed images, Workload Identity, no static secrets
5. **Test continuously**: Regular penetration testing to verify controls work

Each control is boring individually. Together, they make a cluster that pentesters literally can't break.

---

## The Real Cost

This level of hardening isn't free:

- **Operational complexity**: More policies, more admission rules, more debugging
- **Developer friction**: Pods need explicit network policies, security contexts
- **Audit overhead**: Immutable logs consume storage and ingestion
- **Initial setup**: Weeks to implement across an organization

But the alternative is this:

- Cluster gets breached
- Containment takes weeks
- Customer notification, regulatory fines
- Incident response costs 100x what hardening cost

!!! success "The Economics Are Clear"
    Spend hours hardening. Or spend months recovering from a breach. The math works.

---

## How to Start

The [GKE Security Hardening](../../secure/cloud-native/gke-hardening/index.md) guide provides:

- Step-by-step hardening checklist
- Terraform/Helm configurations for each control
- Testing methodology to verify each layer
- Troubleshooting when legitimate traffic breaks
- Metrics to track your security posture

Hardening a cluster takes time, but hardening from day one takes less time than retrofitting.

---

## Conclusion

The pentesters left disappointed not because the cluster was boring, but because it was *unremarkable in its security*. No shortcuts. No clever tricks. Just systematic elimination of every attack vector they could think of.

That's the goal: a cluster so thoroughly hardened that finding vulnerabilities requires not tools or methodology, but pure luck.

---

## Related

- [GKE Security Hardening](../../secure/cloud-native/gke-hardening/index.md) - Detailed hardening guide with configurations
- [Network Policy Patterns](../../secure/cloud-native/gke-hardening/network-security/index.md) - Deny-by-default network control
- [Pod Security Standards](../../secure/cloud-native/gke-hardening/runtime-security/index.md) - Container privilege restrictions
- [Workload Identity](../../secure/cloud-native/workload-identity/index.md) - Ephemeral credentials without keys
