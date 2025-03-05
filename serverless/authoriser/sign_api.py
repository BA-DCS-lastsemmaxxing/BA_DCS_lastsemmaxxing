import json
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from datetime import datetime

AWS_REGION = "ap-southeast-1"  # Change to your API Gateway region
SERVICE = "execute-api"


def lambda_handler(event, context):
    """Lambda@Edge function to sign API Gateway requests with SigV4 and forward JWT"""
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    # Extract JWT Token from Cookie Header (if present)
    jwt_token = headers.get("cookie", [{}])[0].get("value", "")

    # Remove any existing Authorization headers to avoid conflicts
    if "authorization" in headers:
        del headers["authorization"]

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

    # Use SigV4Auth to sign the request with the Lambda execution role credentials
    session = boto3.Session()  # Automatically uses IAM role credentials
    signer = SigV4Auth(session.get_credentials(), SERVICE, AWS_REGION)
    signer.add_auth(aws_request)

    # Add the signed authorization header to the request
    signed_headers = dict(aws_request.headers)

    # Ensure that headers are in array format for CloudFront
    signed_headers["authorization"] = [{"key": "Authorization", "value": signed_headers["authorization"]}]
    
    # If a JWT token exists, forward it in the Cookie header, also as an array of dicts
    if jwt_token:
        signed_headers["cookie"] = [{"key": "Cookie", "value": jwt_token}]
    
    # Update headers in the original request
    request["headers"] = signed_headers

    print(f"Signed Request: {request}")
    
    return request
