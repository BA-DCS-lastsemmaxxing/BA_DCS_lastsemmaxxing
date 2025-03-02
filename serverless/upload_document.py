import json
import boto3
import base64
import os
from datetime import datetime
from models import *
import uuid
from io import BytesIO
from multipart import MultipartParser

origin = os.getenv("ORIGIN")

# AWS S3 Configuration
S3_BUCKET = os.getenv("S3_BUCKET")  # Ensure this is set in Lambda Environment Variables

# Initialize S3 Client
s3 = boto3.client("s3")

def lambda_handler(event, context):
    if event["httpMethod"] == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": origin,
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": ""
        }
    try:

        # Ensure content-type is multipart/form-data
        content_type = event.get("headers", {}).get("content-type", "")

        if not content_type.startswith("multipart/form-data"):
            return {
                "statusCode": 400, 
                "headers": {
                    "Access-Control-Allow-Origin": origin,
                    "Access-Control-Allow-Methods": "OPTIONS, POST",
                    "Access-Control-Allow-Headers": "Content-Type, Authorization"
                },
                "body": json.dumps({"error": "Invalid content type"})
            }

        # Extract boundary from content-type header
        boundary = content_type.split("boundary=")[-1]
        if not boundary:
            return {
                "statusCode": 400,
                "headers": {
                "Access-Control-Allow-Origin": origin,
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
                },
                "body": json.dumps({"error": "Missing boundary in content type"})
            }

        # Decode the request body (Base64 decoding if necessary)
        body_bytes = base64.b64decode(event["body"]) if event.get("isBase64Encoded", False) else event["body"].encode("utf-8")

        # Parse multipart form-data
        parser = MultipartParser(BytesIO(body_bytes), boundary.encode("utf-8"))

        for part in parser:

            if part.name == "files":  # Match the field name in FormData
                file_name = part.filename  # Extract original filename
                file_bytes = part.file.read()  # Read file content as bytes

                # Generate a unique filename to avoid overwrites
                file_id = f"{uuid.uuid4()}"

                # Upload file to S3
                s3.put_object(
                    Bucket=S3_BUCKET,
                    Key=file_id,
                    Body=file_bytes,
                    ContentType="application/octet-stream"  # Auto-detect file type
                )

            Document.insert_file_record(file_id,file_name)

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": origin,
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": json.dumps({"message": "File(s) uploaded successfully"})
        }

    except Exception as e:
        print(f"Error during file upload: {e}")
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": origin,
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": json.dumps({"error": "Internal Server Error"})
        }

