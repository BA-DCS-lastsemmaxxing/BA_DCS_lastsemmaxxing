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
            # Find the cookie that starts with "CognitoToken=" and extract just the token
            if cookie["value"].startswith("CognitoToken="):
                jwt_token = cookie["value"].split('=')[1]  # Get the token part only
                break

    # Prepare request details for signing
    method = request["method"]
    path = request["uri"]
    query_string = request.get("querystring", "")
    body = ""  # Adjust if needed
    date_now = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

    # Log the request details that are being prepared for signing
    print(f"Request Method: {method}")
    print(f"Request Path: {path}")
    print(f"Query String: {query_string}")
    print(f"Request Body: {body}")
    print(f"x-amz-date: {date_now}")

    # Create a dictionary of headers to sign
    signing_headers = {
        "host": api_host,
        "x-amz-date": date_now  # Ensure this is always present
    }

    # Log the signing headers
    print(f"Signing Headers: {json.dumps(signing_headers, indent=2)}")

    # Construct AWSRequest for signing
    aws_request = AWSRequest(
        method=method,
        url=f"https://{api_host}{path}?{query_string}",
        data=body,
        headers=signing_headers
    )

    # Convert HTTPHeaders object to a dictionary for logging
    canonical_headers = dict(aws_request.headers.items())

    # Log the canonical request headers
    print(f"Canonical Request URL: https://{api_host}{path}?{query_string}")
    print(f"Canonical Request Headers: {json.dumps(canonical_headers, indent=2)}")

    # Sign the request using AWS SigV4
    session = boto3.Session()
    credentials = session.get_credentials()
    print(f"AWS Access Key: {credentials.access_key}")
    print(f"AWS Secret Key: {'Exists' if credentials.secret_key else 'Missing'}")
    print(f"AWS Session Token: {'Exists' if credentials.token else 'Missing'}")

    signer = SigV4Auth(credentials, SERVICE, AWS_REGION)
    signer.add_auth(aws_request)

    # The string to sign is not directly accessible, but you can log important components.
    print(f"Signed Authorization Header: {aws_request.headers.get('Authorization')}")

    # Extract signed headers
    signed_auth_header = aws_request.headers["Authorization"]
    
    # Add signed headers back into the request
    signed_headers = headers.copy()
    
    # Ensure Authorization and x-amz-date headers are set properly
    signed_headers["authorization"] = [{"key": "Authorization", "value": signed_auth_header}]
    signed_headers["x-amz-date"] = [{"key": "x-amz-date", "value": date_now}]
    
    # Add x-amz-security-token if using temporary credentials
    if credentials.token:
        signed_headers["x-amz-security-token"] = [{"key": "x-amz-security-token", "value": credentials.token}]

    # Log the signed headers
    print(f"Signed Headers: {json.dumps(signed_headers, indent=2)}")

    # Preserve Cookie header if it exists and add the JWT token back (without "CognitoToken=")
    if jwt_token:
        signed_headers["cookie"] = [{"key": "cookie", "value": f"{jwt_token}"}]

    # Update request headers
    request["headers"] = signed_headers

    # Log the final signed request
    print(f"Final Signed Request: {json.dumps(request, indent=2)}")
    print(f"🚀 Final Signed Request URL: https://{api_host}{path}?{query_string}")
    
    print(f"JWT Token in Cookie: {jwt_token}")
    
    return request
