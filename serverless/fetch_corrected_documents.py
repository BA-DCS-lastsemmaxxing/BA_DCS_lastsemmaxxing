import json
from models import Document, ModelState # Import the shared models.py

def lambda_handler(event, context):
    state = ModelState.get_state()
    print("State: ", state)
    body = {}
    if state["isRetraining"]:
        body["state"] = state
    else:
        # Fetch corrected documents
        documents = Document.get_corrected_documents()
        body["documents"] = documents
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