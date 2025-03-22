import json
import boto3
from botocore.exceptions import ClientError
import logging
from models import *

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
BUCKET_NAME = 'lsm-fyp-document-storage'  # Replace with your S3 bucket name

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}") # logs the event

    try:
        doc_id = event['queryStringParameters']['docId']
        file_key = f'{doc_id}'

        response = s3_client.delete_object(Bucket=BUCKET_NAME, Key=file_key)

        Document.delete_document(doc_id)
        
        if response.get('ResponseMetadata', {}).get('HTTPStatusCode') == 204:
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': 'https://d1ztk01ovm0zc3.cloudfront.net',  # Replace with your CloudFront domain
                    'Access-Control-Allow-Methods': 'DELETE,OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
                },
                'body': json.dumps({
                    'message': f'Document {doc_id} deleted successfully.'
                })
            }
        else:
            return {
                'statusCode': 404,
                'headers': {
                    'Access-Control-Allow-Origin': 'https://d1ztk01ovm0zc3.cloudfront.net', # Replace with your CloudFront domain
                    'Access-Control-Allow-Methods': 'DELETE,OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
                },
                'body': json.dumps({
                    'error': f'Document {doc_id} not found.'
                })
            }

    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            return {
                'statusCode': 404,
                'headers': {
                    'Access-Control-Allow-Origin': 'https://d1ztk01ovm0zc3.cloudfront.net', # Replace with your CloudFront domain
                    'Access-Control-Allow-Methods': 'DELETE,OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
                },
                'body': json.dumps({
                    'error': f'Document {doc_id} not found in S3.'
                })
            }
        logger.error(f"Error deleting document: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': 'https://d1ztk01ovm0zc3.cloudfront.net', # Replace with your CloudFront domain
                'Access-Control-Allow-Methods': 'DELETE,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
            },
            'body': json.dumps({
                'error': 'Failed to delete the document from S3.'
            })
        }
    except KeyError as e:
        logger.error(f"KeyError: {e}")
        return {
            'statusCode': 400,
            'headers': {
                'Access-Control-Allow-Origin': 'https://d1ztk01ovm0zc3.cloudfront.net', # Replace with your CloudFront domain
                'Access-Control-Allow-Methods': 'DELETE,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
            },
            'body': json.dumps({
                'error': 'Missing document ID in request.'
            })
        }
    except Exception as e: # Catch any other exception that may happen.
        logger.error(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'headers':{
                'Access-Control-Allow-Origin': 'https://d1ztk01ovm0zc3.cloudfront.net', # Replace with your CloudFront domain
                'Access-Control-Allow-Methods': 'DELETE,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
            },
            'body': json.dumps({'error': 'An unexpected error occured'})
        }