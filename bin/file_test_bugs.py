#!/usr/bin/env python3
"""File a single rollup bug issue in Linear when CI goes red on main.

This is the autonomous, CI-side counterpart to filing a bug by hand. It is
invoked by the `report-failures` job in .github/workflows/ci.yml when one or
more required jobs fail on a push to `main`. It talks to the Linear GraphQL
API directly (https://api.linear.app/graphql) using only the Python standard
library so the macOS runner needs no pip/SwiftPM dependency.

Design (decided by the repo owner, do not deviate):
  - One ROLLUP issue per red run: a single Linear issue that summarizes which
    jobs/layers failed, the commit, and a link to the GitHub run.
  - Idempotent by commit SHA: re-running CI on the same commit updates the
    existing issue (adds a comment) instead of filing a duplicate. A new red
    commit files a new rollup issue. Dedup is implemented by embedding a hidden
    marker `<!-- dod-bugfiler:sha=<full-sha> -->` in the issue description and
    searching the team's open `test-failure`-labeled issues for it.
  - Priority = the max severity among the failed layers.

Auth: Linear personal API keys are sent as the RAW key in the `Authorization`
header with NO `Bearer` prefix (verified against developers.linear.app). The
key is read from the LINEAR_API_KEY environment variable and is never logged.

Usage (real run, in CI):
    file_test_bugs.py \
        --sha "$GITHUB_SHA" \
        --run-url "https://github.com/<org>/<repo>/actions/runs/<id>" \
        --failed-jobs "build-app,test-ui-smoke"

Dry run (no network, prints the GraphQL operations it WOULD send):
    file_test_bugs.py --sha ... --run-url ... --failed-jobs ... --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #

LINEAR_API_URL = "https://api.linear.app/graphql"

# The "Dutch Oven Daddy" Linear team. Hardcoded id provided by the repo owner;
# not a secret (a team id is not a credential).
TEAM_ID = "6ca2f53d-4a1b-4f1d-b7a5-b26564d09705"
TEAM_NAME = "Dutch Oven Daddy"

BUG_LABEL = "bug"
TEST_FAILURE_LABEL = "test-failure"

# Marker template embedded (hidden) in the issue description so re-runs on the
# same commit find and update the existing rollup issue instead of duplicating.
MARKER_TEMPLATE = "<!-- dod-bugfiler:sha={sha} -->"
MARKER_RE = re.compile(r"<!--\s*dod-bugfiler:sha=([0-9a-fA-F]+)\s*-->")

# Linear priority scale: 0 No priority, 1 Urgent, 2 High, 3 Medium, 4 Low.
PRIORITY_URGENT = 1
PRIORITY_HIGH = 2
PRIORITY_MEDIUM = 3
PRIORITY_LOW = 4

PRIORITY_NAMES = {
    0: "No priority",
    PRIORITY_URGENT: "Urgent",
    PRIORITY_HIGH: "High",
    PRIORITY_MEDIUM: "Medium",
    PRIORITY_LOW: "Low",
}

# Severity per CI layer, per the owner's map:
#   L2 build / L0 tooling -> Urgent (1)
#   L1 unit / L3 UI smoke -> High (2)
#   L4 snapshot           -> Medium (3)
#   L5 live-API           -> Low (4)
LAYER_PRIORITY = {
    "L0": PRIORITY_URGENT,
    "L1": PRIORITY_HIGH,
    "L2": PRIORITY_URGENT,
    "L3": PRIORITY_HIGH,
    "L4": PRIORITY_MEDIUM,
    "L5": PRIORITY_LOW,
}

# Map a GitHub job (the `needs` key / job id from ci.yml, or a recognizable
# slice of its display name) to a CI layer. Keys are matched case-insensitively
# as substrings, longest first, against the incoming job token. An unmapped job
# defaults to High (see job_to_layer).
JOB_LAYER_RULES = {
    # L0 tooling / CI-infra gates.
    "lint": "L0",
    "format": "L0",
    "changes": "L0",
    # L1 unit tests (package + host-app slice).
    "test-unit-packages": "L1",
    "test-unit-app": "L1",
    "test-unit": "L1",
    "unit": "L1",
    # L2 build.
    "build-app": "L2",
    "build": "L2",
    # L3 UI smoke.
    "test-ui-smoke": "L3",
    "ui-smoke": "L3",
    "ui smoke": "L3",
    # L4 snapshots.
    "test-snapshots-designsystem": "L4",
    "snapshot": "L4",
    # L5 end-to-end / live-API.
    "test-e2e": "L5",
    "e2e": "L5",
    "live-api": "L5",
    "live api": "L5",
}

DEFAULT_LAYER = "L1"  # fall back to High for an unmappable job.


# --------------------------------------------------------------------------- #
# Pure logic (no network) -- unit-tested directly
# --------------------------------------------------------------------------- #


def build_marker(sha: str) -> str:
    """Return the hidden dedup marker for a full commit SHA."""
    return MARKER_TEMPLATE.format(sha=sha)


def parse_marker(text: str) -> str | None:
    """Extract the SHA from a dedup marker in *text*, or None if absent."""
    if not text:
        return None
    match = MARKER_RE.search(text)
    return match.group(1) if match else None


def short_sha(sha: str) -> str:
    """Return the conventional 7-char short SHA."""
    return sha[:7]


def parse_failed_jobs(raw: str) -> list[str]:
    """Split a comma-separated --failed-jobs value into clean job tokens."""
    if not raw:
        return []
    return [job.strip() for job in raw.split(",") if job.strip()]


def job_to_layer(job: str) -> str:
    """Map a GitHub job token to a CI layer (L0..L5).

    Matching is case-insensitive. An explicit "L<n>" token anywhere in the job
    name wins first (e.g. the display name "L4 Snapshots DODDesignSystem").
    Otherwise the JOB_LAYER_RULES substrings are tried longest-first so the
    more specific id (test-unit-packages) beats a generic one (unit). Unknown
    jobs fall back to DEFAULT_LAYER (High).
    """
    token = job.strip().lower()
    explicit = re.search(r"\bl([0-5])\b", token)
    if explicit:
        return "L" + explicit.group(1)
    for needle in sorted(JOB_LAYER_RULES, key=len, reverse=True):
        if needle in token:
            return JOB_LAYER_RULES[needle]
    return DEFAULT_LAYER


def layer_priority(layer: str) -> int:
    """Severity (Linear priority int) for a CI layer; default High."""
    return LAYER_PRIORITY.get(layer, PRIORITY_HIGH)


def max_priority_for_jobs(jobs: list[str]) -> int:
    """Highest severity (lowest priority number, 1=Urgent) across *jobs*.

    Empty -> High, a safe non-zero default so a misconfigured caller still
    files an actionable issue rather than a "No priority" one.
    """
    if not jobs:
        return PRIORITY_HIGH
    # Urgent(1) is the most severe; min() picks it.
    return min(layer_priority(job_to_layer(job)) for job in jobs)


def jobs_with_layers(jobs: list[str]) -> list[tuple[str, str]]:
    """Pair each job with its resolved layer, preserving input order."""
    return [(job, job_to_layer(job)) for job in jobs]


def build_issue_title(sha: str) -> str:
    """Rollup issue title."""
    return f"Test suite red on main @ {short_sha(sha)}"


def build_issue_description(sha: str, run_url: str, jobs: list[str],
                            details: str | None = None) -> str:
    """Compose the rollup issue description (Markdown) incl. hidden marker."""
    lines = [
        "The CI test suite went red on `main`.",
        "",
        "**Failed jobs / layers:**",
    ]
    if jobs:
        for job, layer in jobs_with_layers(jobs):
            sev = PRIORITY_NAMES[layer_priority(layer)]
            lines.append(f"- `{job}` ({layer} -> {sev})")
    else:
        lines.append("- (none reported)")
    lines += [
        "",
        f"**Commit:** `{sha}`",
        f"**GitHub run:** {run_url}",
    ]
    if details:
        lines += [
            "",
            "**Details:**",
            "",
            "```",
            details.rstrip("\n"),
            "```",
        ]
    lines += [
        "",
        "---",
        "Filed automatically by `bin/file_test_bugs.py`. Re-running CI on this "
        "same commit will add a comment here rather than open a duplicate.",
        "",
        build_marker(sha),
    ]
    return "\n".join(lines)


def build_rerun_comment(run_url: str) -> str:
    """Comment body added when the same commit is still red on a re-run."""
    return f"Still red on re-run: {run_url}"


def find_issue_for_sha(issues: list[dict], sha: str) -> dict | None:
    """Return the first issue whose description marker matches *sha*.

    *issues* is the list of node dicts from a Linear issues query; each needs at
    least `description`. Used for the dedup decision and unit-tested directly.
    """
    for issue in issues:
        if parse_marker(issue.get("description") or "") == sha:
            return issue
    return None


# --------------------------------------------------------------------------- #
# GraphQL documents
# --------------------------------------------------------------------------- #

LABELS_QUERY = """
query TeamLabels($teamId: String!) {
  team(id: $teamId) {
    id
    name
    labels(first: 250) {
      nodes { id name }
    }
  }
}
""".strip()

WORKFLOW_STATES_QUERY = """
query TeamStates($teamId: String!) {
  team(id: $teamId) {
    states(first: 100) {
      nodes { id name type position }
    }
  }
}
""".strip()

# Open issues for the team carrying the test-failure label, newest first. We
# scan their descriptions for the dedup marker. `first: 50` is ample: only a
# handful of rollup issues are ever open at once.
OPEN_TEST_FAILURE_ISSUES_QUERY = """
query OpenTestFailureIssues($teamId: ID!, $labelName: String!) {
  issues(
    first: 50
    orderBy: createdAt
    filter: {
      team: { id: { eq: $teamId } }
      labels: { name: { eq: $labelName } }
      state: { type: { nin: ["completed", "canceled"] } }
    }
  ) {
    nodes { id identifier url title description }
  }
}
""".strip()

CREATE_LABEL_MUTATION = """
mutation CreateLabel($teamId: String!, $name: String!, $color: String!) {
  issueLabelCreate(input: { teamId: $teamId, name: $name, color: $color }) {
    success
    issueLabel { id name }
  }
}
""".strip()

CREATE_ISSUE_MUTATION = """
mutation CreateIssue($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue { id identifier url }
  }
}
""".strip()

CREATE_COMMENT_MUTATION = """
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    success
    comment { id }
  }
}
""".strip()


# --------------------------------------------------------------------------- #
# Linear client (network)
# --------------------------------------------------------------------------- #


class LinearError(RuntimeError):
    """A Linear API call failed (HTTP error or GraphQL `errors`)."""


class LinearClient:
    """Minimal Linear GraphQL client over urllib.

    In dry-run mode no request is sent: every operation is recorded to
    `self.dry_run_log` and a canned, shape-compatible response is returned so
    the rest of the flow can run end to end with zero network access.
    """

    def __init__(self, api_key: str, dry_run: bool = False, timeout: int = 30):
        self.api_key = api_key
        self.dry_run = dry_run
        self.timeout = timeout
        self.dry_run_log: list[dict] = []

    # -- transport -------------------------------------------------------- #

    def execute(self, query: str, variables: dict | None = None,
                op_name: str = "operation") -> dict:
        """Run a GraphQL document. Returns the `data` object.

        In dry-run mode, logs the op (with variables) and returns {} so callers
        must route through the dry-run-aware helpers below for canned data.
        """
        variables = variables or {}
        if self.dry_run:
            self.dry_run_log.append({
                "name": op_name,
                "query": query,
                "variables": variables,
            })
            return {}

        payload = json.dumps({"query": query, "variables": variables}).encode()
        request = urllib.request.Request(LINEAR_API_URL, data=payload)
        request.add_header("Content-Type", "application/json")
        # Linear personal API key: RAW key, no "Bearer" prefix.
        request.add_header("Authorization", self.api_key)
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as resp:
                body = json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:  # pragma: no cover - network
            detail = exc.read().decode(errors="replace")
            raise LinearError(
                f"{op_name}: HTTP {exc.code} {exc.reason}: {detail}"
            ) from exc
        except urllib.error.URLError as exc:  # pragma: no cover - network
            raise LinearError(f"{op_name}: network error: {exc.reason}") from exc

        if body.get("errors"):
            raise LinearError(f"{op_name}: GraphQL errors: {body['errors']}")
        return body.get("data") or {}

    # -- resolve helpers -------------------------------------------------- #

    def resolve_labels(self) -> dict:
        """Return {name: id} for the team labels we need.

        Creates the `bug` and `test-failure` labels if missing (the owner says
        test-failure already exists; create-if-missing is a safety fallback).
        """
        if self.dry_run:
            self.execute(LABELS_QUERY, {"teamId": TEAM_ID}, "TeamLabels")
            return {BUG_LABEL: "<bug-label-id>",
                    TEST_FAILURE_LABEL: "<test-failure-label-id>"}

        data = self.execute(LABELS_QUERY, {"teamId": TEAM_ID}, "TeamLabels")
        team = data.get("team") or {}
        nodes = ((team.get("labels") or {}).get("nodes")) or []
        by_name = {n["name"]: n["id"] for n in nodes}
        resolved: dict[str, str] = {}
        for name, color in ((BUG_LABEL, "#eb5757"),
                            (TEST_FAILURE_LABEL, "#f2994a")):
            if name in by_name:
                resolved[name] = by_name[name]
            else:
                resolved[name] = self.create_label(name, color)
        return resolved

    def create_label(self, name: str, color: str) -> str:
        data = self.execute(
            CREATE_LABEL_MUTATION,
            {"teamId": TEAM_ID, "name": name, "color": color},
            "CreateLabel",
        )
        result = data.get("issueLabelCreate") or {}
        if not result.get("success"):
            raise LinearError(f"failed to create label {name!r}")
        return result["issueLabel"]["id"]

    def resolve_todo_state_id(self) -> str:
        """Return the team's unstarted 'Todo' workflow-state id.

        Prefers a state of type `unstarted` named "Todo"; else the first
        `unstarted` state (lowest position); else any "Todo"-named state.
        """
        if self.dry_run:
            self.execute(WORKFLOW_STATES_QUERY, {"teamId": TEAM_ID},
                        "TeamStates")
            return "<todo-state-id>"

        data = self.execute(WORKFLOW_STATES_QUERY, {"teamId": TEAM_ID},
                            "TeamStates")
        team = data.get("team") or {}
        nodes = ((team.get("states") or {}).get("nodes")) or []
        return pick_todo_state_id(nodes)

    def find_existing_issue(self, sha: str) -> dict | None:
        """Find an open test-failure issue whose marker matches *sha*."""
        if self.dry_run:
            self.execute(
                OPEN_TEST_FAILURE_ISSUES_QUERY,
                {"teamId": TEAM_ID, "labelName": TEST_FAILURE_LABEL},
                "OpenTestFailureIssues",
            )
            return None  # dry-run always takes the "create" path for preview

        data = self.execute(
            OPEN_TEST_FAILURE_ISSUES_QUERY,
            {"teamId": TEAM_ID, "labelName": TEST_FAILURE_LABEL},
            "OpenTestFailureIssues",
        )
        nodes = ((data.get("issues") or {}).get("nodes")) or []
        return find_issue_for_sha(nodes, sha)

    # -- write helpers ---------------------------------------------------- #

    def create_issue(self, *, title: str, description: str, label_ids: list[str],
                    state_id: str, priority: int) -> dict:
        variables = {
            "input": {
                "teamId": TEAM_ID,
                "title": title,
                "description": description,
                "labelIds": label_ids,
                "stateId": state_id,
                "priority": priority,
            }
        }
        if self.dry_run:
            self.execute(CREATE_ISSUE_MUTATION, variables, "CreateIssue")
            return {"identifier": "<new-issue>", "url": "<new-issue-url>"}
        data = self.execute(CREATE_ISSUE_MUTATION, variables, "CreateIssue")
        result = data.get("issueCreate") or {}
        if not result.get("success"):
            raise LinearError("issueCreate did not report success")
        return result["issue"]

    def add_comment(self, issue_id: str, body: str) -> None:
        variables = {"issueId": issue_id, "body": body}
        if self.dry_run:
            self.execute(CREATE_COMMENT_MUTATION, variables, "CreateComment")
            return
        data = self.execute(CREATE_COMMENT_MUTATION, variables, "CreateComment")
        result = data.get("commentCreate") or {}
        if not result.get("success"):
            raise LinearError("commentCreate did not report success")


def pick_todo_state_id(states: list[dict]) -> str:
    """Choose the unstarted 'Todo' state id from a team's workflow states."""
    if not states:
        raise LinearError("team has no workflow states")
    unstarted = [s for s in states if s.get("type") == "unstarted"]
    for state in unstarted:
        if (state.get("name") or "").strip().lower() == "todo":
            return state["id"]
    if unstarted:
        return sorted(unstarted, key=lambda s: s.get("position", 0))[0]["id"]
    for state in states:
        if (state.get("name") or "").strip().lower() == "todo":
            return state["id"]
    raise LinearError("no unstarted/Todo workflow state found")


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #


def run(args: argparse.Namespace, api_key: str) -> int:
    jobs = parse_failed_jobs(args.failed_jobs)
    details = None
    if args.details_file:
        try:
            with open(args.details_file, "r", encoding="utf-8") as handle:
                details = handle.read()
        except OSError as exc:
            print(f"warning: could not read --details-file: {exc}",
                file=sys.stderr)

    title = build_issue_title(args.sha)
    description = build_issue_description(args.sha, args.run_url, jobs, details)
    priority = max_priority_for_jobs(jobs)

    client = LinearClient(api_key, dry_run=args.dry_run)

    if args.dry_run:
        print("=== DRY RUN: no network calls will be made ===")
        print(f"Team: {TEAM_NAME} ({TEAM_ID})")
        print(f"Failed jobs -> layers: "
            f"{', '.join(f'{j}={l}' for j, l in jobs_with_layers(jobs))}")
        print(f"Computed priority: {priority} ({PRIORITY_NAMES[priority]})")
        print(f"Title: {title}")
        print("Description:")
        print("-" * 60)
        print(description)
        print("-" * 60)
        print()

    labels = client.resolve_labels()
    state_id = client.resolve_todo_state_id()
    existing = client.find_existing_issue(args.sha)

    if existing is not None:
        client.add_comment(existing["id"], build_rerun_comment(args.run_url))
        print(f"Updated existing rollup issue {existing.get('identifier')} "
            f"({existing.get('url')}) with a re-run comment.")
    else:
        label_ids = [labels[BUG_LABEL], labels[TEST_FAILURE_LABEL]]
        issue = client.create_issue(
            title=title,
            description=description,
            label_ids=label_ids,
            state_id=state_id,
            priority=priority,
        )
        print(f"Created rollup issue {issue.get('identifier')} "
            f"({issue.get('url')}).")

    if args.dry_run:
        print()
        print("=== GraphQL operations that WOULD be sent (in order) ===")
        for index, op in enumerate(client.dry_run_log, start=1):
            print(f"\n[{index}] {op['name']}")
            print("query:")
            print(op["query"])
            print("variables:")
            print(json.dumps(op["variables"], indent=2))
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="File/update a rollup Linear bug when CI is red on main.")
    parser.add_argument("--sha", required=True,
                        help="Full commit SHA of the red run.")
    parser.add_argument("--run-url", required=True,
                        help="URL of the GitHub Actions run.")
    parser.add_argument("--failed-jobs", default="",
                        help="Comma-separated list of failed job ids/names.")
    parser.add_argument("--details-file", default=None,
                        help="Optional path to a file with extra failure "
                            "detail to embed in the issue description.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the GraphQL operations without sending "
                            "any network request.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    api_key = os.environ.get("LINEAR_API_KEY", "")
    if not args.dry_run and not api_key:
        print("error: LINEAR_API_KEY is not set (and --dry-run not given).",
            file=sys.stderr)
        return 2
    try:
        return run(args, api_key)
    except LinearError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
