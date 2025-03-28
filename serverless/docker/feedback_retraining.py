import json, traceback
from models import Document, ModelState, local_tz
from machine_learning import *
import datetime

def lambda_handler(event, context):
    try:
        print("Feedback retraining triggered")
        print("Event: ", event, flush=True)
        state = ModelState.get_state()
        print("Model state: ", state)
        if state["isRetraining"]:
            return {
                "statusCode": 400,
                "headers": { 
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "OPTIONS, GET, POST, PUT, DELETE",
                    "Access-Control-Allow-Headers": "Content-Type, Authorization"
                },
                "body": json.dumps({"message": "Model is undergoing training, aborting feedback retraining request..."})
            }
        ModelState.update_state({
            "isRetraining": True,
            "startedAt": datetime.datetime.now(local_tz).isoformat(),
            "type": "Feedback Retraining"
        })
        record = event.get("Records")[0]
        body = json.loads(record.get("body"))
        documents_to_retrain = body.get("documents")
        modelManager.retrain_with_feedback(documents_to_retrain, documentProcessor)

        for doc in documents_to_retrain:
            Document.correct_file_topic(doc["id"], doc["user_corrected_category"], doc["feedback"])
        ModelState.update_state({"isRetraining": False})
    except Exception as e: 
        print("lambda handler failed with exception: " + str(e),flush=True)
        traceback.print_exc()
        ModelState.update_state({"isRetraining": False})
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

