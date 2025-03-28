import json, traceback, datetime
from models import ModelState, Topic, local_tz
from machine_learning import *

def lambda_handler(event, context):
    try:
        print("Add new topic triggered")
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
                "body": json.dumps({"message": "Model is undergoing training, aborting new topic request..."})
            }
        ModelState.update_state({
            "isRetraining": True,
            "startedAt": datetime.datetime.now(local_tz).isoformat(),
            "type": "Adding New Topic"
        })
        record = event.get("Records")[0]
        record = event["Records"][0]
        body = json.loads(record["body"])
        file_info = body.get("files")
        new_topic = body.get("topic")
        files = []
        for f in file_info:
            response = s3_client.get_object(Bucket=bucket_name, Key=f["file_id"])
            file_content = response["Body"].read()
            files.append({"file_content": file_content, "file_name": f["file_name"]})
        Topic.insert_topic(new_topic)
        modelManager.add_new_topic(new_topic,files, documentProcessor)
        Topic.update_topic_status(new_topic, "Completed")
        ModelState.update_state({"isRetraining": False})
    except Exception as e: 
        print("lambda handler failed with exception: " + str(e),flush=True)
        traceback.print_exc()
        print("Deleting topic from RDS (Rollback)...")
        try:
            Topic.delete_topic(new_topic)
        except Exception as e:
            print("Error deleting topic from RDS: " + str(e))
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

