import json
from models import *

def lambda_handler(event, context):

    try:
        body = json.loads(event["body"]) if "body" in event and event["body"] else {}
        file_id = body.get("file_id")
        file_name = body.get("file_name")
        Document.insert_file_record(file_id,file_name)

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": json.dumps({"message": "File(s) uploaded successfully"})
        }

    except Exception as e:
        print(f"Error during document record insertion in RDS: {e}")
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": json.dumps({"error": "Internal Server Error"})
        }

