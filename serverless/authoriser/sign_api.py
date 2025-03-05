import json
import datetime
import hashlib
import hmac
import boto3

AWS_REGION = "ap-southeast-1"
SERVICE = "execute-api"
ALGORITHM = "AWS4-HMAC-SHA256"

def sign(key, msg):
    """Generate HMAC signature"""
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

def get_signature_key(secret_key, date_stamp, region, service):
    """Generate AWS Signature Version 4 signing key"""
    k_date = sign(("AWS4" + secret_key).encode("utf-8"), date_stamp)
    k_region = sign(k_date, region)
    k_service = sign(k_region, service)
    k_signing = sign(k_service, "aws4_request")
    return k_signing

def lambda_handler(event, context):
    """Lambda@Edge function to sign API Gateway requests with SigV4 and forward JWT"""
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    # Extract JWT Token from Cookie Header (if present)
    jwt_token = headers.get("cookie", [{}])[0].get("value", "")

    # Remove any existing Authorization headers to avoid conflicts
    if "authorization" in headers:
        del headers["authorization"]

    # Extract API Gateway Host
    api_host = headers["host"][0]["value"]

    # Retrieve AWS Credentials from IAM role
    session = boto3.Session()
    credentials = session.get_credentials()
    access_key = credentials.access_key
    secret_key = credentials.secret_key

    if not access_key or not secret_key:
        return {"status": "500", "body": "Missing AWS credentials"}

    # Generate Timestamp for Signature
    t = datetime.datetime.utcnow()
    amz_date = t.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = t.strftime("%Y%m%d")  # YYYYMMDD format

    # Extract HTTP Method, URI, and Query String
    http_method = request["method"]
    canonical_uri = request["uri"]

    # Ensure Query String is Sorted for SigV4
    raw_query_string = request.get("querystring", "")
    query_params = sorted(raw_query_string.split("&"))
    canonical_querystring = "&".join(query_params)

    # Compute Payload Hash (Fix: Read actual request body if available)
    payload_hash = hashlib.sha256(request.get("body", {}).get("data", b"")).hexdigest()

    # Canonical Headers (Add X-Amz-Date here)
    canonical_headers = f"host:{api_host}\n" + f"x-amz-date:{amz_date}\n"
    signed_headers = "host;x-amz-date"

    # Construct Canonical Request
    canonical_request = (
        f"{http_method}\n{canonical_uri}\n{canonical_querystring}\n"
        f"{canonical_headers}\n{signed_headers}\n{payload_hash}"
    )

    # Construct String to Sign
    credential_scope = f"{date_stamp}/{AWS_REGION}/{SERVICE}/aws4_request"
    string_to_sign = (
        f"{ALGORITHM}\n{amz_date}\n{credential_scope}\n"
        f"{hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()}"
    )

    # Generate Signature
    signing_key = get_signature_key(secret_key, date_stamp, AWS_REGION, SERVICE)
    signature = hmac.new(signing_key, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()

    # Construct Authorization Header for SigV4
    sigv4_authorization_header = (
        f"{ALGORITHM} Credential={access_key}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    # Attach Signed Headers
    headers["authorization"] = [{"key": "Authorization", "value": sigv4_authorization_header}]
    
    # Add X-Amz-Date to headers
    headers["x-amz-date"] = [{"key": "X-Amz-Date", "value": amz_date}]

    # Forward JWT Token in Cookie Header (if exists)
    if jwt_token:
        headers["cookie"] = [{"key": "Cookie", "value": jwt_token}]

    return request
