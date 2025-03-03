import json
import re

def lambda_handler(event, context):
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    # Allowed paths (accessible without authentication)
    allowed_paths = [
        "/login.html",
        "/favicon.ico",
        "/_next/static/",
        "/dashboard"  # ✅ Temporarily allow dashboard for redirection
    ]

    # Check for authentication token in cookies
    authenticated = False
    print("Headers:", headers, flush=True)

    if "cookie" in headers:
        cookies = headers["cookie"][0]["value"]
        print("Cookies:", cookies, flush=True)  # Debugging: Check what cookies are sent
        if "CognitoToken" in cookies:
            authenticated = True  # ✅ User is authenticated

    print("Request URI:", request["uri"], flush=True)

    # ✅ Allow access to the login page & public assets
    if request["uri"] == "/" or any(path in request["uri"] for path in allowed_paths):
        return request

    # 🔄 Redirect unauthenticated users to login page
    if not authenticated:
        return {
            "status": "302",
            "statusDescription": "Found",
            "headers": {
                "location": [{"key": "Location", "value": "/login.html"}]
            }
        }

    # ✅ Allow access if authenticated
    return request
