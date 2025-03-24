import json
from models import Document, Topic
from machine_learning import *

def lambda_handler(event, context):
    try:
        print("Add new topic triggered")
        print("Event: ", event, flush=True)
        record = event["Records"][0]
        body = json.loads(record["body"])
        file_info = body.get("files")
        new_topic = body.get("topic")
        files = []
        for f in file_info:
            response = s3_client.get_object(Bucket=bucket_name, Key=f["file_id"])
            file_content = response["Body"].read()
            files.append({"file_content": file_content, "file_name": f["file_name"]})

        modelManager.add_new_topic(new_topic,files, documentProcessor)
        Topic.insert_topic(new_topic)
    except Exception as e: 
        print("lambda handler failed with exception: " + e,flush=True)
        return {
        "statusCode": 500,
        "headers": { 
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS, GET, POST, PUT, DELETE",
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
    }

    return {
        "statusCode": 200,
        "headers": { 
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS, GET, POST, PUT, DELETE",
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
    }

