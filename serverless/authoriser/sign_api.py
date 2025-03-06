import json
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from datetime import datetime

AWS_REGION = "ap-southeast-1"  # Change this to your region
SERVICE = "execute-api"

def lambda_handler(event, context):
    """Lambda@Edge function to sign API Gateway requests with SigV4 and forward JWT"""
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    # Extract JWT Token from Cookie Header (if present)
    jwt_token = headers.get("cookie", [{}])[0].get("value", "")
    print(f"JWT Token: {jwt_token}")

    # Extract API Gateway Host from Host header
    api_host = headers.get("host", [{}])[0].get("value", "")
    print(f"API Host: {api_host}")

    # Prepare the HTTP request for signing
    method = request["method"]
    path = request["uri"]
    query_string = request.get("querystring", "")
    body = ""  # You can adjust this if you have a payload
    date_now = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    
    # Set up the canonical request headers for signing
    request_headers = {
        "host": api_host,
        "x-amz-date": date_now
    }

    # Use AWSRequest to prepare the request
    aws_request = AWSRequest(
        method=method,
        url=f"https://{api_host}{path}?{query_string}",
        data=body,
        headers=request_headers
    )

    # Use SigV4Auth to sign the request
    session = boto3.Session()
    signer = SigV4Auth(session.get_credentials(), SERVICE, AWS_REGION)
    signer.add_auth(aws_request)

    # Add the signed authorization header
    signed_headers = {key.lower(): [{"key": key, "value": value}] for key, value in aws_request.headers.items()}

    # If a JWT token exists, add it to the Authorization header
    if jwt_token:
        signed_headers["authorization"] = [
            {"key": "Authorization", "value": f"Bearer {jwt_token}"}
        ]

    # Ensure the cookie header is formatted as an array
    if jwt_token:
        signed_headers["cookie"] = [{"key": "Cookie", "value": f"CognitoToken={jwt_token}"}]

    # Update request headers
    request["headers"] = signed_headers

    print(f"Signed Request: {json.dumps(request, indent=2)}")
    
    return request
