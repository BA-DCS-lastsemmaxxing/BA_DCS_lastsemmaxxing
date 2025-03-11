import os, re, io, pickle, json, random, math, boto3
from pypdf import PdfReader
from nltk.corpus import stopwords
import pandas as pd
from botocore.config import Config
from sklearn.feature_extraction.text import CountVectorizer
from models import Document

# AWS credentials
aws_region = os.environ.get("REGION")

# AWS Bedrock model configuration
MODEL_ID_LLAMA = "arn:aws:bedrock:us-west-2:874280117166:inference-profile/us.meta.llama3-3-70b-instruct-v1:0"

# Prevent Bedrock timeout
config = Config(read_timeout=1000)

bedrock_client = boto3.client(
    "bedrock-runtime",
    region_name=aws_region,
    config=config
)

s3_client = boto3.client('s3')
bucket_name = os.environ.get("S3_BUCKET")

# Load topic mappings
mapping_file_path = 'final_file_topic_mapping.csv'
file_topic_mapping = pd.read_csv(mapping_file_path)
unique_topics = file_topic_mapping['folder_name'].unique().tolist()
unique_topics_str = ', '.join(unique_topics)

#  Load Keyword Data for Rule-Based Classification
top_keywords_per_topic = {}
main_topics = set()

def lambda_handler(event, context):
    print("Document classification triggered")
    print("Event: ", event, flush=True)
    body = event.get("body")
    filename = event.get("file_name")
    file_id = event.get("file_id")
    response = s3_client.get_object(Bucket=bucket_name, Key=file_id)
    file_content = response["Body"].read()
    preprocess_pdf(file_content,filename)
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



df = pd.read_csv("refined_tfidf_bigrams.csv")
for index, row in df.iterrows():
    topic_name = row.iloc[0].strip()
    keywords = [row[col] for col in df.columns[1:] if pd.notna(row[col])]
    if keywords:
        top_keywords_per_topic[topic_name] = keywords[:150]
        main_topics.add(topic_name.split("/")[0])

#  Tokenization (For Rule-Based Classifier)
vectorizer = CountVectorizer(
    stop_words="english",
    lowercase=True,
    token_pattern=r"(?u)\b\w+\b",
    ngram_range=(1, 2)
)

def fast_tokenize(text):
    return set(vectorizer.build_analyzer()(text))

#  Length Penalty
def apply_length_penalty(score, doc_length):
    return score / (1 + math.log(1 + doc_length) / 70)

#  Rule-Based Classification
def classify_document(text):
    doc_words = fast_tokenize(text)
    doc_length = len(doc_words)

    if doc_length < 100:
        return None, 0.0  # Skip classification if document too short

    best_match, best_score = None, 0
    for topic in main_topics:
        topic_keywords = set(word for subtopic in top_keywords_per_topic if subtopic.startswith(topic) for word in top_keywords_per_topic[subtopic])
        matched_words = doc_words.intersection(topic_keywords)

        weighted_score = sum(1.0 * (0.85 ** idx) for idx, word in enumerate(matched_words))
        max_possible_score = sum(1.0 * (0.85 ** idx) for idx in range(len(topic_keywords)))
        normalized_score = weighted_score / max_possible_score if max_possible_score > 0 else 0

        adjusted_score = apply_length_penalty(normalized_score, doc_length)

        if adjusted_score > best_score and len(matched_words) >= 30:
            best_score = adjusted_score
            best_match = topic

    if best_score < 0.9:
        return None, best_score  # Low confidence → No classification (fall back to LLM)

    return best_match, best_score

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
    with open("processed_file.pkl", "rb") as f:
        metadata = pickle.load(f)

    file_path = metadata["file_path"]
    filename = metadata["filename"]

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Rule-Based Attempt
    predicted_topic, confidence = classify_document(content)

    if predicted_topic:
        print(f" Rule-Based Classification: {predicted_topic} (Confidence: {confidence:.2f})")
        return filename, predicted_topic, confidence, "-", "Rule-Based"

    # Fallback to LLM using Sampled Text (Hybrid)
    sampled_text = extract_intro_middle_conclusion(content)
    predicted_topic, explanation = evaluate_topic_with_llama(sampled_text)

    print(f" LLM Classification: {predicted_topic}")
    return filename, predicted_topic, "-", explanation, "LLM"