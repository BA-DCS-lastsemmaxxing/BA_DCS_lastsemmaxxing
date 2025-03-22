import json
import boto3
import os

s3_client = boto3.client("s3")
sfn_client = boto3.client("stepfunctions")

def lambda_handler(event, context):
    print("Received S3 event:", json.dumps(event))

    # file_name = event["Records"][0]["s3"]["object"]["key"]
    record = event["Records"][0]
    bucket_name = record["s3"]["bucket"]["name"]
    object_key = record["s3"]["object"]["key"]

    # Fetch metadata using `head_object`
    metadata_response = s3_client.head_object(Bucket=bucket_name, Key=object_key)
    metadata = metadata_response.get("Metadata", {})
    print("Metadata:", metadata, flush=True)
    if metadata.get("for-training") == 'true':
        return {"statusCode": 200, "body": "Training document detected, no step function triggered"}

    file_id = record["s3"]["object"]["key"]

    # Start Step Function
    response = sfn_client.start_execution(
        stateMachineArn=os.environ["STEP_FUNCTION_ARN"],
        input=json.dumps({
            "file_id": file_id,
            "file_name": metadata.get("file-name")
        })
    )

    return {"statusCode": 200, "body": "Step Function started"}
