import json
from models import Document  # Import the shared models.py

def lambda_handler(event, context):
    
    # Extract query parameter
    query = event.get("queryStringParameters", {}).get("query", None)
    
    print(f"Query: {query}", flush=True)

    # Fetch documents from database
    documents = Document.get_documents(query)
    print("documents: ", documents, flush=True)
    # Return a valid API Gateway response
    return {
        "statusCode": 200,
        "headers": { "Content-Type": "application/json" },
        "body": json.dumps(documents)
    }
