<!-- Glossary abbreviations for site-wide tooltips -->
<!-- This file is auto-appended to all pages via pymdownx.snippets -->

<!-- Supply Chain Security -->
*[SLSA]: Supply chain Levels for Software Artifacts - A security framework with four levels for supply chain integrity using cryptographic attestation
*[Provenance]: Cryptographic proof of how an artifact was built, recording source commit and build details with digital signatures
*[Attestation]: A signed statement about software artifacts covering builds, tests, or scans using cryptographic signatures
*[SBOM]: Software Bill of Materials - A complete list of all software components including all libraries and dependencies
*[Sigstore]: An open-source project for signing software with free code signing, short-lived certificates, and transparency logs
*[Cosign]: A tool for signing container images, part of Sigstore, integrating with OCI registries and admission controllers

<!-- Policy & Compliance -->
*[Policy-as-Code]: Security and compliance policies expressed as executable code that can be version controlled, tested, and automatically enforced
*[OPA]: Open Policy Agent - A policy engine that uses Rego language for rules, evaluating policies across cloud-native stacks
*[Kyverno]: A Kubernetes-native policy engine using YAML that validates and mutates resources at local dev, CI, and runtime
*[Gatekeeper]: OPA integration for Kubernetes using Rego policies deployed as a webhook with reusable constraint templates
*[Admission Controllers]: Kubernetes components that intercept API requests before persistence to validate or mutate resources
*[Scorecard]: OpenSSF tool that measures security practices by evaluating 18 checks scoring 0 to 10

<!-- Architecture Patterns -->
*[Hub-and-Spoke]: A centralized distribution pattern where the hub controls many spoke repositories for organization-wide policies
*[Three-Stage Design]: A workflow with three phases - Discovery, Distribution, and Summary - with clear success criteria and rollback capability
*[Strangler Fig]: Incremental migration pattern for replacing legacy systems by running old and new in parallel with gradual traffic shifting
*[Separation of Concerns]: Single-responsibility components with clear boundaries where orchestration is separated from business logic
*[Matrix Distribution]: Run operations in parallel across targets using matrix strategies with discovery and parallel distribution
*[Environment Progression]: Progressive deployment across environments - dev, staging, production - with realistic testing and automated rollback

<!-- Efficiency Patterns -->
*[Idempotency]: An operation that always gives the same result whether run once or a thousand times, making retries safe
*[Work Avoidance]: Patterns for skipping unnecessary work to reduce runtime and costs using change detection and caching
*[Check-Before-Act]: Check if state exists before creating it - the most common idempotency pattern
*[Tombstone Markers]: Leave marker files when operations complete to track progress and skip work on reruns
*[Content Hashing]: Use cryptographic hashes to detect changes - if hashes match, content is identical
*[Caching]: Store results for reuse, designing for cache hits but surviving cache misses

<!-- CI/CD & Automation -->
*[GitHub Actions]: GitHub CI/CD platform where workflows run on events, jobs run in parallel, and steps execute commands
*[GitHub Apps]: Organization-level applications for authentication providing machine identity with auditable actions and higher rate limits
*[Argo Workflows]: Kubernetes workflow engine defining workflows in YAML, running steps in containers with retry and error handling
*[Argo Events]: Event-driven framework for Kubernetes connecting external systems to reactive workflows without polling
*[Release-Please]: Automated versioning tool that reads commit history, generates changelogs, and creates release PRs
*[Pre-commit Hooks]: Git hooks that run before commits to block bad code from history and check for secrets and violations
*[Reusable Workflows]: Parameterized GitHub Actions workflows that can be called from multiple repositories to centralize logic
*[Conventional Commits]: Structured commit message format (type(scope): description) enabling automated changelog and version bumps
*[WorkflowTemplate]: Reusable Argo Workflow definitions stored in Kubernetes that can be referenced and parameterized

<!-- Security & Hardening -->
*[Zero Trust]: Security model with no implicit trust where every request needs verification regardless of network location
*[Defense in Depth]: Multiple independent security layers where one breach cannot destroy everything
*[Least Privilege]: Minimum permissions principle giving only what is needed to limit damage from breaches
*[Fail Secure]: Failures default to safe states - when controls fail, deny access to prevent bypass
*[Branch Protection]: GitHub rules enforcing security on branches requiring code review, blocking force pushes, and requiring status checks
*[Commit Signing]: Cryptographic proof of authorship using GPG signatures to prove commits since Git author fields are trivial to forge
*[Workload Identity]: Cloud authentication without static keys where containers use auto-rotating JWT tokens instead of keys
*[GKE Hardening]: Defense in depth security for Google Kubernetes Engine using private clusters, Workload Identity, and Binary Authorization

<!-- Common abbreviations and acronyms -->
*[CI/CD]: Continuous Integration/Continuous Deployment
*[YAML]: YAML Ain't Markup Language
*[JSON]: JavaScript Object Notation
*[JWT]: JSON Web Token
*[OCI]: Open Container Initiative
*[OpenSSF]: Open Source Security Foundation
*[GPG]: GNU Privacy Guard
*[GKE]: Google Kubernetes Engine
*[IAM]: Identity and Access Management
*[RBAC]: Role-Based Access Control
*[API]: Application Programming Interface
*[CVE]: Common Vulnerabilities and Exposures
*[TLS]: Transport Layer Security
*[VPC]: Virtual Private Cloud
*[DAG]: Directed Acyclic Graph
