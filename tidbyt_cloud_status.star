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
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAABQklEQVQoz6WSsUvDQBTGf02zO3QpWNqK0sHsooMGMmSxIBScAzcoDaVLEXddhOLSsUOlf0IG14Y4Ck5SwdCjuUEIOAoODq1D2qgFpdS3vOPg9933vnuZrKZNWaG0VaB/gXolDydn1wAMBgMAoijiaTik7roEQUC5XCaKIoQQAHTbLfQwBillqtRsNul0OgghME0TpRSWZSGlpFgs4vs+YQz6tmFg23YKep5HqVSiVqvRaDTSe6UUALZtEwQBOkChUMBxnNTKXGj0cIueM+i2W4RxMkK/3/8ZjmmaSClRSiGlpFqtoucMhBCEMdRdl17vJnWQ2dtkej9eLtxKHtbXZqmeWrA7nvD4ouE//w2eH05w9mcvZjVtenk0Wfr/Xt++gXMbB1tfAhfHSb/y4P0jOd+NNMJ4AVysnY1E5Lf5M6su+ScMmm/oIzT5xwAAAABJRU5ErkJggg==
""")
GCP_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAABoUlEQVQoz2Pc0JzEzEAGYEIXcBXfo2F45PYiq4OXf1sdvPzb6OjtB+cFTdzxajQ8cnvR11Xilzn//oiEiXH8+SGdvWH+lnfM36cgq2WBMc4Lmrhb/b0cycDAwPCdmWM5578fT74zccgwMDAwLFUJjTrz0yCDieHvzxiWxcUoGitVGkJ/ZrO8ZGBgYPg+Q5nhmJ1uFUzu3B/d1wwMDPn/GJjzNzAnLgr4O/8i49dZctosSt+nMDAy2KJ44j/D4e3HfV1grrn8WmcrAwMDAzcrw+bg/wsCWf6I/tnDwsggysDAwPDjE+trBgYGBg6+36LIZjz8pPuC+f+fiwwMDNpffzP7Lv0fe5bx517RPwwMDAz/fzMu3nHaJwUWSOdtVOPQQ3LJn9jefwzM+Sih+rJfnQ0eUFg0wQDz/79/mP///QO3keE/w2Gb1w6nkBXJ38hiR+Yz/mdwYGBg0GZgYFjJ8nOfSjq7052ZPz6zajAy/HdACR+mHwxMfzn+oNvKzcHSx7SPQ3PBn7uc+jkMFj+JSGlF3Bws5gF/519kpFpaJRYAAJ1JmAEpLB3MAAAAAElFTkSuQmCC
""")
AZURE_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAABt0lEQVQoz42Sz0vcQBTHv5lMEjfrhlbb0pIt2FVJQfSwCD2ohyJ7sJf+B714tSiW/gOFHvTg/6B43EuhsIeCHtqTZy20SLXQXRd/RJttnGSSyXooI5O1BR8MzHszn/fefN9o7mKdoMdixhbKT0s2APi7Lf8s6m/euW831Du0Fwqa/vvHs8/f2BMPKADYzwD785cPnSOWA3PVwoB7hLPZ5tY2iY7ZdXxgZvplzNjCf0FqiBqsQhW3sBwY++yR3H/9uNONjhnkevJi5lUYcO8GeHFyOUc0vJW+FbS7alLR7asmcVr5Z8XUKmWpVcoAQJiFze/1Txvq+eikM34DLPRrw7n3mvoKNfUVNXbUMudlu0SqqTuDrwFAWEU9dh5q1BC1yB2rcj/VJOhOVYdluxQAkjitROdpBVYR2b1yFwAClNeQCGScJUCJygSjk874yc+0QQCA8Gj6uvfTX9pd0T6Q/v5hJ6cDL4y9CwPukTDgnqomAPxpnS4553vL0o/anbR3jpQaosb+KqkDgPG7veq4Aw0AIIZ+liViff+wQ0aGkKgfRXMX60QdbNExv6mZw4B76vwAwLDojyt2OLOVh76h9gAAAABJRU5ErkJggg==
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
    Check AWS status by examining RSS feed.
    Returns True if all services are operational, False if there are issues.
    """
    cache_key = "aws_status"
    cached_status = cache.get(cache_key)
    
    if cached_status != None:
        return cached_status == "good"
    
    # For a real implementation, you would parse the RSS feed
    # For now, we'll do a simplified check
    response = http.get(AWS_STATUS_URL, ttl_seconds = 60)
    if response.status_code == 200:
        # Check if RSS contains any active incidents
        content = str(response.body())
        is_good = True

        # Check for problem indicators in RSS
        problem_keywords = ["Service disruption", "Degraded", "Investigating", "Identified", "Monitoring"]
        for keyword in problem_keywords:
            if keyword.lower() in content.lower():
                # Found a potential issue, but need to check if it's resolved
                if "[RESOLVED]" not in content[:500]:  # Check recent items
                    is_good = False
                    break

        cache.set(cache_key, "good" if is_good else "bad", ttl_seconds = 300)
        return is_good
    
    # Default to good if can't fetch
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
