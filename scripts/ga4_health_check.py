#!/usr/bin/env python3
"""GA4 health check — confirm the iOS app's analytics are landing.

The website's traffic makes GA4 Realtime hard to read, so this queries the GA4
Realtime Reporting API directly for the app-exclusive ``recipe_open`` event and
prints a definitive count for the last ~30 minutes. Open a recipe in the app,
run this, and see your event — no fighting the noisy UI.

One-time setup:
  1. Google Cloud console → create a service account → download its JSON key.
  2. GA4 Admin → Property → Access Management → add the service-account email as
     a **Viewer** on the Dutch Oven Daddy property.
  3. pip install google-analytics-data
  4. Export two env vars:
       export GA4_PROPERTY_ID=123456789     # the NUMERIC GA4 property id (not the G- id)
       export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json

Run:  ./scripts/ga4_health_check.py
Exit 0 (+ the count and a breakdown) when app events are seen in the last ~30
min; exit 1 when none are — meaning either no one has opened a recipe recently
in a build that has the GA4 creds, or the api_secret is wrong.

Why ``recipe_open`` is the signal: the app maps in-app recipe/article opens to a
custom ``recipe_open`` event (DUT-680). The website's gtag never fires that name,
so any ``recipe_open`` in GA4 is unambiguously the app. The DUT-681 build tags
these with ``app_platform=ios`` too — see APP_PLATFORM_ONLY below to narrow
further once that param is registered as a custom dimension in GA4.
"""

import os
import sys

# Set to True to additionally require app_platform == "ios" (needs the param
# registered as a Realtime custom dimension in GA4 Admin first).
APP_PLATFORM_ONLY = False

try:
    from google.analytics.data_v1beta import BetaAnalyticsDataClient
    from google.analytics.data_v1beta.types import (
        Dimension,
        Filter,
        FilterExpression,
        FilterExpressionList,
        Metric,
        RunRealtimeReportRequest,
    )
except ImportError:
    sys.exit("Missing dependency — run: pip install google-analytics-data")


def _event_name_filter() -> FilterExpression:
    return FilterExpression(
        filter=Filter(
            field_name="eventName",
            string_filter=Filter.StringFilter(value="recipe_open"),
        )
    )


def _app_platform_filter() -> FilterExpression:
    return FilterExpression(
        filter=Filter(
            field_name="customEvent:app_platform",
            string_filter=Filter.StringFilter(value="ios"),
        )
    )


def main() -> int:
    prop = os.environ.get("GA4_PROPERTY_ID")
    if not prop:
        sys.exit(
            "Set GA4_PROPERTY_ID (numeric GA4 property id) and "
            "GOOGLE_APPLICATION_CREDENTIALS (service-account JSON path). See the header."
        )

    expr = _event_name_filter()
    if APP_PLATFORM_ONLY:
        expr = FilterExpression(
            and_group=FilterExpressionList(expressions=[expr, _app_platform_filter()])
        )

    client = BetaAnalyticsDataClient()
    request = RunRealtimeReportRequest(
        property=f"properties/{prop}",
        dimensions=[Dimension(name="eventName"), Dimension(name="unifiedScreenName")],
        metrics=[Metric(name="eventCount")],
        dimension_filter=expr,
    )
    response = client.run_realtime_report(request)

    total = sum(int(row.metric_values[0].value) for row in response.rows)
    if total > 0:
        print(f"✅ app recipe_open events (last ~30 min): {total}")
        for row in response.rows[:10]:
            label = " / ".join(dim.value for dim in row.dimension_values)
            print(f"    {label} → {row.metric_values[0].value}")
        return 0

    print("❌ NO app recipe_open events in the last ~30 min.")
    print("    Open a recipe in a build that has the GA4 creds, wait ~1 min, re-run.")
    print("    If still zero, the api_secret is likely wrong (regenerate it in the web stream).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
