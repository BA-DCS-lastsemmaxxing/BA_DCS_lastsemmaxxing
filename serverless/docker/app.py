import os, re, io, pickle, json, random, math, boto3, joblib
from pypdf import PdfReader
from nltk.corpus import stopwords
import pandas as pd
from botocore.config import Config
from models import Document

# AWS credentials
aws_region = os.environ.get("REGION")

# AWS Bedrock model configuration
MODEL_ID_LLAMA = "arn:aws:bedrock:us-west-2:874280117166:inference-profile/us.meta.llama3-3-70b-instruct-v1:0"

# Prevent Bedrock timeout
config = Config(read_timeout=1000)

bedrock_client = boto3.client(
    "bedrock-runtime",
    region_name='us-west-2',
    config=config
)

s3_client = boto3.client('s3')
bucket_name = os.environ.get("S3_BUCKET")

# Load topic mappings
mapping_file_path = 'final_file_topic_mapping.csv'
file_topic_mapping = pd.read_csv(mapping_file_path)
unique_topics = file_topic_mapping['folder_name'].unique().tolist()
unique_topics_str = ', '.join(unique_topics)

#  Load Trained Model & Vectorizer** 
print(" Loading Trained TF-IDF Vectorizer and Random Forest Model...")
tfidf_vectorizer = joblib.load("tfidf_vectorizer.pkl")
rf_model = joblib.load("rf_model.pkl")

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
    preprocess_pdf(file_content,filename)
    pickle_path = "/tmp/processed_file.pkl"
    if not os.path.exists(pickle_path):
        raise FileNotFoundError(f"Error: Pickle file not found at {pickle_path}. Something went wrong in `preprocess_pdf()`.")
    filename, classification, confidence, summary, source = process_single_file()
    print("filename: ", filename)
    print("classification: ", classification)
    print("confidence: ", confidence)
    print("summary: ", summary)
    print("source: ", source)
    
    Document.update_file_classification(file_id, summary if summary != "-" else None, classification, confidence if confidence != "-" else None)
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
        output_dir = "/tmp/output_data"
        os.makedirs(output_dir, exist_ok=True)  # Ensure the directory exists
        output_path = os.path.join(output_dir, f"{filename}.txt")
        with open(output_path, "w", encoding="utf-8") as text_file:
            text_file.write(cleaned_text)

        print(f"Processed text saved to: {output_path}")
        print(f"Preview:\n{cleaned_text[:500]}...")  # Print first 500 chars

        # Save metadata for second script
        metadata = {
            "filename": filename,
            "file_path": output_path
        }
        pickle_path = "/tmp/processed_file.pkl"  # Use /tmp for Lambda compatibility
        with open(pickle_path, "wb") as f:
            pickle.dump(metadata, f)

        print(f"Metadata saved to: {pickle_path}")

    except Exception as e:
        print(f"Error processing PDF: {e}")

#  Random Forest Classification** 
def rf_classify_document(text, confidence_threshold=0.99):
    """Classifies a document using the trained Random Forest model."""
    text_tfidf = tfidf_vectorizer.transform([text])  # Convert text to TF-IDF features
    y_pred_proba = rf_model.predict_proba(text_tfidf)[0]  # Get probability scores
    
    max_prob = max(y_pred_proba)
    predicted_topic = rf_model.classes_[y_pred_proba.argmax()]

    if predicted_topic == "Financial Regulations":
        return None, max_prob  # Defer to LLM for Financial Regulations

    if max_prob < confidence_threshold:
        return None, max_prob  # Defer to LLM

    return predicted_topic, max_prob

#  Sampling Logic for Hybrid Text Extraction (Intro, Middle Sample, Conclusion)
def extract_intro_middle_conclusion(text, max_tokens=20000):
    words = text.split()
    total_words = len(words)

    if total_words < 5000:
        ratios = (0.15, 0.15, 0.15)
    elif total_words < 20000:
        ratios = (0.08, 0.12, 0.08)
    elif total_words < 50000:
        ratios = (0.04, 0.08, 0.04)
    else:
        ratios = (0.02, 0.06, 0.02)

    intro_end = max(int(total_words * ratios[0]), 100)
    conclusion_start = max(int(total_words * (1 - ratios[2])), total_words - 100)

    middle = words[intro_end:conclusion_start]
    middle_sample_size = int(len(middle) * ratios[1])
    middle_sample = random.sample(middle, min(middle_sample_size, len(middle)))

    hybrid_text_words = words[:intro_end] + middle_sample + words[conclusion_start:]
    estimated_tokens = len(hybrid_text_words) * 1.3

    if estimated_tokens > max_tokens:
        allowed_words = int(max_tokens / 1.3)
        hybrid_text_words = hybrid_text_words[:allowed_words]

    return " ".join(hybrid_text_words)

#  LLM Fallback (Uses Sampled Text)
def evaluate_topic_with_llama(file_content):
    try:
        prompt = f"""
        Analyze the following document sample and classify it into only one of these topics: {unique_topics_str}.
        After explaining your reasoning, clearly state the final topic at the end.

        Document:
        {file_content}

        Explanation:
        Final Topic:
        """

        formatted_prompt = f"""
        <|begin_of_text|>
        <|start_header_id|>user<|end_header_id|>
        {prompt}
        <|eot_id|>
        <|start_header_id|>assistant<|end_header_id|>
        """

        response = bedrock_client.invoke_model(
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

        match = re.search(r"Final Topic:\s*(.+)", response_text, re.IGNORECASE)
        predicted_topic = match.group(1).strip() if match else "Unknown"

        return predicted_topic, response_text

    except Exception as e:
        print(f"Error calling AWS Bedrock API: {e}")
        return "Unknown", "Error occurred during LLM call"

#  Main Pipeline (Single File Upload)
def process_single_file():
    pickle_path = "/tmp/processed_file.pkl"  # Use /tmp for Lambda

    with open(pickle_path, "rb") as f:
        metadata = pickle.load(f)

    file_path = os.path.join("/tmp/output_data", metadata["filename"] + ".txt")

    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Cleaned text file not found at {file_path}")

    filename = metadata["filename"]

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    sampled_text = extract_intro_middle_conclusion(content)
    predicted_topic, confidence = rf_classify_document(sampled_text)

    if predicted_topic:
        print(f" Random Forest Classification: {predicted_topic} (Confidence: {confidence:.2f})")
        return filename, predicted_topic, confidence, "-", "Random Forest Rule-Based Classification"

    # Fallback to LLM using Sampled Text (Hybrid)
    predicted_topic, explanation = evaluate_topic_with_llama(sampled_text)

    print(f" LLM Classification: {predicted_topic}")
    return filename, predicted_topic, "-", explanation, "LLM"