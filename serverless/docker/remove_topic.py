import json, traceback, datetime
from models import ModelState, Topic
from machine_learning import *

def lambda_handler(event, context):
    try:
        print("Remove topic triggered")
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
                "body": json.dumps({"message": "Model is undergoing training, aborting remove topic request..."})
            }
        ModelState.update_state({
            "isRetraining": True,
            "startedAt": datetime.datetime.now().isoformat(),
            "type": "Removing Topic"
        })
        record = event.get("Records")[0]
        record = event.get("Records")[0]
        body = json.loads(record.get("body"))
        topic_to_remove = body.get("topic")
        Topic.update_topic_status(topic_to_remove, "Pending")
        modelManager.remove_topic(topic_to_remove)
        Topic.delete_topic(topic_to_remove)
        ModelState.update_state({"isRetraining": False})
    except Exception as e: 
        print("lambda handler failed with exception: " + str(e),flush=True)
        traceback.print_exc()
        Topic.update_topic_status(topic_to_remove, "Completed")
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

