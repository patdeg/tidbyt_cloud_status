"""
AI Platform Status for Tidbyt

Displays the status of OpenAI, Anthropic, and Groq with a compact row of
provider icons and a status dot (green = OK, red = issues).
"""

load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("encoding/json.star", "json")
load("schema.star", "schema")
load("encoding/base64.star", "base64")

# Statuspage/summary endpoints
OPENAI_STATUS_URL = "https://status.openai.com/api/v2/summary.json"
ANTHROPIC_STATUS_URL = "https://status.claude.com/api/v2/summary.json"
GROQ_STATUS_URL = "https://groqstatus.com/api/v2/summary.json"

# Embedded icons (base64 PNG)
OPENAI_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAACTUlEQVQoz2WSMUhyYRSGn6xFbhBEwyWCkA+ciiC4CBVCQ4JLYDRchQhqaSgiyGgrIQeHaOqDCKQbLnIhouUGLQ0NbiLVUEuD0B0K1LgSOXT+KRH+ZzuH857lfZAeOp2OuK4riURCDMOQWCwmWmsJgkA6nU7vqdA7uK4rSimxbVu01hKLxboPEomEaK3F930REQkBtNttbm9vyeVyJJNJTk5O+NtHIhHi8TjRaJSjoyN2dnZot9sQBIFsbm6KYRhiGIZ4nie2bYtSSrLZrJRKJcnn81KtVsXzPFFKidZa+sfGxg7Pzs5YX1/n9fWVubk5KpUKa2trNJtNXNfl5eWFi4sLTNOkXq/z+/tL6Pr6mng8TiaT4Y9Wq4XjOHieB8DW1hZLS0sUi0Wenp4ACLVaLQYHB7uhr68vAHZ3d7m7u8OyLPb29gDI5XLMzs5SqVToT6VShw8PD8zMzNBsNrm/v2doaIjt7W1M06TRaPDz80OtVuPj44ONjQ3K5TJ91WpVlpeXGRkZYXV1lUajwc3NDZOTk0xPT+M4DpZlEQ6HqdVqFAoFVlZWGDBNk3A4zOfnJ8fHx1iWxeLiIqenpzw+PhKJROjl+fmZt7c3+nzfl4WFBdLpNNFolPPzc97f30mn04yPj3N5ecnU1BQAV1dXACilCJmmSTKZpFgsAlAoFNjf38f3fQ4ODhgeHiaTyVCv1/n+/mZ+fh7HcUBExPf9bukTExMyOjoqhmF0i9dai1JKSqXS/64GQSCe50k+nxfbtruO/vmazWYlCIJu8B+iBHBENdJuzwAAAABJRU5ErkJggg==
""")

ANTHROPIC_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAACO0lEQVR4nI2SwUobYRSFz38zcRLdCMGghqIV6cKFO6tQoeoD1IT6GupOsqtQrEJ9BdtuLNTgqkjxAeyy0kWRRpuaJo1ITFoZM/PP5J85XcS0FLro4q7O+e7hwMHi4qOhavXbcRDoUOtWGAQe/3UdTYfVauVjLpfNqFqt+nloKHPP991IRIQkwjCEiEBEYIxBLBaDUgpRFEW2nZTLy8uvyhifxphIRAQgLCsOpSwARBi2EYv1gDQwpg2gA1uWJdKFSEIkjkqlgq2tTRwff0C9Xsfm5jNUKhWIxNHxdBh0O3jeDUlyff0JATCbXaTj/GR/fz/z+TWSpOfd/O6MIPDo+y6NCXh9/YOTk5OcnX3AwcFBlkqn3Nh4ytHRUTrONY0J6PvuH7CbVii8YSqVYrlc4vT0febza6xWy0wkEtzfL/yVKgAgIgAi7O6+xsDAAIrFL8hkMtjbKyCdTmN+fg47Oy8B8NYLQOsWyZDF4gmHh4c5Pj7OsbExTkxMMJlM8vDwHQ8O3rKvr49nZ0WSIbVuEa7rkCRXV5eZSqV4fl5is3nFZrPJubmHnJmZodYtptNprqwskyRd16ElIlEYtmVqagoLCwsYGbkLY3xYlo3t7ec4OnoPAHj16gUajQbCsA0RiW4H0I5su08AwPddKKUAED09SQAK7bZGPJ5AR29FlhUXqdevTm27V1zXibRuQUSglIJSAt/3oHUL3Yeu60S23SuNRrOMXC6bqdW+f/qfkfu+F15c1E6Wlh7f+QWn88txzsaV8gAAAABJRU5ErkJggg==
""")

GROQ_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAABjklEQVR4nGWSvU+UQRDGfzO7HifqQcQoiY1W9iYalRDt0QL/BQtNLKyoSCwtTKwt7K1NSEzsLDShoLC1AApiRC7hTjm9A96dodg97l7vaXZ2PjLPPDOyc1e2ppU5B2McIuDO/xDQvtGJU8rMdKBl2YmXKGagAqrZLlABqzB1MC8FVl53wTWgi4+z7cVPTnbBdIJLCPhvIy4/J9x8gP+pIMZxqrlz/acwSOj1qzSevsK+b0CCUb8RcuFwMAOvnMbKW6R5Du/sIa1mmTfUCkccVPFeRePJCvHeIwCmXr7He1187weD1WW804aogA+pCn5cIVfmCHceYj+38YMucn4Wnb9GWl/Dd9vImXi6Ivm1IO0LgUsGIApuYA3C7fs033wirX+k/2IJaYbSyekZ+3VV3bKqB4dw8TI++Mfh62eISlFjJNDkOhAQCDducfRuFdvcgbOhdgR1cYZIFbQi6dtn0tc1ZFYhpYm0qE7U01sb8nD8ywfUPN/YWExzOMa/zq4fc+S1cKElCqm+eAHpG90TmHimJ7TzdFEAAAAASUVORK5CYII=
""")

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "refresh_interval",
                name = "Refresh Interval",
                desc = "Minutes between status checks",
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

def _indicator_is_good(status_json):
    # Statuspage-style JSON: { status: { indicator: "none" | "minor" | ... } }
    status = status_json.get("status") or {}
    indicator = status.get("indicator") or "none"
    return indicator == "none"

def check_status(url, cache_key):
    cached_status = cache.get(cache_key)
    if cached_status != None:
        return cached_status == "good"
    resp = http.get(url, ttl_seconds = 60)
    if resp.status_code == 200:
        ok = _indicator_is_good(resp.json())
        cache.set(cache_key, "good" if ok else "bad", ttl_seconds = 300)
        return ok
    # Assume healthy on fetch error to avoid noisy false alarms.
    return True

def check_openai_status():
    return check_status(OPENAI_STATUS_URL, "openai_status")

def check_anthropic_status():
    return check_status(ANTHROPIC_STATUS_URL, "anthropic_status")

def check_groq_status():
    return check_status(GROQ_STATUS_URL, "groq_status")

def create_status_indicator(is_good):
    return render.Circle(diameter = 6, color = "#00FF00" if is_good else "#FF0000")

def provider_column(icon_bytes, is_good):
    children = []
    if icon_bytes != None:
        children.append(render.Image(src = icon_bytes, width = 14, height = 14))
    else:
        # Fallback: blank box to keep alignment
        children.append(render.Box(width = 14, height = 14))
    children.append(render.Box(width = 1, height = 2))
    children.append(create_status_indicator(is_good))
    return render.Column(
        expanded = True,
        main_align = "center",
        cross_align = "center",
        children = children,
    )

def main(config):
    # Read refresh interval; the platform controls actual refresh cadence.
    refresh_minutes = int(config.get("refresh_interval", "5"))
    _ = refresh_minutes  # reserved for future use

    # Fetch status booleans
    openai_ok = check_openai_status()
    anthropic_ok = check_anthropic_status()
    groq_ok = check_groq_status()

    row = render.Row(
        expanded = True,
        main_align = "space_evenly",
        cross_align = "center",
        children = [
            provider_column(OPENAI_ICON, openai_ok),
            provider_column(ANTHROPIC_ICON, anthropic_ok),
            provider_column(GROQ_ICON, groq_ok),
        ],
    )

    title = render.Text("AI STATUS", color = "#FFFFFF", font = "tom-thumb")

    return render.Root(
        child = render.Column(
            expanded = True,
            main_align = "space_evenly",
            cross_align = "center",
            children = [
                title,
                render.Box(width = 64, height = 1, color = "#333333"),
                row,
            ],
        ),
    )
