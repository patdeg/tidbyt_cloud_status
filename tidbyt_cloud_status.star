# Copyright 2024
# Cloud Status Monitor for Tidbyt
# 
# This Tidbyt application displays the status of AWS, Google Cloud, and Azure
# services with visual indicators (green for good, red for degraded/issues)

"""
This Tidbyt application monitors and displays the status of the three major
cloud providers (AWS, Google Cloud, Azure) with visual indicators showing
whether services are operational or experiencing issues.
"""

load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("encoding/json.star", "json")
load("time.star", "time")
load("schema.star", "schema")

load("encoding/base64.star", "base64")
AWS_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAABAElEQVQoz8WSTUvDUBBFT0RL8l5clKa0KGok2biQWhR05R8X3LhR8BPciKlGIaWliTEkLylY0FWKxYAQBGc1M8wZ7gxXc3rHn9SIpTrQ/4DLZSKl4OigjykF40lInhcIYQDQaVtkKuf88gal8kUQwJSC3u4OKi8AMHSdt/gdgGA4qpZqtZq4js3HbIY38DF0nWI6JRiOuL67x3VsrFbzp9Qwijk5PSNJU8Io5uLqFoA0Uzj2Jt7Ar75x1ZRsb20wnoTzRWVfCIP1tS6Zynl5DQDQvhug22lzuL+H69g0GisAJEnKw+MT3rNPGMXz52hVzpFSLNTlcKXU3wb/zAC1wS8cAF+/y0pEjgAAAABJRU5ErkJggg==
""")
GCP_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAACZklEQVR4nH2SX0hTYRjGn/f7zs5sO5tukqYzTDOdFmllgWJzMzG6CbpTKIkIIxAkiuyi27opyagLqavAsMiLwKgLwRxFBaXezT+Zov1Rs+Waa2vn7HxfF7bKi3ruXnge3vfl9wB/iRHhXyJi6+ffIQACgNuisAPZmYXlmq2CIBGKJUKD4ehcxDAEEUFK+SeYDjVuzMzp8hY+KLfbfBa2tkE3TUxFV58en9NbRj5NL6W9jBFBElDjcGb1lnoni5nmW4yZ0WfhyMNg+Ft/TNcxX9YcyDk1POEqqsuSIBBxgP069rG/5JbRUSbD7cWJ83vdPgCwEuD3FBX4L7wdD3RLWd022LPu37ZDvCL5ZIORHOaGHuTmhwH25tJJdlBR1gwFNacrm66kZMPleNKz70QFADB/FblunGVjqsNQZJIxPc7ingJlz/4d7IiqgDgRIu+GJvRETGdcVUsPd4+4iutduHuRd8iXFjl/Xxmt38VcVduY7eYZfjRTIwIIjHEQs8Bd0pBd2zk12tQl5fbmOx2K20n5UoV4EZJ9wTGxAgDt19CbxiSECcDE1+mh8Or7133O/JJKi82dryyG5QzpjPl3itb6gKP/1axlKUMRZAoOSnokoJAUhrDneHOzttS2ihQxPbowQ9Vepj2/Th/HM/KcnV924/N3S1ThugJTg33+qmApjQnoKcXqcHLVCj22Eh293eQhAGisVfOMY3X3wrmbfA5FQJAJMjU4ZntApgoQIAUQX54MTg2ca1kef7RARICUAOxWcm7WnIIYCBIAB/+xFZBsrV9SILYUiqYSEYk0R76+v/9VGv5PhNjsCpzTQGQAAAAASUVORK5CYII=
""")
AZURE_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAA+0lEQVR4nNWSvUrEQBSFv8ydhImCmDyC76GNvdopWLiFD+CjCJaLoI0gKD7EWtlYKNjbLUhWIrL5m7m2OyktBE95ON/94yb1wZayokG1KZy46cvX5H5vzu4+V/WCRixuNWf4pf4etINqs2p4pRtUCYEQAgRPo4HODyOwcFm0tCouyYX1dFnma7BR4khwRkbg5ev7JOoIXlJkNvePb08QWj7bJT4xRKg93bmIS6mHXOB5xkl/zTYGrwHROJbIg8ZWGLCblv7u9uymPOLwWM6pPIxH9fVHE4O+Iymy0NZV/Q1DRdMv6FJDFoGIjY4DgKQOjDEGrOAwYP/v5/wAoxpi2W2kUPEAAAAASUVORK5CYII=
""")

# Status check endpoints - simplified for demonstration
AWS_STATUS_URL = "https://status.aws.amazon.com/rss/all.rss"
GOOGLE_STATUS_URL = "https://status.cloud.google.com/incidents.json"
AZURE_STATUS_URL = "https://status.dev.azure.com/_apis/status/health?api-version=7.1-preview.1"

def get_schema():
    """
    Defines the configuration schema for the application.
    """
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "refresh_interval",
                name = "Refresh Interval",
                desc = "How often to check status (minutes)",
                icon = "clock",
                default = "5",
                options = [
                    schema.Option(display = "1 minute", value = "1"),
                    schema.Option(display = "5 minutes", value = "5"),
                    schema.Option(display = "10 minutes", value = "10"),
                    schema.Option(display = "15 minutes", value = "15"),
                    schema.Option(display = "30 minutes", value = "30"),
                ],
            ),
        ],
    )

def check_aws_status():
    """
    Check AWS status by examining the AWS Service Health RSS feed.
    Logic:
    - Parse the first <item> title; AWS posts a final RESOLVED update when an
      incident ends. If the latest item is RESOLVED or "operating normally",
      treat as healthy.
    - Otherwise, consider it degraded.
    This avoids false reds caused by older incident keywords elsewhere in RSS.
    """
    cache_key = "aws_status"
    cached_status = cache.get(cache_key)
    if cached_status != None:
        return cached_status == "good"

    response = http.get(AWS_STATUS_URL, ttl_seconds = 60)
    if response.status_code == 200:
        content = str(response.body())

        # Extract first <item> <title> ... </title>
        lower = content.lower()
        item_start = lower.find("<item>")
        is_good = True
        if item_start != -1:
            title_tag = "<title>"
            title_cdata_open = "<![cdata["
            title_cdata_close = "]]></title>"

            # Find title within the first item block
            item_end = lower.find("</item>", item_start)
            block = lower[item_start:item_end if item_end != -1 else None]

            # Prefer CDATA title if present
            t_start = block.find(title_cdata_open)
            t_end = -1
            title = ""
            if t_start != -1:
                t_start += len(title_cdata_open)
                t_end = block.find(title_cdata_close, t_start)
                if t_end != -1:
                    title = block[t_start:t_end].strip()
            else:
                # Fallback: plain title tag
                t_start = block.find(title_tag)
                if t_start != -1:
                    t_start += len(title_tag)
                    t_end = block.find("</title>", t_start)
                    if t_end != -1:
                        title = block[t_start:t_end].strip()

            # Determine health from title
            if title:
                if ("[resolved]" in title) or ("operating normally" in title):
                    is_good = True
                else:
                    is_good = False
            else:
                # If we can't parse the title, fall back to optimistic default
                is_good = True
        else:
            # No items found; assume healthy
            is_good = True

        cache.set(cache_key, "good" if is_good else "bad", ttl_seconds = 300)
        return is_good

    # If fetch fails, assume healthy to avoid noisy false alarms
    return True

def check_google_status():
    """
    Check Google Cloud status by examining incidents JSON.
    Returns True if all services are operational, False if there are issues.
    """
    cache_key = "google_status"
    cached_status = cache.get(cache_key)
    
    if cached_status != None:
        return cached_status == "good"
    
    response = http.get(GOOGLE_STATUS_URL, ttl_seconds = 60)
    if response.status_code == 200:
        incidents = response.json()
        is_good = True

        # Check for active incidents
        if incidents and len(incidents) > 0:
            # Look for recent, unresolved incidents
            for incident in incidents[:5]:  # Check recent incidents
                if incident.get("end") == None:  # No end time means ongoing
                    is_good = False
                    break

        cache.set(cache_key, "good" if is_good else "bad", ttl_seconds = 300)
        return is_good
    
    return True

def check_azure_status():
    """
    Check Azure status using Azure DevOps status API.
    Returns True if all services are operational, False if there are issues.
    """
    cache_key = "azure_status"
    cached_status = cache.get(cache_key)
    
    if cached_status != None:
        return cached_status == "good"
    
    response = http.get(AZURE_STATUS_URL, ttl_seconds = 60)
    if response.status_code == 200:
        data = response.json()
        status = data.get("status", {})
        health = status.get("health", "healthy")

        is_good = health == "healthy"
        cache.set(cache_key, "good" if is_good else "bad", ttl_seconds = 300)
        return is_good
    
    return True

def create_status_indicator(is_good):
    """
    Create a circular status indicator (green for good, red for issues).
    """
    color = "#00FF00" if is_good else "#FF0000"
    return render.Circle(
        diameter = 6,
        color = color,
    )

def main(config):
    """
    Main function to render the cloud status monitor.
    """
    # Check status for each cloud provider
    aws_status = check_aws_status()
    google_status = check_google_status()
    azure_status = check_azure_status()
    
    # Build the display as one row with three columns (AWS, GCP, Azure)
    def provider_column(icon, label, color, is_good):
        children = [
            render.Image(src = icon, width = 14, height = 14),
            render.Box(width = 1, height = 2),
            create_status_indicator(is_good),
        ]
        return render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = children,
        )

    icons_row = render.Row(
        expanded = True,
        main_align = "space_evenly",
        cross_align = "center",
        children = [
            provider_column(AWS_ICON, "AWS", "#FF9900", aws_status),
            provider_column(GCP_ICON, "GCP", "#4285F4", google_status),
            provider_column(AZURE_ICON, "Azure", "#0078D4", azure_status),
        ],
    )
    
    # Add title
    title = render.Text(
        "CLOUD STATUS",
        color = "#FFFFFF",
        font = "tom-thumb",
    )
    
    # Return the complete display
    return render.Root(
        child = render.Column(
            expanded = True,
            main_align = "space_evenly",
            cross_align = "center",
            children = [
                title,
                render.Box(width = 64, height = 1, color = "#333333"),  # Separator line
                icons_row,
            ],
        ),
    )
