import json
import boto3
import os

# AWS S3 Configuration
S3_BUCKET = os.getenv("S3_BUCKET")  # Ensure this is set in Lambda environment variables
s3 = boto3.client("s3")

origin = os.getenv("ORIGIN")

def generate_presigned_url(bucket_name, object_key, expiration=300):  # 5 minutes expiration
    """
    Generate a presigned URL for downloading an S3 object.
    """
    try:
        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": bucket_name, "Key": object_key},
            ExpiresIn=expiration
        )
        return url
    except Exception as e:
        print(f"Error generating presigned URL: {e}")
        return None

def lambda_handler(event, context):
    try:
        # Parse request body
        print("Event : ", event, flush = true)
        query_params = event.get("queryStringParameters", {}) or {}  # Handles None case
        file_id = query_params.get("file_id")

        if not file_id:
            return {"statusCode": 400, "body": json.dumps({"error": "Missing file_id"})}

        # Generate a presigned URL for the requested file
        presigned_url = generate_presigned_url(S3_BUCKET, file_id)

        if not presigned_url:
            return {"statusCode": 500, "body": json.dumps({"error": "Failed to generate presigned URL"})}

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": origin,  # Modify for security
                "Access-Control-Allow-Methods": "OPTIONS, GET",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
                "Content-Type": "application/json"
            },
            "body": json.dumps({"download_url": presigned_url})
        }

    except Exception as e:
        print(f"Lambda Error: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": "Internal Server Error"})}
