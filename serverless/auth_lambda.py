import json
import re

def lambda_handler(event, context):
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    # Allowed paths (accessible without authentication)
    allowed_paths = ["/login.html", "/favicon.ico", "/_next/static/"]

    # Check for authentication token in cookies
    authenticated = False
    print("headers", headers, flush=True)
    if "cookie" in headers:
        cookies = headers["cookie"][0]["value"]
        if "CognitoToken" in cookies:
            authenticated = True # User is authenticated
                                

    # ✅ Allow access to the login page & public assets
    print("request uri: ", request["uri"],flush=True)
    if request["uri"] == "/":
        return request
    for path in allowed_paths:
        print("allowed path: ", path, flush=True)
        if path in request["uri"]:
            return request

    # 🔄 Redirect all other requests to the login page if unauthenticated
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
