import os
import re
import io
import ipywidgets as widgets
from IPython.display import display
from pypdf import PdfReader
from nltk.corpus import stopwords
import pickle
import json
import pandas as pd
import boto3
from botocore.config import Config
from dotenv import load_dotenv
from models import Document
load_dotenv(".env")

# AWS credentials
aws_access_key = os.environ.get("AWS_ACCESS_KEY_ID")
aws_secret_key = os.environ.get("AWS_SECRET_ACCESS_KEY")
aws_region = os.environ.get("AWS_REGION")

# AWS Bedrock model configuration
MODEL_ID_LLAMA = "arn:aws:bedrock:us-west-2:874280117166:inference-profile/us.meta.llama3-3-70b-instruct-v1:0"

# Prevent Bedrock timeout
config = Config(read_timeout=1000)

client = boto3.client(
    "bedrock-runtime",
    region_name=aws_region,
    aws_access_key_id=aws_access_key,
    aws_secret_access_key=aws_secret_key,
    config=config
)

# Load topic mappings
mapping_file_path = 'final_file_topic_mapping.csv'
file_topic_mapping = pd.read_csv(mapping_file_path)
unique_topics = file_topic_mapping['folder_name'].unique().tolist()
unique_topics_str = ', '.join(unique_topics)

def classify(file_content,filename, file_id):
    preprocess_pdf(file_content,filename)
    result = [evaluate_saved_file()]
    Document.update_file_classification(file_id, result)
    return

def clean_text(text):
    """
    Clean text by removing unwanted characters and formatting.
    """
    text = re.sub(r'[^\x00-\x7F]+', ' ', text)  # Remove non-ASCII characters
    text = re.sub(r'http\S+', '', text)  # Remove URLs
    text = re.sub(r'[^a-zA-Z\s]', '', text)  # Remove special characters and numbers
    text = text.lower()  # Convert to lowercase
    text = re.sub(r'\s+', ' ', text).strip()  # Remove extra whitespace
    text = re.sub(r'\n+', '\n', text)  # Remove extra newlines
    return text


def remove_stop_words(text):
    stop_words = set(stopwords.words('english'))
    words = text.split()
    filtered_words = [word for word in words if word not in stop_words]
    return ' '.join(filtered_words)


def preprocess_pdf(file_content, filename):
    """Extract and preprocess text from uploaded PDF file."""
    try:
        # Convert memoryview to BytesIO
        pdf_stream = io.BytesIO(file_content)

        reader = PdfReader(pdf_stream)
        extracted_text = ""
        for page in reader.pages:
            text = page.extract_text()
            if text:
                extracted_text += text + "\n"

        cleaned_text = clean_text(extracted_text)
        cleaned_text = remove_stop_words(cleaned_text)

        # Save cleaned text to file
        output_path = os.path.join(os.getcwd(), "output_data", f"{filename}.txt")
        with open(output_path, "w", encoding="utf-8") as text_file:
            text_file.write(cleaned_text)

        print(f"Processed text saved to: {output_path}")
        print(f"Preview:\n{cleaned_text[:500]}...")  # Print first 500 chars

        # Save metadata for second script
        metadata = {
            "filename": filename,
            "file_path": output_path
        }
        with open("processed_file.pkl", "wb") as f:
            pickle.dump(metadata, f)

        print("Metadata saved for evaluation script.")

    except Exception as e:
        print(f"Error processing PDF: {e}")





def read_txt_file(file_path):
    """Reads the content of a .txt file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            return file.read()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return None


def map_to_category(predicted_output):
    """Maps the model's output to a known category."""
    predicted_output = predicted_output.lower().strip()
    for topic in unique_topics:
        if topic.lower() in predicted_output:
            return topic
    return "unknown"


def evaluate_topic_with_llama(file_content):
    """Classify the text using AWS Bedrock (Meta's Llama 3.3 70B Instruct)."""
    try:
        prompt = f"Classify the following text into only one of these topics: {unique_topics_str}. \n{file_content}"
        formatted_prompt = f"""
            <|begin_of_text|>
            <|start_header_id|>user<|end_header_id|>
            {prompt}
            <|eot_id|>
            <|start_header_id|>assistant<|end_header_id|>
            """

        response = client.invoke_model(
            modelId=MODEL_ID_LLAMA,
            body=json.dumps({
                "prompt": formatted_prompt,
                "max_gen_len": 512,
                "temperature": 0,
            }),
            contentType="application/json"
        )
        response_body = json.loads(response['body'].read())
        predicted_topic = response_body.get("generation", "").strip()
        
        if not predicted_topic:
            print("Empty response from AWS Bedrock Llama, defaulting to unknown.")

        return map_to_category(predicted_topic)

    except Exception as e:
        print(f"Error calling AWS Bedrock API: {e}")
        return "unknown"


def evaluate_saved_file():
    """Loads metadata, reads file content, and evaluates it."""
    try:
        # Load metadata
        with open("processed_file.pkl", "rb") as f:
            metadata = pickle.load(f)

        filename = metadata["filename"]
        file_path = metadata["file_path"]

        print(f"Evaluating file: {filename}")

        # Read file content
        text_content = read_txt_file(file_path)
        if text_content:
            predicted_topic = evaluate_topic_with_llama(text_content)
            print(f"Predicted Topic: {predicted_topic}")
            return predicted_topic
        else:
            print("Error: No content found in the file.")

    except FileNotFoundError:
        print("Error: No processed file metadata found. Run `upload_pdf.py` first.")
    except Exception as e:
        print(f"Unexpected error: {e}")


# Run the evaluation
evaluate_saved_file()