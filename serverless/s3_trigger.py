import json
import boto3
import os

sfn_client = boto3.client("stepfunctions")

def lambda_handler(event, context):
    print("Received S3 event:", json.dumps(event))
    
    # Extract bucket name and object key
    bucket_name = event["Records"][0]["s3"]["bucket"]["name"]
    object_key = event["Records"][0]["s3"]["object"]["key"]

    # Start Step Function
    response = sfn_client.start_execution(
        stateMachineArn=os.environ["STEP_FUNCTION_ARN"],
        input=json.dumps({
            "bucket": bucket_name,
            "key": object_key
        })
    )

    return {"statusCode": 200, "body": "Step Function started"}
