import os
from models import Document
from machine_learning import *

def lambda_handler(event, context):
    print("Document classification triggered")
    print("Event: ", event, flush=True)
    body = event.get("body")
    filename = body.get("file_name")
    file_id = body.get("file_id")
    print('body: ', body, flush=True)
    print('filename: ', filename, flush=True)
    print('file id: ', file_id, flush=True)
    response = s3_client.get_object(Bucket=bucket_name, Key=file_id)
    file_content = response["Body"].read()
    DocumentProcessor.preprocess_pdf(file_content,filename)
    pickle_path = "/tmp/processed_file.pkl"
    if not os.path.exists(pickle_path):
        raise FileNotFoundError(f"Error: Pickle file not found at {pickle_path}. Something went wrong in `preprocess_pdf()`.")
    filename, classification, confidence, summary, source = ModelManager.classify_document()
    print("filename: ", filename)
    print("classification: ", classification)
    print("confidence: ", confidence)
    print("summary: ", summary)
    print("source: ", source)
    
    Document.update_file_classification(file_id, summary if summary != "-" else None, classification, float(confidence) if confidence != "-" else None)
    return

