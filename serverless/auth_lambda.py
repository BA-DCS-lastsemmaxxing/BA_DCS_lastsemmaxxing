import json
import re

def lambda_handler(event, context):
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    # Allowed paths (accessible without authentication)
    allowed_paths = ["/login.html", "/favicon.ico", "/public/"]

    # Check for authentication token in cookies
    authenticated = False
    if "cookie" in headers:
        cookies = headers["cookie"][0]["value"]
        if "CognitoToken" in cookies:
            authenticated = True  # User is authenticated

    # ✅ Allow access to the login page & public assets
    if request["uri"] in allowed_paths:
        return request

    # ❌ If requesting /api/*, check authentication
    if re.match(r"^/api/.*", request["uri"]):
        if authenticated:
            return request  # ✅ Allow API call if authenticated
        else:
            return {
                "status": "403",
                "statusDescription": "Forbidden",
                "body": json.dumps({"message": "Access Denied"}),
            }

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
