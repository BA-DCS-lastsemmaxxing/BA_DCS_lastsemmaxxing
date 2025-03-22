import os
from models import Document, Topic
from machine_learning import *

def lambda_handler(event, context):
    print("Add new topic triggered")
    print("Event: ", event, flush=True)
    body = event.get("body")
    file_info = body.get("files")
    new_topic = body.get("topic")
    files = []
    for f in file_info:
        response = s3_client.get_object(Bucket=bucket_name, Key=f["file_id"])
        file_content = response["Body"].read()
        files.append({"file_content": file_content, "file_name": f["file_name"]})

    ModelManager.add_new_topic(new_topic,files, DocumentProcessor())
    Topic.insert_topic(new_topic)
    
    return {
        "statusCode": 200,
        "headers": { 
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS, GET, POST, PUT, DELETE",
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
    }

