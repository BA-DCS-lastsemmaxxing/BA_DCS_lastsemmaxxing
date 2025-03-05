import json
import datetime
import hashlib
import hmac
import boto3

AWS_REGION = "ap-southeast-1"  # AWS Region for your API Gateway
SERVICE = "execute-api"        # Service name
ALGORITHM = "AWS4-HMAC-SHA256" # Signature algorithm

def sign(key, msg):
    """Generate HMAC signature."""
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

def get_signature_key(secret_key, date_stamp, region, service):
    """Generate the AWS Signature Version 4 signing key."""
    k_date = sign(("AWS4" + secret_key).encode("utf-8"), date_stamp)
    k_region = sign(k_date, region)
    k_service = sign(k_region, service)
    k_signing = sign(k_service, "aws4_request")
    return k_signing

def lambda_handler(event, context):
    """Lambda@Edge function to sign API Gateway requests with SigV4 and forward JWT."""
    request = event["Records"][0]["cf"]["request"]
    headers = request["headers"]

    # Extract JWT Token from Cookie Header (if present)
    jwt_token = headers.get("cookie", [{}])[0].get("value", "")

    # Remove any existing Authorization headers to avoid conflicts
    if "authorization" in headers:
        del headers["authorization"]

    # IMPT: Set API Gateway Host Manually
    api_host = "kay8ehgv4g.execute-api.ap-southeast-1.amazonaws.com"

    # Generate Timestamp for Signature
    t = datetime.datetime.utcnow()
    amz_date = t.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = t.strftime("%Y%m%d")  # YYYYMMDD format

    # Extract HTTP Method, URI, and Query String
    http_method = request["method"]
    canonical_uri = "/prod" + request["uri"]

    # Ensure Query String is Sorted for SigV4 (Handle empty query string)
    raw_query_string = request.get("querystring", "")
    canonical_querystring = ""
    if raw_query_string:
        query_params = sorted(raw_query_string.split("&"))
        canonical_querystring = "&".join(query_params)

    # Canonical Headers (Add host header for SigV4)
    canonical_headers = f"host:{api_host}\nx-amz-date:{amz_date}\n"
    signed_headers = "host;x-amz-date"

    # Compute Payload Hash (empty body in case of API Gateway request)
    payload_hash = hashlib.sha256(b"").hexdigest()

    # Construct Canonical Request
    canonical_request = (
        f"{http_method}\n{canonical_uri}\n{canonical_querystring}\n"
        f"{canonical_headers}\n{signed_headers}\n{payload_hash}"
    )

    print("Canonical Request: ", canonical_request)  # Debugging step

    # Construct String to Sign
    credential_scope = f"{date_stamp}/{AWS_REGION}/{SERVICE}/aws4_request"
    string_to_sign = (
        f"{ALGORITHM}\n{amz_date}\n{credential_scope}\n"
        f"{hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()}"
    )

    print("String to Sign: ", string_to_sign)  # Debugging step

    # Use Boto3 to get AWS credentials automatically
    session = boto3.Session()
    credentials = session.get_credentials()
    access_key = credentials.access_key
    secret_key = credentials.secret_key
    session_token = credentials.token  # Optional, but necessary for temporary credentials

    # Generate Signature using AWS SigV4
    signing_key = get_signature_key(secret_key, date_stamp, AWS_REGION, SERVICE)
    signature = hmac.new(signing_key, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()

    # Construct Authorization Header for SigV4
    sigv4_authorization_header = (
        f"{ALGORITHM} Credential={access_key}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    # Attach Authorization Header
    headers["authorization"] = [{"key": "Authorization", "value": sigv4_authorization_header}]
    
    # Add 'x-amz-date' header for SigV4
    headers["x-amz-date"] = [{"key": "x-amz-date", "value": amz_date}]

    # If using temporary credentials, add the session token to 'x-amz-security-token'
    if session_token:
        headers["x-amz-security-token"] = [{"key": "x-amz-security-token", "value": session_token}]

    # Forward JWT Token in Cookie Header (if exists)
    if jwt_token:
        headers["cookie"] = [{"key": "Cookie", "value": jwt_token}]

    return request
