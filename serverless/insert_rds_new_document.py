import json
from models import *

def lambda_handler(event, context):

    try:
        print("Event: ", event, flush=True)
        file_id = event.get("file_id")
        file_name = event.get("file_name")
        Document.insert_file_record(file_id,file_name)

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": {
                "message": "File(s) uploaded successfully",
                "file_id": file_id,
                "file_name": file_name
            }
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

