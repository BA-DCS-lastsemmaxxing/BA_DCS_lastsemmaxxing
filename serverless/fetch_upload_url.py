import json
import boto3
import os
import uuid

s3 = boto3.client("s3")
S3_BUCKET = os.getenv("S3_BUCKET")

def lambda_handler(event, context):
    query_params = event.get("queryStringParameters", {})
    file_type = query_params.get("file_type")
    try:
        # Generate a unique filename
        file_id = f"{uuid.uuid4()}"

        # Generate a presigned URL for S3 upload
        presigned_url = s3.generate_presigned_url(
            "put_object",
            Params={"Bucket": S3_BUCKET, "Key": file_id, "ContentType": file_type},
            ExpiresIn=3600  # URL expires in 1 hour
        )

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": json.dumps({"upload_url": presigned_url, "file_id": file_id})
        }

    except Exception as e:
        print(f"Error generating presigned URL: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal Server Error"})
        }
