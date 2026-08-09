
import re
import os

def check_links_in_markdown_files(all_markdown_files):
    """
    Checks all internal links within a set of markdown files for existence.

    Args:
        all_markdown_files (list): A list of all markdown file paths (e.g., "docs/path/to/file.md").

    Returns:
        list: A list of invalid links found. Each invalid link is a dict
                with 'source_file', 'link_text', 'original_link', 'resolved_path', 'reason'.
    """
    invalid_links = []
    
    # Normalize all_markdown_files for easier lookup (MkDocs friendly)
    # A set for fast lookup of existing content paths
    normalized_content_paths = set()
    for f in all_markdown_files:
        # Remove 'docs/' prefix
        content_path = f.replace('docs/', '')
        
        # Remove '.md' suffix
        content_path = content_path.replace('.md', '')
        
        # Handle 'index' files: 'dir/index' should also be accessible as 'dir/' or 'dir'
        if content_path.endswith('/index'):
            normalized_content_paths.add(content_path.rsplit('/index', 1)[0]) # e.g., 'dir/index' -> 'dir'
            normalized_content_paths.add(content_path) # keep 'dir/index' for direct links
        else:
            normalized_content_paths.add(content_path)
    
    # Add an empty string for the root index.md which is often linked as '/' or just ''
    if 'index' in normalized_content_paths:
        normalized_content_paths.add('')

    # Regex to find markdown links [text](link)
    link_pattern = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')

    for file_path in all_markdown_files:
        try:
            with open(file_path, 'r') as f:
                markdown_content = f.read()
        except FileNotFoundError:
            invalid_links.append({
                'source_file': file_path.replace('docs/', ''),
                'link_text': '',
                'original_link': '',
                'resolved_path': '',
                'reason': 'Source file not found (should not happen if all_markdown_files is accurate)'
            })
            continue

        for match in link_pattern.finditer(markdown_content):
            link_text = match.group(1)
            original_link = match.group(2)

            # Ignore external links
            if original_link.startswith('http://') or original_link.startswith('https://'):
                continue
            
            # Ignore anchor-only links within the same file (e.g., #section) for now.
            # Checking anchors within a file requires parsing markdown headers, which is more complex.
            # Focusing on file existence first.
            if original_link.startswith('#'):
                continue

            # Split link into path and optional anchor
            link_parts = original_link.split('#', 1)
            link_path_no_anchor = link_parts[0]
            # link_anchor = '#' + link_parts[1] if len(link_parts) > 1 else ''

            # Resolve relative path
            # The current file's directory relative to 'docs/'
            current_file_dir = os.path.dirname(file_path).replace('docs', '', 1).strip('/')
            
            # Construct the full path from the root of 'docs/'
            # os.path.join handles '.' and '..' correctly
            if current_file_dir:
                resolved_full_path = os.path.normpath(os.path.join(current_file_dir, link_path_no_anchor))
            else: # If current_file_dir is empty (root of docs)
                resolved_full_path = os.path.normpath(link_path_no_anchor)

            # Normalize the resolved path for lookup in normalized_content_paths
            # Remove .md suffix
            lookup_path = resolved_full_path.replace('.md', '')
            
            # Special handling for root link '/'. It should resolve to 'index' or ''
            if lookup_path == '/':
                lookup_path = ''
            elif lookup_path.startswith('/'): # Remove leading slash if not root
                 lookup_path = lookup_path[1:]


            if lookup_path not in normalized_content_paths:
                invalid_links.append({
                    'source_file': file_path.replace('docs/', ''),
                    'link_text': link_text,
                    'original_link': original_link,
                    'resolved_path': lookup_path,
                    'reason': 'Target content path not found'
                })

    return invalid_links

# The list of markdown files from the `find` command output
all_md_files = [
    "docs/roadmap.md", "docs/index.md", "docs/about/connect.md",
    "docs/about/index.md", "docs/about/mission.md", "docs/about/principles.md",
    "docs/about/approach.md", "docs/about/brand.md", "docs/about/audience.md",
    "docs/tags.md", "docs/patterns/reliability/chaos-engineering/experiments.md",
    "docs/patterns/reliability/chaos-engineering/validation.md",
    "docs/patterns/reliability/chaos-engineering/index.md",
    "docs/patterns/reliability/chaos-engineering/tools-comparison.md",
    "docs/patterns/reliability/chaos-engineering/resource-experiments.md",
    "docs/patterns/reliability/chaos-engineering/blast-radius.md",
    "docs/patterns/reliability/chaos-engineering/experiment-design/hypothesis.md",
    "docs/patterns/reliability/chaos-engineering/experiment-design/validation.md",
    "docs/patterns/reliability/chaos-engineering/experiment-design/index.md",
    "docs/patterns/reliability/chaos-engineering/experiment-design/sli-monitoring.md",
    "docs/patterns/reliability/chaos-engineering/experiment-design/blast-radius.md",
    "docs/patterns/reliability/chaos-engineering/experiment-design/success-criteria.md",
    "docs/patterns/reliability/chaos-engineering/network-experiments.md",
    "docs/patterns/reliability/chaos-engineering/observability.md",
    "docs/patterns/reliability/chaos-engineering/dependency-experiments.md",
    "docs/patterns/reliability/chaos-engineering/pod-experiments.md",
    "docs/patterns/reliability/chaos-engineering/operations.md",
    "docs/patterns/index.md", "docs/patterns/github-actions/actions-integration/using-tokens.md",
    "docs/patterns/github-actions/actions-integration/index.md",
    "docs/patterns/github-actions/actions-integration/workflow-permissions.md",
    "docs/patterns/github-actions/actions-integration/token-generation/index.md",
    "docs/patterns/github-actions/actions-integration/token-generation/workflow-patterns.md",
    "docs/patterns/github-actions/actions-integration/token-generation/use-cases.md",
    "docs/patterns/github-actions/actions-integration/token-generation/lifecycle-security.md",
    "docs/patterns/github-actions/actions-integration/troubleshooting.md",
    "docs/patterns/github-actions/actions-integration/token-validation.md",
    "docs/patterns/github-actions/actions-integration/security-best-practices.md",
    "docs/patterns/github-actions/actions-integration/token-lifecycle/caching-rate-limits.md",
    "docs/patterns/github-actions/actions-integration/token-lifecycle/index.md",
    "docs/patterns/github-actions/actions-integration/token-lifecycle/long-workflows.md",
    "docs/patterns/github-actions/actions-integration/token-lifecycle/refresh-patterns.md",
    "docs/patterns/github-actions/actions-integration/token-lifecycle/best-practices.md",
    "docs/patterns/github-actions/actions-integration/jwt-authentication/security-troubleshooting.md",
    "docs/patterns/github-actions/actions-integration/jwt-authentication/index.md",
    "docs/patterns/github-actions/actions-integration/performance-optimization.md",
    "docs/patterns/github-actions/actions-integration/error-handling/rate-limiting.md",
    "docs/patterns/github-actions/actions-integration/error-handling/index.md",
    "docs/patterns/github-actions/actions-integration/error-handling/best-practices.md",
    "docs/patterns/github-actions/actions-integration/oauth-authentication/security-troubleshooting.md",
    "docs/patterns/github-actions/actions-integration/oauth-authentication/index.md",
    "docs/patterns/github-actions/actions-integration/oauth-authentication/device-flow.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/index.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/path-filtering.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/content-comparison.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/cache-based-skip.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/matrix-patterns/index.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/matrix-patterns/path-filtering.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/matrix-patterns/advanced-patterns.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/matrix-patterns/matrix-optimization.md",
    "docs/patterns/github-actions/use-cases/work-avoidance/matrix-patterns/caching-artifacts.md",
    "docs/patterns/github-actions/use-cases/file-distribution/discovery-stage.md",
    "docs/patterns/github-actions/use-cases/file-distribution/workflow-config.md",
    "docs/patterns/github-actions/use-cases/file-distribution/index.md",
    "docs/patterns/github-actions/use-cases/file-distribution/summary-stage.md",
    "docs/patterns/github-actions/use-cases/file-distribution/performance.md",
    "docs/patterns/github-actions/use-cases/file-distribution/architecture.md",
    "docs/patterns/github-actions/use-cases/file-distribution/troubleshooting.md",
    "docs/patterns/github-actions/use-cases/file-distribution/error-handling.md",
    "docs/patterns/github-actions/use-cases/file-distribution/supporting-scripts.md",
    "docs/patterns/github-actions/use-cases/file-distribution/monitoring.md",
    "docs/patterns/github-actions/use-cases/file-distribution/distribution-stage.md",
    "docs/patterns/github-actions/use-cases/file-distribution/security.md",
    "docs/patterns/github-actions/use-cases/file-distribution/extension-patterns.md",
    "docs/patterns/github-actions/use-cases/file-distribution/idempotency.md",
    "docs/patterns/security/secure-by-design/fail-secure.md",
    "docs/patterns/security/secure-by-design/index.md",
    "docs/patterns/security/secure-by-design/defense-in-depth.md",
    "docs/patterns/security/secure-by-design/least-privilege.md",
    "docs/patterns/security/secure-by-design/integration.md",
    "docs/patterns/security/secure-by-design/zero-trust.md",
    "docs/patterns/argo-workflows/scheduled/index.md",
    "docs/patterns/argo-workflows/scheduled/concurrency-policy.md",
    "docs/patterns/argo-workflows/scheduled/orchestration.md",
    "docs/patterns/argo-workflows/scheduled/github-integration.md",
    "docs/patterns/argo-workflows/scheduled/basic.md",
    "docs/patterns/argo-workflows/index.md",
    "docs/patterns/argo-workflows/concurrency/index.md",
    "docs/patterns/argo-workflows/concurrency/semaphores.md",
    "docs/patterns/argo-workflows/concurrency/mutex.md",
    "docs/patterns/argo-workflows/concurrency/ttl.md",
    "docs/patterns/argo-workflows/templates/rbac.md",
    "docs/patterns/argo-workflows/templates/volume-patterns.md",
    "docs/patterns/argo-workflows/templates/index.md",
    "docs/patterns/argo-workflows/templates/init-containers.md",
    "docs/patterns/argo-workflows/templates/retry-strategy.md",
    "docs/patterns/argo-workflows/templates/basic-structure.md",
    "docs/patterns/argo-workflows/composition/index.md",
    "docs/patterns/argo-workflows/composition/communication.md",
    "docs/patterns/argo-workflows/composition/dag.md",
    "docs/patterns/argo-workflows/composition/spawning-children.md",
    "docs/patterns/argo-workflows/composition/parallel.md",
    "docs/patterns/efficiency/index.md",
    "docs/patterns/efficiency/work-avoidance/index.md",
    "docs/patterns/efficiency/work-avoidance/anti-patterns.md",
    "docs/patterns/efficiency/work-avoidance/techniques/queue-cleanup.md",
    "docs/patterns/efficiency/work-avoidance/techniques/index.md",
    "docs/patterns/efficiency/work-avoidance/techniques/cache-based-skip.md",
    "docs/patterns/efficiency/work-avoidance/techniques/existence-checks.md",
    "docs/patterns/efficiency/work-avoidance/techniques/content-hashing.md",
    "docs/patterns/efficiency/work-avoidance/techniques/volatile-field-exclusion.md",
    "docs/patterns/efficiency/idempotency/pros-and-cons.md",
    "docs/patterns/efficiency/idempotency/decision-matrix.md",
    "docs/patterns/efficiency/idempotency/index.md",
    "docs/patterns/efficiency/idempotency/real-world-example.md",
    "docs/patterns/efficiency/idempotency/patterns/force-overwrite.md",
    "docs/patterns/efficiency/idempotency/patterns/index.md",
    "docs/patterns/efficiency/idempotency/patterns/unique-identifiers.md",
    "docs/patterns/efficiency/idempotency/patterns/upsert.md",
    "docs/patterns/efficiency/idempotency/patterns/tombstone-markers/index.md",
    "docs/patterns/efficiency/idempotency/patterns/tombstone-markers/edge-cases.md",
    "docs/patterns/efficiency/idempotency/patterns/tombstone-markers/ci-cd-examples.md",
    "docs/patterns/efficiency/idempotency/patterns/check-before-act.md",
    "docs/patterns/efficiency/idempotency/caches.md",
    "docs/patterns/efficiency/idempotency/testing.md",
    "docs/patterns/error-handling/index.md",
    "docs/patterns/error-handling/prerequisite-checks/examples.md",
    "docs/patterns/error-handling/prerequisite-checks/index.md",
    "docs/patterns/error-handling/prerequisite-checks/ordering.md",
    "docs/patterns/error-handling/prerequisite-checks/checks/state.md",
    "docs/patterns/error-handling/prerequisite-checks/checks/environment.md",
    "docs/patterns/error-handling/prerequisite-checks/checks/permissions.md",
    "docs/patterns/error-handling/prerequisite-checks/checks/input.md",
    "docs/patterns/error-handling/prerequisite-checks/checks/dependencies.md",
    "docs/patterns/error-handling/prerequisite-checks/anti-patterns.md",
    "docs/patterns/error-handling/prerequisite-checks/implementation.md",
    "docs/patterns/error-handling/fail-fast/index.md",
    "docs/patterns/error-handling/fail-fast/techniques/error-escalation.md",
    "docs/patterns/error-handling/fail-fast/techniques/timeouts.md",
    "docs/patterns/error-handling/fail-fast/techniques/assertions.md",
    "docs/patterns/error-handling/fail-fast/techniques/early-termination.md",
    "docs/patterns/error-handling/fail-fast/techniques/strict-mode.md",
    "docs/patterns/error-handling/graceful-degradation/index.md",
    "docs/patterns/argo-events/setup/index.md",
    "docs/patterns/argo-events/setup/sensors.md",
    "docs/patterns/argo-events/setup/event-bus.md",
    "docs/patterns/argo-events/setup/event-sources.md",
    "docs/patterns/argo-events/reliability/backpressure.md",
    "docs/patterns/argo-events/reliability/index.md",
    "docs/patterns/argo-events/reliability/dead-letter.md",
    "docs/patterns/argo-events/reliability/high-availability.md",
    "docs/patterns/argo-events/reliability/retry.md",
    "docs/patterns/argo-events/index.md",
    "docs/patterns/argo-events/troubleshooting/index.md",
    "docs/patterns/argo-events/troubleshooting/eventsources.md",
    "docs/patterns/argo-events/troubleshooting/sensors.md",
    "docs/patterns/argo-events/troubleshooting/common-patterns.md",
    "docs/patterns/argo-events/routing/transformation.md",
    "docs/patterns/argo-events/routing/index.md",
    "docs/patterns/argo-events/routing/filtering.md",
    "docs/patterns/argo-events/routing/conditional.md",
    "docs/patterns/argo-events/routing/multi-trigger.md",
    "docs/patterns/architecture/hub-and-spoke/examples.md",
    "docs/patterns/architecture/hub-and-spoke/index.md",
    "docs/patterns/architecture/hub-and-spoke/pattern-comparison.md",
    "docs/patterns/architecture/hub-and-spoke/push-pull-patterns.md",
    "docs/patterns/architecture/hub-and-spoke/operations.md",
    "docs/patterns/architecture/index.md",
    "docs/patterns/architecture/separation-of-concerns/index.md",
    "docs/patterns/architecture/separation-of-concerns/guide.md",
    "docs/patterns/architecture/separation-of-concerns/workflow-examples.md",
    "docs/patterns/architecture/separation-of-concerns/implementation.md",
    "docs/patterns/architecture/three-stage-design.md",
    "docs/patterns/architecture/strangler-fig/index.md",
    "docs/patterns/architecture/strangler-fig/migration-guide.md",
    "docs/patterns/architecture/strangler-fig/platform-component-replacement.md",
    "docs/patterns/architecture/strangler-fig/validation-rollback.md",
    "docs/patterns/architecture/strangler-fig/monitoring.md",
    "docs/patterns/architecture/strangler-fig/implementation.md",
    "docs/patterns/architecture/strangler-fig/traffic-routing.md",
    "docs/patterns/architecture/strangler-fig/platform-component-examples.md",
    "docs/patterns/architecture/strangler-fig/edge-cases-comparison.md",
    "docs/patterns/architecture/strangler-fig/compatibility-layers.md",
    "docs/patterns/architecture/matrix-distribution/index.md",
    "docs/patterns/architecture/matrix-distribution/template-rendering.md",
    "docs/patterns/architecture/matrix-distribution/conditional-distribution.md",
    "docs/patterns/architecture/matrix-distribution/anti-patterns.md",
    "docs/patterns/architecture/environment-progression-operations.md",
    "docs/patterns/architecture/environment-progression.md",
    "docs/secure/cloud-native/gke-hardening/runtime-security/admission-controllers.md",
    "docs/secure/cloud-native/gke-hardening/runtime-security/index.md",
    "docs/secure/cloud-native/gke-hardening/runtime-security/pod-security-standards.md",
    "docs/secure/cloud-native/gke-hardening/runtime-security/runtime-monitoring.md",
    "docs/secure/cloud-native/gke-hardening/index.md",
    "docs/secure/cloud-native/gke-hardening/cluster-configuration/index.md",
    "docs/secure/cloud-native/gke-hardening/cluster-configuration/binary-authorization.md",
    "docs/secure/cloud-native/gke-hardening/cluster-configuration/private-cluster-setup.md",
    "docs/secure/cloud-native/gke-hardening/cluster-configuration/private-cluster.md",
    "docs/secure/cloud-native/gke-hardening/cluster-configuration/private-cluster-advanced.md",
    "docs/secure/cloud-native/gke-hardening/cluster-configuration/workload-identity.md",
    "docs/secure/cloud-native/gke-hardening/network-security/index.md",
    "docs/secure/cloud-native/gke-hardening/network-security/network-policies.md",
    "docs/secure/cloud-native/gke-hardening/network-security/vpc-native.md",
    "docs/secure/cloud-native/gke-hardening/network-security/cloud-armor.md",
    "docs/secure/cloud-native/gke-hardening/iam-configuration/audit-logging.md",
    "docs/secure/cloud-native/gke-hardening/iam-configuration/index.md",
    "docs/secure/cloud-native/gke-hardening/iam-configuration/least-privilege-roles.md",
    "docs/secure/cloud-native/gke-hardening/iam-configuration/workload-identity-federation.md",
    "docs/secure/cloud-native/workload-identity/cluster-configuration.md",
    "docs/secure/cloud-native/workload-identity/index.md",
    "docs/secure/cloud-native/workload-identity/migration-guide.md",
    "docs/secure/cloud-native/workload-identity/troubleshooting.md",
    "docs/secure/cloud-native/workload-identity/service-account-binding.md",
    "docs/secure/cloud-native/workload-identity/pod-configuration.md",
    "docs/secure/scorecard/scorecard-workflow-examples.md",
    "docs/secure/scorecard/index.md",
    "docs/secure/scorecard/ci-integration.md",
    "docs/secure/scorecard/score-progression/tier-1.md",
    "docs/secure/scorecard/score-progression/tier-3.md",
    "docs/secure/scorecard/score-progression/tier-1/part-1.md",
    "docs/secure/scorecard/score-progression/tier-1/part-2.md",
    "docs/secure/scorecard/score-progression/tier-2.md",
    "docs/secure/scorecard/score-progression/tier-3/part-1.md",
    "docs/secure/scorecard/score-progression/tier-3/part-2.md",
    "docs/secure/scorecard/score-progression/tier-2/part-1.md",
    "docs/secure/scorecard/score-progression/tier-2/part-2.md",
    "docs/secure/scorecard/false-positives.md",
    "docs/secure/scorecard/scorecard-compliance.md",
    "docs/secure/scorecard/false-positives/part-4.md",
    "docs/secure/scorecard/false-positives/part-1.md",
    "docs/secure/scorecard/false-positives/part-2.md",
    "docs/secure/scorecard/false-positives/part-3.md",
    "docs/secure/scorecard/score-progression.md",
    "docs/secure/scorecard/ci-integration/part-1.md",
    "docs/secure/scorecard/ci-integration/part-2.md",
    "docs/secure/scorecard/ci-integration/part-3.md",
    "docs/secure/scorecard/checks/supply-chain/part-4.md",
    "docs/secure/scorecard/checks/supply-chain/part-1.md",
    "docs/secure/scorecard/checks/supply-chain/part-2.md",
    "docs/secure/scorecard/checks/supply-chain/part-3.md",
    "docs/secure/scorecard/checks/supply-chain.md",
    "docs/secure/scorecard/checks/code-review/part-1.md",
    "docs/secure/scorecard/checks/code-review/part-2.md",
    "docs/secure/scorecard/checks/code-review/part-3.md",
    "docs/secure/scorecard/checks/branch-protection/part-2a.md",
    "docs/secure/scorecard/checks/branch-protection/part-1b.md",
    "docs/secure/scorecard/checks/branch-protection/part-1a.md",
    "docs/secure/scorecard/checks/branch-protection/part-3.md",
    "docs/secure/scorecard/checks/branch-protection/part-2b.md",
    "docs/secure/scorecard/checks/release-security.md",
    "docs/secure/scorecard/checks/release-security/packaging/go-modules.md",
    "docs/secure/scorecard/checks/release-security/packaging/pypi.md",
    "docs/secure/scorecard/checks/release-security/packaging/containers.md",
    "docs/secure/scorecard/checks/release-security/packaging/npm.md",
    "docs/secure/scorecard/checks/release-security/signed-releases-advanced.md",
    "docs/secure/scorecard/checks/release-security/license.md",
    "docs/secure/scorecard/checks/release-security/packaging.md",
    "docs/secure/scorecard/checks/release-security/signed-releases.md",
    "docs/secure/scorecard/checks/security-practices/security-policy.md",
    "docs/secure/scorecard/checks/security-practices/token-permissions.md",
    "docs/secure/scorecard/checks/security-practices/fuzzing.md",
    "docs/secure/scorecard/checks/security-practices/cii-best-practices.md",
    "docs/secure/scorecard/checks/security-practices/vulnerabilities-advanced.md",
    "docs/secure/scorecard/checks/security-practices/vulnerabilities.md",
    "docs/secure/scorecard/checks/security-practices/fuzzing-advanced.md",
    "docs/secure/scorecard/checks/branch-protection.md",
    "docs/secure/scorecard/checks/code-review.md",
    "docs/secure/scorecard/checks/security-practices.md",
    "docs/secure/scorecard/decision-framework.md",
    "docs/secure/scorecard/decision-framework/part-1.md",
    "docs/secure/scorecard/decision-framework/part-2.md",
    "docs/secure/scorecard/decision-framework/part-3.md",
    "docs/secure/index.md",
    "docs/secure/vulnerability-scanning/vulnerability-scanning.md",
    "docs/secure/github-actions-security/secrets/rotation/emergency-checklist.md",
    "docs/secure/github-actions-security/secrets/rotation/index.md",
    "docs/secure/github-actions-security/secrets/rotation/cloud-patterns.md",
    "docs/secure/github-actions-security/secrets/oidc/index.md",
    "docs/secure/github-actions-security/secrets/oidc/cloud-providers.md",
    "docs/secure/github-actions-security/secrets/secrets-management/index.md",
    "docs/secure/github-actions-security/secrets/secrets-management/best-practices.md",
    "docs/secure/github-actions-security/secrets/scanning/index.md",
    "docs/secure/github-actions-security/secrets/scanning/custom-patterns.md",
    "docs/secure/github-actions-security/secrets/scanning/alert-response.md",
    "docs/secure/github-actions-security/index.md",
    "docs/secure/github-actions-security/runners/index.md",
    "docs/secure/github-actions-security/runners/groups/index.md",
    "docs/secure/github-actions-security/runners/groups/repository-access.md",
    "docs/secure/github-actions-security/runners/groups/workflow-restrictions.md",
    "docs/secure/github-actions-security/runners/hardening/index.md",
    "docs/secure/github-actions-security/runners/hardening/credential-protection.md",
    "docs/secure/github-actions-security/runners/hardening/network-isolation.md",
    "docs/secure/github-actions-security/runners/ephemeral/index.md",
    "docs/secure/github-actions-security/runners/ephemeral/arc-patterns.md",
    "docs/secure/github-actions-security/runners/ephemeral/vm-patterns.md",
    "docs/secure/github-actions-security/action-pinning/dependabot.md",
    "docs/secure/github-actions-security/action-pinning/index.md",
    "docs/secure/github-actions-security/action-pinning/sha-pinning.md",
    "docs/secure/github-actions-security/action-pinning/automation.md",
    "docs/secure/github-actions-security/cheat-sheet/index.md",
    "docs/secure/github-actions-security/cheat-sheet/advanced-patterns.md",
    "docs/secure/github-actions-security/token-permissions/index.md",
    "docs/secure/github-actions-security/token-permissions/templates.md",
    "docs/secure/github-actions-security/token-permissions/job-scoping.md",
    "docs/secure/github-actions-security/third-party-actions/allowlisting.md",
    "docs/secure/github-actions-security/third-party-actions/index.md",
    "docs/secure/github-actions-security/third-party-actions/evaluation.md",
    "docs/secure/github-actions-security/third-party-actions/common-actions.md",
    "docs/secure/github-actions-security/examples/index.md",
    "docs/secure/github-actions-security/examples/ci-workflow/index.md",
    "docs/secure/github-actions-security/examples/ci-workflow/language-specific.md",
    "docs/secure/github-actions-security/examples/ci-workflow/advanced-checklist.md",
    "docs/secure/github-actions-security/examples/release-workflow/index.md",
    "docs/secure/github-actions-security/examples/release-workflow/package-release-checklist.md",
    "docs/secure/github-actions-security/examples/release-workflow/container-release.md",
    "docs/secure/github-actions-security/examples/release-workflow/multi-arch-builds.md",
    "docs/secure/github-actions-security/examples/security-scanning/index.md",
    "docs/secure/github-actions-security/examples/security-scanning/language-specific.md",
    "docs/secure/github-actions-security/examples/security-scanning/codeql-configuration.md",
    "docs/secure/github-actions-security/examples/security-scanning/advanced-patterns.md",
    "docs/secure/github-actions-security/examples/security-scanning/checklist.md",
    "docs/secure/github-actions-security/examples/deployment-workflow/index.md",
    "docs/secure/github-actions-security/examples/deployment-workflow/multi-environment.md",
    "docs/secure/github-actions-security/examples/deployment-workflow/security-checklist.md",
    "docs/secure/github-actions-security/examples/deployment-workflow/rollback.md",
    "docs/secure/github-actions-security/workflows/triggers/index.md",
    "docs/secure/github-actions-security/workflows/triggers/fork-patterns.md",
    "docs/secure/github-actions-security/workflows/reusable/secret-patterns.md",
    "docs/secure/github-actions-security/workflows/reusable/index.md",
    "docs/secure/github-actions-security/workflows/reusable/caller-validation-pinning.md",
    "docs/secure/github-actions-security/workflows/environments/index.md",
    "docs/secure/github-actions-security/workflows/environments/deployment-gates.md",
    "docs/secure/github-actions-security/workflows/environments/api-configuration.md",
    "docs/secure/culture/tactical-playbook/career-growth.md",
    "docs/secure/culture/tactical-playbook/scorecards-dashboards.md",
    "docs/secure/culture/tactical-playbook/automation-tools.md",
    "docs/secure/culture/tactical-playbook/index.md",
    "docs/secure/culture/tactical-playbook/recognition-rewards.md",
    "docs/secure/culture/tactical-playbook/notifications-badges.md",
    "docs/secure/culture/tactical-playbook/automated-reviews.md",
    "docs/secure/culture/tactical-playbook/champions-program.md",
    "docs/secure/culture/tactical-playbook/pre-commit-ide.md",
    "docs/secure/risk-management/engineer-framework/risk-assessment.md",
    "docs/secure/risk-management/engineer-framework/index.md",
    "docs/secure/risk-management/engineer-framework/cvss-interpretation.md",
    "docs/secure/risk-management/engineer-framework/real-world-scenarios.md",
    "docs/secure/risk-management/engineer-framework/blast-radius.md",
    "docs/secure/risk-management/engineer-framework/remediation-cost.md",
    "docs/secure/risk-management/engineer-framework/exploitability-analysis.md",
    "docs/secure/risk-management/engineer-framework/decision-trees.md",
    "docs/secure/sbom/sbom-generation.md",
    "docs/secure/go-security/index.md",
    "docs/secure/go-security/integration.md",
    "docs/secure/go-security/conclusion.md",
    "docs/secure/go-security/compliance.md",
    "docs/secure/go-security/tools.md",
    "docs/secure/github-apps/installation-scopes.md",
    "docs/secure/github-apps/index.md",
    "docs/secure/github-apps/authentication-flows.md",
    "docs/secure/github-apps/troubleshooting.md",
    "docs/secure/github-apps/authentication-decision-guide.md",
    "docs/secure/github-apps/permission-patterns.md",
    "docs/secure/github-apps/security-best-practices.md",
    "docs/secure/github-apps/maintenance.md",
    "docs/secure/github-apps/common-permissions.md",
    "docs/secure/github-apps/creating-the-app.md",
    "docs/secure/github-apps/storing-credentials/kubernetes.md",
    "docs/secure/github-apps/storing-credentials/index.md",
    "docs/secure/github-apps/storing-credentials/rotation-security.md",
    "docs/secure/github-apps/storing-credentials/external-ci.md",
    "docs/build/release-pipelines/index.md",
    "docs/build/release-pipelines/change-detection.md",
    "docs/build/release-pipelines/workflow-triggers.md",
    "docs/build/release-pipelines/release-please/extra-files.md",
    "docs/build/release-pipelines/release-please/index.md",
    "docs/build/release-pipelines/release-please/troubleshooting.md",
    "docs/build/release-pipelines/release-please/release-types.md",
    "docs/build/release-pipelines/release-please/workflow-integration.md",
    "docs/build/release-pipelines/protected-branches.md",
    "docs/build/coverage-patterns/coverage-patterns.md",
    "docs/build/documentation-as-skills/extraction-pipeline.md",
    "docs/build/documentation-as-skills/index.md",
    "docs/build/documentation-as-skills/ci-automation.md",
    "docs/build/documentation-as-skills/skill-anatomy.md",
    "docs/build/documentation-as-skills/marketplace-versioning.md",
    "docs/build/index.md",
    "docs/build/go-cli-architecture/packaging/index.md",
    "docs/build/go-cli-architecture/packaging/helm-charts.md",
    "docs/build/go-cli-architecture/packaging/container-builds.md",
    "docs/build/go-cli-architecture/packaging/pre-commit-hooks.md",
    "docs/build/go-cli-architecture/packaging/github-actions.md",
    "docs/build/go-cli-architecture/packaging/release-automation.md",
    "docs/build/go-cli-architecture/command-architecture/index.md",
    "docs/build/go-cli-architecture/command-architecture/subcommand-design.md",
    "docs/build/go-cli-architecture/command-architecture/orchestrator-pattern.md",
    "docs/build/go-cli-architecture/command-architecture/io-contracts.md",
    "docs/build/go-cli-architecture/testing/index.md",
    "docs/build/go-cli-architecture/testing/unit-testing.md",
    "docs/build/go-cli-architecture/testing/e2e-testing.md",
    "docs/build/go-cli-architecture/testing/integration-testing.md",
    "docs/build/go-cli-architecture/index.md",
    "docs/build/go-cli-architecture/framework-selection/index.md",
    "docs/build/go-cli-architecture/framework-selection/cli-frameworks.md",
    "docs/build/go-cli-architecture/framework-selection/viper-configuration.md",
    "docs/build/go-cli-architecture/kubernetes-integration/index.md",
    "docs/build/go-cli-architecture/kubernetes-integration/client-configuration.md",
    "docs/build/go-cli-architecture/kubernetes-integration/common-operations/index.md",
    "docs/build/go-cli-architecture/kubernetes-integration/common-operations/rollout-restart.md",
    "docs/build/go-cli-architecture/kubernetes-integration/common-operations/watch-resources.md",
    "docs/build/go-cli-architecture/kubernetes-integration/common-operations/list-resources.md",
    "docs/build/go-cli-architecture/kubernetes-integration/common-operations/configmap-operations.md",
    "docs/build/go-cli-architecture/kubernetes-integration/rbac-setup.md",
    "docs/build/versioned-docs/version-strategies.md",
    "docs/build/versioned-docs/mike-configuration.md",
    "docs/build/versioned-docs/index.md",
    "docs/build/versioned-docs/pipeline-integration.md",
    "docs/build/open-source-templates/index.md",
    "docs/build/open-source-templates/issue-templates.md",
    "docs/build/open-source-templates/contributing-template.md",
    "docs/build/open-source-templates/security-template.md",
    "docs/build/efficiency-patterns/refresh-strategies.md",
    "docs/build/efficiency-patterns/use-cases.md",
    "docs/build/efficiency-patterns/implementation.md",
    "docs/build/efficiency-patterns/configmap-cache.md",
]

invalid_links_found = check_links_in_markdown_files(all_md_files)

if invalid_links_found:
    print("Found dead internal links:")
    for link_info in invalid_links_found:
        print(f"- Source: {link_info['source_file']}, Link: '{link_info['original_link']}', Resolved: '{link_info['resolved_path']}', Reason: {link_info['reason']}")
else:
    print("No dead internal links found.")
