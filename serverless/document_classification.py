import json

def lambda_handler(event, context):
    print("Document classification triggered")

    return {"statusCode": 200, "body": "Document classification triggered"}
