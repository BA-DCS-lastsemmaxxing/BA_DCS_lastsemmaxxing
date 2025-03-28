import json, traceback
from models import Document, Topic
from machine_learning import *

def lambda_handler(event, context):
    try:
        print("Feedback retraining triggered")
        print("Event: ", event, flush=True)
        record = event.get("Records")[0]
        body = json.loads(record.get("body"))
        documents_to_retrain = body.get("documents")
        modelManager.retrain_with_feedback(documents_to_retrain, documentProcessor)

        for doc in documents_to_retrain:
            Document.correct_file_topic(doc["id"], doc["corrected_topic"], doc["feedback"])

    except Exception as e: 
        print("lambda handler failed with exception: " + str(e),flush=True)
        traceback.print_exc()

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

