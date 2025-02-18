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
    summary, classification = evaluate_saved_file()
    Document.update_file_classification(file_id, summary, classification)
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

def extract_final_topic(response_text):
    """
    Extracts the final topic from the model's response using regex.
    Ensures that we capture the topic stated explicitly at the end.
    """
    match = re.search(r"Final Topic:\s*(.+)", response_text, re.IGNORECASE)
    if match:
        return match.group(1).strip()
    
    # If no clear label is found, fall back to the last line
    lines = response_text.strip().split("\n")
    return lines[-1].strip() if lines else "unknown"

def evaluate_topic_with_llama(file_content):
    """Classify the text using AWS Bedrock (Meta's Llama 3.3 70B Instruct) with an explanation."""
    try:
        prompt = f"""
        Analyze the following document in depth and determine which topic it belongs to from the given list: {unique_topics_str}. 
        Provide a justification first, then explicitly state the final topic in the format below:

        Explanation: <Your explanation>
        Final Topic: <One of the topics from the list>

        Text:
        {file_content}

        Final classification:
        """

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
        response_text = response_body.get("generation", "").strip()

        if not response_text:
            print("Empty response from AWS Bedrock Llama, defaulting to unknown.")
            return "unknown", "unknown"

        predicted_topic = extract_final_topic(response_text)
        return response_text, predicted_topic  # Return both full response and extracted topic
    
    except Exception as e:
        print(f"Error calling AWS Bedrock API: {e}")
        return "unknown", "unknown"

def evaluate_saved_file():
    """Loads metadata, reads file content, and evaluates it with explanation."""
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
            explanation, predicted_topic = evaluate_topic_with_llama(text_content)
            explanation = explanation.strip("Explanation: ").split("Final Topic")[0]
            print(f"Explanation: {explanation}\nPredicted Topic: {predicted_topic}")
            return explanation, predicted_topic
            
        else:
            print("Error: No content found in the file.")

    except FileNotFoundError:
        print("Error: No processed file metadata found. Run `upload_pdf.py` first.")
    except Exception as e:
        print(f"Unexpected error: {e}")


# Run the evaluation
evaluate_saved_file()