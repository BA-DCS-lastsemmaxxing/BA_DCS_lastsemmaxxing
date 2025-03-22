import json
from models import Topic  # Import the shared models.py

def lambda_handler(event, context):
    # Fetch topics from database
    topics = Topic.get_all_topics()
    print("topics: ", topics, flush=True)
    # Return a valid API Gateway response
    return {
        "statusCode": 200,
        "headers": { 
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS, GET, POST, PUT, DELETE",
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        },
        "body": json.dumps(topics)
    }