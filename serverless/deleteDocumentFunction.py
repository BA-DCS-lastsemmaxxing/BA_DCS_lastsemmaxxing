import json
import os
import boto3
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')  # Assuming documents are stored in an S3 bucket
BUCKET_NAME = 'fypfilestorage592'  # Replace with your S3 bucket name

def lambda_handler(event, context):
    try:
        # Extract docId from the event
        doc_id = event['queryStringParameters']['docId']
        
        # Construct the file key (assuming it's the same as doc_id)
        file_key = f'{doc_id}'  # Modify if file structure is different

        # Try deleting the document from S3
        response = s3_client.delete_object(Bucket=BUCKET_NAME, Key=file_key)
        
        # If the delete response does not indicate an error, assume success
        if response.get('ResponseMetadata', {}).get('HTTPStatusCode') == 204:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Document {doc_id} deleted successfully.'
                })
            }
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({
                    'error': f'Document {doc_id} not found.'
                })
            }

    except ClientError as e:
        # Check for specific errors like 'NoSuchKey' if file does not exist
        if e.response['Error']['Code'] == 'NoSuchKey':
            return {
                'statusCode': 404,
                'body': json.dumps({
                    'error': f'Document {doc_id} not found in S3.'
                })
            }
        print(f"Error deleting document: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to delete the document from S3.'
            })
        }
    except KeyError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Missing document ID in request.'
            })
        }
