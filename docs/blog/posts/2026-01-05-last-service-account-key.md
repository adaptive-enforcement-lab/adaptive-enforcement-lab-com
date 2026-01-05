---
title: The Last Service Account Key
date: 2026-01-05
authors:
  - mark
categories:
  - Cloud Security
  - GCP
  - Kubernetes
description: >-
  When you delete the last JSON key file from production. The Workload Identity migration that eliminated credential leaks forever.
slug: last-service-account-key
---
# The Last Service Account Key

```text
$ git log --all --oneline -- '**/service-account.json' | wc -l
47

$ git log --all --oneline -- '**/service-account.json' | head -1
a3f8c2e delete: remove production service account key
```

That commit sits in your history like a monument. Not because of what it added, but because of what it finally took away. Forty-seven commits that existed only to move secrets around, rotate them, revoke them, apologize for them, and eventually eliminate them.

That last deletion was the sound of the door closing on an entire class of infrastructure vulnerability.

<!-- more -->

## The Weight of a JSON File

For years, service account keys were the only tool in the drawer. Your Pod needed to authenticate to a GCP service? JSON key in a Secret. Your pipeline needed to push to Cloud Storage? JSON key in environment variables. Your batch job needed to run queries? You guessed it.

But JSON keys have a gravity all their own.

!!! danger "Keys Leak Everywhere"
    JSON keys leak. Always. Everywhere. It's not if, it's when and how many times before you find them all.

- A developer commits one to git "just temporarily"
- It gets pushed before anyone notices
- The key is now in the repository history, backed up, cached, forever
- Someone clones the repo at 2 AM in a panic to debug something
- Three months later, a security scanner finds it in a fork they created and forgot about
- Another three months later, someone rotates it, except nobody can find all the places it was deployed
- A year later, someone finds it in a pod log file from when the application crashed

Each key is a thread. Pull it and the whole fabric unravels. Rotation becomes a nightmare. Revocation becomes archaeology. Compliance becomes storytelling.

But there's a different way. One that doesn't require keys at all.

## The Discovery: Authentication Without Keys

Workload Identity is a pattern that does something radical: it makes the Pod itself the credential.

Here's how it works:

Pod identity → Kubernetes Service Account → GCP Service Account → IAM bindings → Access to resources

No JSON file. No base64-encoded secret. No leaky environment variable. The Pod proves its identity through environment and metadata. GCP verifies it through cryptographic identity.

The Pod running in your cluster has built-in metadata about:

- The Kubernetes cluster it's in
- The Kubernetes namespace where it runs
- The Kubernetes Service Account it uses
- Cryptographic proof it actually is that workload

GCP can verify all of this without ever seeing a secret. The Pod calls the metadata server at `http://metadata.google.internal`, proves its identity, and gets a short-lived token. No long-lived credential. No key to steal.

This is the pattern that eliminates the threat model entirely.

## The Struggle: Migration at Scale

Converting from keys to Workload Identity isn't simple. It requires:

1. **Understanding what needs access** - Audit every Pod and figure out what GCP resources it touches
2. **Creating GCP Service Accounts** - One per logical workload, configured with minimal IAM bindings
3. **Binding Kubernetes → GCP identities** - Using Workload Identity binding to link the k8s Service Account to the GCP Service Account
4. **Updating Pod specs** - Removing secret mounts, adding the necessary Kubernetes Service Account annotation
5. **Testing the migration** - For each workload, verify it can still access what it needs
6. **Cleaning up the old keys** - Removing the JSON keys, the Secrets, the environment variables, the scattered copies

For a production system, this is hundreds of decisions. Hundreds of test cases. Hundreds of potential places where something breaks silently.

But the path forward is clear: no key, no leak.

## The Victory: Zero Findings

The moment your security scan runs and reports:

> Service account JSON keys found in production: **0**

That's not just a metric. That's a principle finally enforced.

Every Pod authenticates via Workload Identity. Every GCP service uses least-privilege IAM bindings. Every credential is short-lived and bound to the identity of a specific workload. There's nothing to extract, nothing to rotate on a deadline, nothing to apologize for in the next security audit.

!!! success "Attack Surface Eliminated"
    The attack surface that existed for years is simply gone. Not reduced. Gone. That last commit that deleted the final JSON key crossed a threshold.

## What Changed: Before and After

### Before Workload Identity

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gcp-credentials
type: Opaque
data:
  service-account.json: eyJw... # 47 commits ago
---
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/credentials.json
    volumeMounts:
    - name: credentials
      mountPath: /secrets
  volumes:
  - name: credentials
    secret:
      secretName: gcp-credentials
```

### After Workload Identity

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  annotations:
    iam.gke.io/gcp-service-account: my-app@project-id.iam.gserviceaccount.com
---
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app
  containers:
  - name: app
    # No secrets. No environment variables.
    # Pod authenticates automatically via metadata server.
```

The code that uses GCP services barely changes. The authentication layer becomes invisible.

## The Real Cost of Keys

Each JSON key that existed cost:

- **Rotation overhead**: Every 90 days or on breach, redeploy everywhere the key lived
- **Audit burden**: Track every deployed key, verify it's still in use, prove when it was rotated
- **Incident response time**: When a key leaks, you have minutes to identify and revoke before attackers potentially use it
- **Team context switching**: Every key rotation is an interruption that pulls someone from their actual work
- **Compliance risk**: Every unrotated key is a compliance violation waiting to be found

Workload Identity removes all of that by making long-lived credentials unnecessary.

## The Enforcement Pattern

Workload Identity only works if it's enforced:

1. **Prohibit Secrets containing service account JSON**: Use a policy to reject any Secret that looks like a GCP service account key
2. **Require Workload Identity annotations**: Every Pod that accesses GCP must have the binding annotation
3. **Audit all authentication methods**: When a Pod accesses GCP, log what identity was used
4. **Review IAM bindings quarterly**: Make sure each workload only has access to what it actually needs

Enforcement turns an optional pattern into a standard.

## Related

- [Workload Identity Guide](../../secure/cloud-native/workload-identity/index.md) - Complete implementation guide
- [Least Privilege IAM Roles](../../secure/cloud-native/gke-hardening/iam-configuration/least-privilege-roles.md) - Design IAM bindings that minimize blast radius
- [Credential Rotation Security](../../secure/github-apps/storing-credentials/rotation-security.md) - When you still need to rotate things
- [Audit Logging Configuration](../../secure/cloud-native/gke-hardening/iam-configuration/audit-logging.md) - Making every identity change traceable
