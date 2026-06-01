#!/usr/bin/env python3
"""Unit tests for bin/file_test_bugs.py.

Stdlib `unittest` only. No real LINEAR_API_KEY and no network: the HTTP layer
(LinearClient.execute) is mocked so we exercise the real resolve/dedup/create
logic against canned GraphQL responses. This is the proof the filer behaves
correctly before the secret exists.

Run:  python3 -m unittest discover -s bin -p 'test_*.py'
  or:  python3 bin/test_file_test_bugs.py
"""

from __future__ import annotations

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import file_test_bugs as f  # noqa: E402


FULL_SHA = "0123456789abcdef0123456789abcdef01234567"
SHORT_SHA = "0123456"
RUN_URL = "https://github.com/acme/dod-ios-app/actions/runs/42"


# --------------------------------------------------------------------------- #
# Marker build / parse
# --------------------------------------------------------------------------- #


class MarkerTests(unittest.TestCase):
    def test_build_marker_contains_full_sha(self):
        marker = f.build_marker(FULL_SHA)
        self.assertIn(FULL_SHA, marker)
        self.assertTrue(marker.startswith("<!--"))
        self.assertTrue(marker.endswith("-->"))

    def test_round_trip(self):
        self.assertEqual(f.parse_marker(f.build_marker(FULL_SHA)), FULL_SHA)

    def test_parse_marker_embedded_in_description(self):
        desc = (
            "Some text\n\n**Commit:** `x`\n\n"
            + f.build_marker(FULL_SHA)
            + "\ntrailing"
        )
        self.assertEqual(f.parse_marker(desc), FULL_SHA)

    def test_parse_marker_absent(self):
        self.assertIsNone(f.parse_marker("no marker here"))
        self.assertIsNone(f.parse_marker(""))
        self.assertIsNone(f.parse_marker(None))

    def test_parse_marker_tolerates_whitespace(self):
        self.assertEqual(
            f.parse_marker(f"<!--  dod-bugfiler:sha={FULL_SHA}  -->"),
            FULL_SHA,
        )

    def test_short_sha(self):
        self.assertEqual(f.short_sha(FULL_SHA), SHORT_SHA)
        self.assertEqual(len(f.short_sha(FULL_SHA)), 7)


# --------------------------------------------------------------------------- #
# Job -> layer -> priority mapping
# --------------------------------------------------------------------------- #


class LayerMappingTests(unittest.TestCase):
    def test_job_id_mapping(self):
        cases = {
            "lint": "L0",
            "format": "L0",
            "test-unit-packages": "L1",
            "test-unit-app": "L1",
            "build-app": "L2",
            "test-ui-smoke": "L3",
            "test-snapshots-designsystem": "L4",
            "test-e2e": "L5",
        }
        for job, layer in cases.items():
            with self.subTest(job=job):
                self.assertEqual(f.job_to_layer(job), layer)

    def test_specific_id_beats_generic_substring(self):
        # "test-unit-packages" contains "unit" (L1) and must not be misread as
        # a bare build/etc.; also ensure "build-app" -> L2 not something else.
        self.assertEqual(f.job_to_layer("test-unit-packages"), "L1")
        self.assertEqual(f.job_to_layer("build-app"), "L2")

    def test_display_name_with_explicit_layer_token(self):
        self.assertEqual(f.job_to_layer("L4 Snapshots DODDesignSystem"), "L4")
        self.assertEqual(f.job_to_layer("L1 Unit all packages"), "L1")
        self.assertEqual(f.job_to_layer("L5 E2E User Journeys"), "L5")

    def test_case_insensitive(self):
        self.assertEqual(f.job_to_layer("BUILD-APP"), "L2")
        self.assertEqual(f.job_to_layer("Lint"), "L0")

    def test_changes_infra_job_is_tooling(self):
        # The path-detection "changes" job failing is a CI-infra/tooling break.
        self.assertEqual(f.job_to_layer("changes"), "L0")
        self.assertEqual(f.layer_priority(f.job_to_layer("changes")),
                        f.PRIORITY_URGENT)

    def test_unknown_job_defaults_high(self):
        self.assertEqual(f.job_to_layer("totally-unknown-job"), f.DEFAULT_LAYER)
        self.assertEqual(f.layer_priority(f.job_to_layer("totally-unknown")),
                        f.PRIORITY_HIGH)

    def test_layer_priority_map(self):
        self.assertEqual(f.layer_priority("L0"), f.PRIORITY_URGENT)
        self.assertEqual(f.layer_priority("L2"), f.PRIORITY_URGENT)
        self.assertEqual(f.layer_priority("L1"), f.PRIORITY_HIGH)
        self.assertEqual(f.layer_priority("L3"), f.PRIORITY_HIGH)
        self.assertEqual(f.layer_priority("L4"), f.PRIORITY_MEDIUM)
        self.assertEqual(f.layer_priority("L5"), f.PRIORITY_LOW)

    def test_max_priority_picks_most_severe(self):
        # L4 (Medium=3) + L2 (Urgent=1) -> Urgent (1).
        self.assertEqual(
            f.max_priority_for_jobs(["test-snapshots-designsystem",
                                    "build-app"]),
            f.PRIORITY_URGENT,
        )

    def test_max_priority_l1_and_l4(self):
        # L1 (High=2) + L4 (Medium=3) -> High (2).
        self.assertEqual(
            f.max_priority_for_jobs(["test-unit-packages",
                                    "test-snapshots-designsystem"]),
            f.PRIORITY_HIGH,
        )

    def test_max_priority_only_low(self):
        self.assertEqual(f.max_priority_for_jobs(["test-e2e"]), f.PRIORITY_LOW)

    def test_max_priority_empty_defaults_high(self):
        self.assertEqual(f.max_priority_for_jobs([]), f.PRIORITY_HIGH)

    def test_parse_failed_jobs(self):
        self.assertEqual(
            f.parse_failed_jobs(" build-app , test-ui-smoke ,, "),
            ["build-app", "test-ui-smoke"],
        )
        self.assertEqual(f.parse_failed_jobs(""), [])


# --------------------------------------------------------------------------- #
# Title / description / comment payload construction
# --------------------------------------------------------------------------- #


class PayloadTests(unittest.TestCase):
    def test_title(self):
        self.assertEqual(
            f.build_issue_title(FULL_SHA),
            f"Test suite red on main @ {SHORT_SHA}",
        )

    def test_description_contains_required_fields(self):
        desc = f.build_issue_description(
            FULL_SHA, RUN_URL, ["build-app", "test-ui-smoke"])
        self.assertIn(FULL_SHA, desc)            # full commit SHA
        self.assertIn(RUN_URL, desc)             # link to the GitHub run
        self.assertIn("build-app", desc)         # each failed job listed
        self.assertIn("test-ui-smoke", desc)
        self.assertIn("L2", desc)                # layers annotated
        self.assertIn("L3", desc)
        self.assertIn(f.build_marker(FULL_SHA), desc)  # hidden dedup marker

    def test_description_with_details(self):
        desc = f.build_issue_description(
            FULL_SHA, RUN_URL, ["build-app"], details="boom\nstack frame")
        self.assertIn("boom", desc)
        self.assertIn("stack frame", desc)
        self.assertIn("```", desc)

    def test_description_no_jobs(self):
        desc = f.build_issue_description(FULL_SHA, RUN_URL, [])
        self.assertIn("(none reported)", desc)
        self.assertIn(f.build_marker(FULL_SHA), desc)

    def test_rerun_comment(self):
        self.assertEqual(
            f.build_rerun_comment(RUN_URL),
            f"Still red on re-run: {RUN_URL}",
        )


# --------------------------------------------------------------------------- #
# Dedup decision (pure)
# --------------------------------------------------------------------------- #


class DedupDecisionTests(unittest.TestCase):
    def test_find_issue_for_sha_found(self):
        issues = [
            {"id": "i1", "description": "unrelated"},
            {"id": "i2", "description": "x\n" + f.build_marker(FULL_SHA)},
        ]
        found = f.find_issue_for_sha(issues, FULL_SHA)
        self.assertIsNotNone(found)
        self.assertEqual(found["id"], "i2")

    def test_find_issue_for_sha_not_found(self):
        other = "ffffffffffffffffffffffffffffffffffffffff"
        issues = [
            {"id": "i1", "description": "unrelated"},
            {"id": "i2", "description": f.build_marker(other)},
        ]
        self.assertIsNone(f.find_issue_for_sha(issues, FULL_SHA))

    def test_find_issue_for_sha_empty(self):
        self.assertIsNone(f.find_issue_for_sha([], FULL_SHA))


# --------------------------------------------------------------------------- #
# Workflow-state selection (pure)
# --------------------------------------------------------------------------- #


class StateSelectionTests(unittest.TestCase):
    def test_prefers_unstarted_todo_by_name(self):
        states = [
            {"id": "s-backlog", "name": "Backlog", "type": "backlog",
            "position": 0},
            {"id": "s-todo", "name": "Todo", "type": "unstarted",
            "position": 1},
            {"id": "s-prog", "name": "In Progress", "type": "started",
            "position": 2},
        ]
        self.assertEqual(f.pick_todo_state_id(states), "s-todo")

    def test_falls_back_to_first_unstarted(self):
        states = [
            {"id": "s-b", "name": "Backlog", "type": "backlog", "position": 0},
            {"id": "s-u2", "name": "Selected", "type": "unstarted",
            "position": 3},
            {"id": "s-u1", "name": "Ready", "type": "unstarted",
            "position": 1},
        ]
        # lowest position among unstarted wins
        self.assertEqual(f.pick_todo_state_id(states), "s-u1")

    def test_raises_when_no_unstarted_or_todo(self):
        states = [
            {"id": "s-b", "name": "Backlog", "type": "backlog", "position": 0},
            {"id": "s-done", "name": "Done", "type": "completed",
            "position": 9},
        ]
        with self.assertRaises(f.LinearError):
            f.pick_todo_state_id(states)


# --------------------------------------------------------------------------- #
# End-to-end orchestration with the HTTP layer mocked
# --------------------------------------------------------------------------- #


def _canned_execute(self, query, variables=None, op_name="operation"):
    """A fake LinearClient.execute returning shape-compatible GraphQL data.

    Patched onto LinearClient.execute, so it receives `self` first. Configured
    per-test via the module-level _STATE dict so each test controls whether the
    dedup search finds an existing issue, and can assert which mutations fired.
    """
    variables = variables or {}
    _STATE["calls"].append((op_name, variables))
    if op_name == "TeamLabels":
        return {"team": {"id": f.TEAM_ID, "name": f.TEAM_NAME, "labels": {
            "nodes": [
                {"id": "lbl-bug", "name": "bug"},
                {"id": "lbl-tf", "name": "test-failure"},
            ]}}}
    if op_name == "TeamStates":
        return {"team": {"states": {"nodes": [
            {"id": "st-todo", "name": "Todo", "type": "unstarted",
            "position": 1},
        ]}}}
    if op_name == "OpenTestFailureIssues":
        return {"issues": {"nodes": _STATE["open_issues"]}}
    if op_name == "CreateIssue":
        _STATE["created"].append(variables)
        return {"issueCreate": {"success": True, "issue": {
            "id": "new-id", "identifier": "DOD-999",
            "url": "https://linear.app/x/issue/DOD-999"}}}
    if op_name == "CreateComment":
        _STATE["commented"].append(variables)
        return {"commentCreate": {"success": True, "comment": {"id": "c1"}}}
    if op_name == "CreateLabel":
        return {"issueLabelCreate": {"success": True, "issueLabel": {
            "id": "lbl-new", "name": variables.get("name")}}}
    raise AssertionError(f"unexpected op {op_name}")


_STATE: dict = {}


class OrchestrationTests(unittest.TestCase):
    def setUp(self):
        _STATE.clear()
        _STATE.update(calls=[], created=[], commented=[], open_issues=[])
        self.args = f.parse_args([
            "--sha", FULL_SHA,
            "--run-url", RUN_URL,
            "--failed-jobs", "build-app,test-ui-smoke",
        ])

    def test_creates_issue_when_none_matches(self):
        _STATE["open_issues"] = [
            {"id": "old", "identifier": "DOD-1", "url": "u",
            "title": "t", "description": "stale, no marker"},
        ]
        with mock.patch.object(f.LinearClient, "execute", _canned_execute):
            rc = f.run(self.args, api_key="dummy-key")
        self.assertEqual(rc, 0)
        self.assertEqual(len(_STATE["created"]), 1, "should create one issue")
        self.assertEqual(len(_STATE["commented"]), 0, "must not comment")
        # priority = max(L2 urgent, L3 high) = urgent(1)
        created_input = _STATE["created"][0]["input"]
        self.assertEqual(created_input["priority"], f.PRIORITY_URGENT)
        self.assertEqual(created_input["teamId"], f.TEAM_ID)
        self.assertEqual(created_input["stateId"], "st-todo")
        self.assertCountEqual(created_input["labelIds"],
                            ["lbl-bug", "lbl-tf"])
        self.assertIn(FULL_SHA, created_input["description"])

    def test_comments_when_existing_issue_matches_sha(self):
        _STATE["open_issues"] = [
            {"id": "match-id", "identifier": "DOD-7", "url": "u7",
            "title": "Test suite red on main @ 0123456",
            "description": "body\n" + f.build_marker(FULL_SHA)},
        ]
        with mock.patch.object(f.LinearClient, "execute", _canned_execute):
            rc = f.run(self.args, api_key="dummy-key")
        self.assertEqual(rc, 0)
        self.assertEqual(len(_STATE["created"]), 0,
                        "must NOT create a duplicate")
        self.assertEqual(len(_STATE["commented"]), 1, "should add one comment")
        self.assertEqual(_STATE["commented"][0]["issueId"], "match-id")
        self.assertIn(RUN_URL, _STATE["commented"][0]["body"])

    def test_create_if_missing_label_path(self):
        # No labels exist yet -> resolve_labels must create both.
        def _execute_no_labels(self, query, variables=None,
                            op_name="operation"):
            if op_name == "TeamLabels":
                _STATE["calls"].append((op_name, variables or {}))
                return {"team": {"id": f.TEAM_ID, "name": f.TEAM_NAME,
                                "labels": {"nodes": []}}}
            return _canned_execute(self, query, variables, op_name)

        created_labels = []
        real_create = f.LinearClient.create_label

        def _spy_create(self, name, color):
            created_labels.append(name)
            return real_create(self, name, color)

        with mock.patch.object(f.LinearClient, "execute", _execute_no_labels), \
            mock.patch.object(f.LinearClient, "create_label", _spy_create):
            rc = f.run(self.args, api_key="dummy-key")
        self.assertEqual(rc, 0)
        self.assertCountEqual(created_labels, ["bug", "test-failure"])


# --------------------------------------------------------------------------- #
# CLI / arg + env handling
# --------------------------------------------------------------------------- #


class CliTests(unittest.TestCase):
    def test_main_requires_key_without_dry_run(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            rc = f.main(["--sha", FULL_SHA, "--run-url", RUN_URL,
                        "--failed-jobs", "build-app"])
        self.assertEqual(rc, 2)

    def test_dry_run_makes_no_network_calls(self):
        # If execute were hit with real transport it would try urlopen; instead
        # dry-run must short-circuit. We assert urlopen is never called.
        with mock.patch("urllib.request.urlopen") as urlopen, \
            mock.patch.dict(os.environ, {}, clear=True):
            rc = f.main(["--sha", FULL_SHA, "--run-url", RUN_URL,
                        "--failed-jobs", "build-app,test-snapshots-designsystem",
                        "--dry-run"])
        self.assertEqual(rc, 0)
        urlopen.assert_not_called()

    def test_dry_run_logs_create_operation(self):
        client = f.LinearClient("k", dry_run=True)
        client.resolve_labels()
        client.resolve_todo_state_id()
        client.find_existing_issue(FULL_SHA)
        client.create_issue(title="t", description="d",
                            label_ids=["a", "b"], state_id="s", priority=1)
        names = [op["name"] for op in client.dry_run_log]
        self.assertEqual(
            names,
            ["TeamLabels", "TeamStates", "OpenTestFailureIssues",
            "CreateIssue"],
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
