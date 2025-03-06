import json
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from datetime import datetime

AWS_REGION = "ap-southeast-1"  # Change to your API Gateway region
SERVICE = "execute-api"

def lambda_handler(event, context):
    """Lambda@Edge function to sign API Gateway requests with SigV4 while preserving the Cognito token in Cookie"""
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]
    
    # Log the original request headers
    print(f"Original Request Headers: {json.dumps(headers, indent=2)}")

    # Extract API Gateway Host (DO NOT modify it)
    api_host = headers["host"][0]["value"]
    print(f"API Host: {api_host}")

    # Extract Cognito Token from Cookie (If present)
    jwt_token = None
    if "cookie" in headers:
        for cookie in headers["cookie"]:
            if cookie["value"].startswith("CognitoToken="):
                jwt_token = cookie["value"].split('=')[1]  # Get the token part only
                break

    # Prepare request details for signing
    method = request["method"]
    path = request["uri"]
    if not path.startswith('/prod'):
        path = '/prod' + path  # Prepend the stage name (e.g., "/prod") to the path if needed
    query_string = request.get("querystring", "")
    body = ""  # Adjust if needed
    date_now = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

    # Log the request details
    print(f"Request Method: {method}")
    print(f"Request Path: {path}")
    print(f"Query String: {query_string}")
    print(f"Request Body: {body}")
    print(f"x-amz-date: {date_now}")

    # Fetch credentials (before using them in headers)
    session = boto3.Session()
    credentials = session.get_credentials()

    # Create a dictionary of headers to sign
    signing_headers = {
        "host": api_host,
        "x-amz-date": date_now  # Ensure this is always present
    }

    if credentials.token:
        signing_headers["x-amz-security-token"] = credentials.token  # Include token if available

    # Log the signing headers
    print(f"Signing Headers: {json.dumps(signing_headers, indent=2)}")

    # Canonical Request Part 1: HTTP Method
    canonical_method = method
    print(f"Canonical Method: {canonical_method}")

    # Canonical Request Part 2: Request Path
    canonical_path = path
    print(f"Canonical Path: {canonical_path}")

    # Canonical Request Part 3: Query String
    canonical_querystring = query_string
    print(f"Canonical Query String: {canonical_querystring}")

    # Canonical Request Part 4: Canonical Headers (Host, x-amz-date, and x-amz-security-token if present)
    canonical_headers = f"host:{api_host}\nx-amz-date:{date_now}\n"
    if credentials.token:
        canonical_headers += f"x-amz-security-token:{credentials.token}\n"  # Include token if available
    print(f"Canonical Headers: {canonical_headers}")

    # Canonical Request Part 5: Signed Headers
    # Dynamically generate the signed headers based on the headers used in canonical headers
    signed_headers = ";".join(sorted(signing_headers.keys()))  # Sorting ensures consistency
    print(f"Signed Headers: {signed_headers}")

    # Canonical Request Part 6: Payload Hash (Empty body here, so hash is the empty string)
    payload_hash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"  # SHA-256 of empty string
    print(f"Payload Hash: {payload_hash}")

    # Construct the Canonical Request
    canonical_request = f"{canonical_method}\n{canonical_path}\n{canonical_querystring}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    print(f"Canonical Request: {canonical_request}")

    # Construct the String-to-Sign (Part 1)
    date_stamp = date_now[:8]
    credential_scope = f"{date_stamp}/{AWS_REGION}/{SERVICE}/aws4_request"
    string_to_sign = f"AWS4-HMAC-SHA256\n{date_now}\n{credential_scope}\n{hash(canonical_request)}"
    print(f"String to Sign: {string_to_sign}")

    # Sign the request using AWS SigV4
    signer = SigV4Auth(credentials, SERVICE, AWS_REGION)
    aws_request = AWSRequest(
        method=method,
        url=f"https://{api_host}{path}?{query_string}",
        data=body,
        headers=signing_headers
    )
    signer.add_auth(aws_request)

    # Log the signed authorization header
    print(f"Signed Authorization Header: {aws_request.headers.get('Authorization')}")

    # Add signed headers back into the request
    signed_headers = headers.copy()
    signed_headers["authorization"] = [{"key": "Authorization", "value": aws_request.headers['Authorization']}]
    signed_headers["x-amz-date"] = [{"key": "x-amz-date", "value": date_now}]
    
    # Log the final signed headers
    print(f"Final Signed Headers: {json.dumps(signed_headers, indent=2)}")

    # Preserve Cookie header if it exists and add the JWT token back (without "CognitoToken=")
    if jwt_token:
        signed_headers["cookie"] = [{"key": "cookie", "value": f"CognitoToken={jwt_token}"}]

    # Update request headers
    request["headers"] = signed_headers

    # Log the final signed request
    print(f"Final Signed Request: {json.dumps(request, indent=2)}")
    print(f"🚀 Final Signed Request URL: https://{api_host}{path}?{query_string}")
    
    return request
