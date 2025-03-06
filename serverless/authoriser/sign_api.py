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

    # Extract API Gateway Host (DO NOT modify it)
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

    # Prepare request details for signing
    method = request["method"]
    path = request["uri"]
    query_string = request.get("querystring", "")
    body = ""  # Adjust if needed
    date_now = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

    # Create a dictionary of headers to sign
    signing_headers = {
        "host": api_host,
        "x-amz-date": date_now
    }

    # Construct AWSRequest for signing
    aws_request = AWSRequest(
        method=method,
        url=f"https://{api_host}{path}?{query_string}",
        data=body,
        headers=signing_headers
    )

    # Sign the request using AWS SigV4
    session = boto3.Session()
    credentials = session.get_credentials()
    signer = SigV4Auth(credentials, SERVICE, AWS_REGION)
    signer.add_auth(aws_request)

    # Extract signed headers
    signed_auth_header = aws_request.headers["Authorization"]
    
    # Add signed Authorization header (without modifying CloudFront's structure)
    signed_headers = headers.copy()
    
    # Ensure Authorization header follows CloudFront format
    signed_headers["authorization"] = [{"key": "Authorization", "value": signed_auth_header}]

    # Preserve Cookie header if it exists
    if "cookie" in headers:
        signed_headers["cookie"] = headers["cookie"]

    # Update request headers
    request["headers"] = signed_headers

    print(f"Final Signed Request: {json.dumps(request, indent=2)}")
    
    return request
