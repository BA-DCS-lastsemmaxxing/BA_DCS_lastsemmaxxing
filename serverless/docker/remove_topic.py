import json
from models import Document, Topic
from machine_learning import *

def lambda_handler(event, context):
    try:
        print("Remove topic triggered")
        print("Event: ", event, flush=True)
        record = event["Records"][0]
        body = json.loads(record["body"])
        topic_to_remove = body.get("topic")
        Topic.update_topic_status(topic_to_remove, "Pending")
        modelManager.remove_topic(topic_to_remove)
        Topic.delete_topic(topic_to_remove)
    except Exception as e: 
        print("lambda handler failed with exception: " + str(e),flush=True)
        Topic.update_topic_status(topic_to_remove, "Completed")
            
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

