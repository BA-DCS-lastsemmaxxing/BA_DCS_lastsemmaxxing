import json
from models import Document  # Import the shared models.py

def lambda_handler(event, context):
    # Fetch corrected documents
    documents = Document.get_corrected_documents()
    # Return a valid API Gateway response
    return {
        "statusCode": 200,
        "headers": { 
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "OPTIONS, GET, POST, PUT, DELETE",
            "Access-Control-Allow-Headers": "Content-Type, Authorization"
        },
        "body": json.dumps(documents)
    }