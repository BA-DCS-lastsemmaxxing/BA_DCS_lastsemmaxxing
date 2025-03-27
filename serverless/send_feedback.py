import json
import mysql.connector
import os
from models import Document

def lambda_handler(event, context):
    print("Send feedback lambda triggered")
    print("Event: ", event)
    # Extract query parameters (document_id)
    document_id = event.get('queryStringParameters', {}).get('document_id')
    body = json.loads(event.get("body"))
    corrected_topic = body.get("corrected_topic")
    feedback = body.get("feedback")
    print("Doc id: ", document_id)
    print("body: ", body)
    Document.add_feedback(document_id, corrected_topic, feedback)

    # Return a valid API Gateway response
    return {
        "statusCode": 200,
        "headers": { 
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS, GET, POST, PUT, DELETE",
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
    }
    
