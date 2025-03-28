import json
from models import Topic, ModelState  # Import the shared models.py

def lambda_handler(event, context):
    state = ModelState.get_state()
    print("State: ", state)
    body = {}
    if state["isRetraining"]:
        body["state"] = state
    else:
        # Fetch topics from database
        topics = Topic.get_all_topics()
        print("topics: ", topics, flush=True)
        body["topics"] = topics
    # Return a valid API Gateway response
    return {
        "statusCode": 200,
        "headers": { 
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS, GET, POST, PUT, DELETE",
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        },
        "body": json.dumps(body)
    }