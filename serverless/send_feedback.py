import json
import mysql.connector
import os

def lambda_handler(event, context):
    try:
        # Extract query parameters (document_id)
        document_id = event.get('queryStringParameters', {}).get('document_id')
        
        if not document_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing document ID'}),
                'headers': {'Access-Control-Allow-Origin': '*'}
            }

        # Extract body (user_corrected_category and feedback)
        body = json.loads(event['body'])
        user_corrected_category = body.get('user_corrected_category')
        feedback = body.get('feedback')

        if not user_corrected_category or not feedback:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required fields'}),
                'headers': {'Access-Control-Allow-Origin': '*'}
            }

        # Forward the request to the Flask backend API
        response = requests.post(
            FLASK_BACKEND_URL,
            params={'document_id': document_id},
            json={'user_corrected_category': user_corrected_category, 'feedback': feedback},
            headers={
                'Authorization': event.get('headers', {}).get('Authorization', '')
            }
        )

        # Process the response from Flask backend
        if response.status_code == 200:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Feedback successfully submitted.'}),
                'headers': {'Access-Control-Allow-Origin': '*'}
            }
        else:
            return {
                'statusCode': response.status_code,
                'body': json.dumps({'error': response.json().get('error', 'Failed to submit feedback')}),
                'headers': {'Access-Control-Allow-Origin': '*'}
            }

    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error'}),
            'headers': {'Access-Control-Allow-Origin': '*'}
        }
