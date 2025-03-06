import json
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from datetime import datetime

AWS_REGION = "ap-southeast-1"  # Change to your API Gateway region
SERVICE = "execute-api"

def lambda_handler(event, context):
    """Lambda@Edge function to sign API Gateway requests with SigV4 and preserve JWT in Cookie"""
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    # Extract API Gateway Host (DO NOT modify)
    api_host = headers["host"][0]["value"]  
    print(f"API Host: {api_host}")

    # Extract Cognito Token from Cookie (If present)
    jwt_token = None
    if "cookie" in headers:
        for cookie in headers["cookie"]:
            if "CognitoToken=" in cookie["value"]:
                jwt_token = cookie["value"]
                break

    print(f"JWT Token from Cookie: {jwt_token}")

    # Prepare the HTTP request for signing
    method = request["method"]
    path = request["uri"]
    query_string = request.get("querystring", "")
    body = ""  # Adjust if needed
    date_now = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

    # Headers required for SigV4 signing (Do NOT modify `host`)
    signing_headers = {
        "x-amz-date": date_now,
        "host": api_host
    }

    # Use AWSRequest to prepare the request
    aws_request = AWSRequest(
        method=method,
        url=f"https://{api_host}{path}?{query_string}",
        data=body,
        headers=signing_headers
    )

    # Use SigV4Auth to sign the request
    session = boto3.Session()
    signer = SigV4Auth(session.get_credentials(), SERVICE, AWS_REGION)
    signer.add_auth(aws_request)

    # Convert signed headers to the correct format
    signed_headers = headers.copy()  # Preserve original headers
    for key, value in aws_request.headers.items():
        if key.lower() not in ["authorization", "host"]:  # Do NOT modify read-only headers
            signed_headers[key.lower()] = [{"key": key, "value": value}]

    # Preserve original Cookie header (Do NOT modify structure)
    if "cookie" in headers:
        signed_headers["cookie"] = headers["cookie"]

    # Update request headers
    request["headers"] = signed_headers

    print(f"Final Signed Request: {json.dumps(request, indent=2)}")
    
    return request
