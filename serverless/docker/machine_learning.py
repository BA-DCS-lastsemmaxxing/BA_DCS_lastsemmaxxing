import os
import re
import io
import json
import random
import shutil
import pandas as pd
import joblib
import boto3
from pypdf import PdfReader
from nltk.corpus import stopwords
from botocore.config import Config
from joblib import parallel_backend
from scipy.sparse import vstack
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.calibration import CalibratedClassifierCV
from imblearn.over_sampling import SMOTE
from imblearn.combine import SMOTEENN

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
model_bucket = "lsm-fyp-serverless-ap"

# =============================================================================
# 1. Document Processing Utilities
# =============================================================================

class DocumentProcessor:
    """Utility class for cleaning and preprocessing PDF documents."""
    
    @staticmethod
    def clean_text(text: str) -> str:
        """
        Clean text by removing non-ASCII characters, URLs, special characters,
        converting to lowercase, and normalizing whitespace.
        """
        text = re.sub(r'[^\x00-\x7F]+', ' ', text)  # Remove non-ASCII characters
        text = re.sub(r'http\S+', '', text)           # Remove URLs
        text = re.sub(r'[^a-zA-Z\s]', '', text)        # Remove special characters and numbers
        text = text.lower()                           # Convert to lowercase
        text = re.sub(r'\s+', ' ', text).strip()       # Normalize whitespace
        text = re.sub(r'\n+', '\n', text)              # Normalize newlines
        return text

    @staticmethod
    def remove_stop_words(text: str) -> str:
        """
        Remove stop words from text using NLTK's English stop word list.
        """
        stop_words = set(stopwords.words('english'))
        words = text.split()
        filtered_words = [word for word in words if word not in stop_words]
        return ' '.join(filtered_words)

    @staticmethod
    def preprocess_pdf(file_content: bytes, filename: str) -> (str, str):
        """
        Extract text from the PDF, clean it, remove stop words,
        and save the cleaned text.
        Returns a tuple of the output file path and the cleaned text.
        """
        try:
            pdf_stream = io.BytesIO(file_content)
            reader = PdfReader(pdf_stream)
            extracted_text = ""
            for page in reader.pages:
                text = page.extract_text()
                if text:
                    extracted_text += text + "\n"

            cleaned_text = DocumentProcessor.clean_text(extracted_text)
            cleaned_text = DocumentProcessor.remove_stop_words(cleaned_text)

            # Save cleaned text to a .txt file in the current working directory
            
            base_name = os.path.splitext(filename)[0]  # removes .pdf or any other extension
            filename = os.path.join("/tmp", f"{base_name}_extracted.txt")
            with open(filename, "w", encoding="utf-8") as text_file:
                text_file.write(cleaned_text)

            print(f"Processed text saved to: {filename}")
            print(f"Preview:\n{cleaned_text[:500]}...")
            return filename, cleaned_text

        except Exception as e:
            print(f"Error processing PDF: {e}")
            raise


class ModelManager:
    """
    Manages loading/saving of the mapping file and models,
    retraining, and classification.

    This version uses a mapping file named final_file_topic_mapping_v6.csv 
    with two columns:
      - folder_name
      - file_name
    Files are stored in a multi-level folder structure under Extracted_Sample_Data.
    For example, a file with folder_name "Annual Reports" may be found under
      Extracted_Sample_Data/Financial/Annual Reports/
    """
    def __init__(self, mapping_file_path: str = '/tmp/final_file_topic_mapping.csv'):
        self.mapping_file_path = mapping_file_path
        self.vectorizer_path = "/tmp/tfidf_vectorizer.pkl"
        self.model_path = "/tmp/rf_model.pkl"
        self.unique_topics = []
        self.unique_topics_str = ""
        self.load_models()  # load initial models
        self.update_unique_topics()  # load topics from mapping file

    @staticmethod
    def find_folder_recursively(root: str, target: str) -> str:
        """
        Recursively search for a directory named target under the root folder.
        Returns the full path if found; otherwise, returns None.
        """
        for dirpath, dirnames, _ in os.walk(root):
            # Compare folder names case-insensitively
            if os.path.basename(dirpath).lower() == target.lower():
                return dirpath
        return None

    def load_mapping_file(self) -> pd.DataFrame:
        """
        Load the topic mapping CSV file. If not found, return an empty DataFrame.
        Expected columns: file_name, folder_name.
        """
        if not os.path.exists(self.mapping_file_path):
            print("Downloading mapping file from S3...", flush=True)
            s3_client.download_file(model_bucket, "final_file_topic_mapping.csv", self.mapping_file_path)
        return pd.read_csv(self.mapping_file_path)


    def save_mapping_file(self, df: pd.DataFrame) -> None:
        """Save the mapping DataFrame to a CSV file."""
        df.to_csv(self.mapping_file_path, index=False)

    def update_unique_topics(self) -> None:
        """
        Load the mapping file and update the unique topics list and corresponding string.
        """
        df = self.load_mapping_file()
        df = df.dropna(subset=["folder_name"])
        self.unique_topics = df['folder_name'].unique().tolist()
        self.unique_topics_str = ', '.join(self.unique_topics)
        print("Loaded topics:", self.unique_topics_str)

    def update_mapping_paths(self) -> pd.DataFrame:
        """
        Loop through mapping file rows and verify file existence.
        Files are expected to be located in a folder found recursively under Extracted_Sample_Data.
        This function reports any missing files.
        """
        df = self.load_mapping_file()
        for idx, row in df.iterrows():
            folder = row['folder_name']
            file_name = row['file_name']
            folder_path = self.find_folder_recursively("/tmp/Extracted_Sample_Data", folder)
            if folder_path:
                full_path = os.path.join(folder_path, file_name)
            else:
                full_path = os.path.join("/tmp", "Extracted_Sample_Data", folder, file_name)
            if not os.path.exists(full_path):
                print(f"Warning: File not found for row {idx}: {full_path}")
        return df

    def retrain_model(self) -> None:
        """
        Retrain TF-IDF + Random Forest using files downloaded from S3.
        """
        df = self.load_mapping_file()
        df = df.dropna(subset=["folder_name", "file_name"])
        texts = []
        labels = []

        for _, row in df.iterrows():
            print("row info: ", row,flush=True)
            folder = row["folder_name"]
            file_name = os.path.splitext(row["file_name"])[0] + "_extracted.txt"
            s3_key = f"Extracted_Sample_Data/{folder}/{file_name}"
            local_path = f"/tmp/{file_name}"

            try:
                s3_client.download_file(model_bucket, s3_key, local_path)
                with open(local_path, "r", encoding="utf-8") as f:
                    text = f.read()
                texts.append(text)
                labels.append(folder)
            except Exception as e:
                print(f"Error loading training file from S3 ({s3_key}): {e}")

        if not texts:
            print("No training data found. Aborting retraining.")
            return

        # Train model
        X = self.tfidf_vectorizer.fit_transform(texts)
        y = pd.Series(labels)

        # Identify classes with at least two samples
        class_counts = y.value_counts()
        sufficient_samples = class_counts[class_counts >= 2].index.tolist()
        insufficient_samples = class_counts[class_counts < 2].index.tolist()

        # Filter data for SMOTE
        sufficient_mask = y.isin(sufficient_samples)
        sufficient_indices = sufficient_mask.values.nonzero()[0]  # Convert boolean mask to indices
        print("Sufficient_mask: ", sufficient_mask)
        print("sufficient_indices: ", sufficient_indices)
        X_sufficient = X[sufficient_indices]
        y_sufficient = y.iloc[sufficient_indices]

        # Apply SMOTE only to classes with sufficient samples
        smote = SMOTE(random_state=42, k_neighbors=1)
        smote_enn = SMOTEENN(smote=smote, random_state=42)
        X_resampled, y_resampled = smote_enn.fit_resample(X_sufficient, y_sufficient)

        # Combine resampled data with the insufficient samples data
        if insufficient_samples:
            insufficient_indices = (~sufficient_mask.values).nonzero()[0]
            X_insufficient = X[insufficient_indices]
            y_insufficient = y.iloc[insufficient_indices]
            X_resampled = vstack([X_resampled, X_insufficient])
            y_resampled = pd.concat([y_resampled, y_insufficient])


        # Train the random forest classifier
        rf_model = RandomForestClassifier(
            n_estimators=5000, max_depth=30, min_samples_split=2,
            min_samples_leaf=2, class_weight="balanced", random_state=42, n_jobs=-1
        )
        rf_model.fit(X_resampled, y_resampled)

        # Calibrate model
        calibrated_rf = CalibratedClassifierCV(rf_model, method='isotonic', cv='prefit')
        calibrated_rf.fit(X_resampled, y_resampled)

        # Save the retrained model
        joblib.dump(self.tfidf_vectorizer, self.vectorizer_path)
        joblib.dump(calibrated_rf, self.model_path)
        print("Retrained and saved models.")

        s3_client.upload_file(self.model_path, model_bucket, "rf_model.pkl")
        s3_client.upload_file(self.vectorizer_path, model_bucket, "tfidf_vectorizer.pkl")
        print("Uploaded updated models to S3.")

        # Refresh local model state
        self.load_models()

    def add_new_topic(self, topic_name: str, files: list, processor) -> None:
        """
        Process and upload new topic documents, update mapping CSV, and retrain model.
        """
        for file in files:
            # Step 1: Process the PDF
            output_path, _ = processor.preprocess_pdf(file["file_content"], file["file_name"])

            # Step 2: Upload cleaned text to S3
            s3_key = f"Extracted_Sample_Data/{topic_name}/{os.path.basename(output_path)}"
            s3_client.upload_file(output_path, model_bucket, s3_key)
            print(f"Uploaded cleaned file to S3: {s3_key}")

            # Step 3: Update mapping file
            df = self.load_mapping_file()
            new_entry = {"folder_name": topic_name, "file_name": os.path.splitext(file["file_name"])[0] + ".txt"}
            df = pd.concat([df, pd.DataFrame([new_entry])], ignore_index=True)
            self.save_mapping_file(df)
            print(f"Mapping file updated with: {new_entry}")

        # Step 4: Upload updated mapping CSV to S3
        s3_client.upload_file(self.mapping_file_path, model_bucket, "final_file_topic_mapping.csv")

        # Step 5: Retrain model using S3-based documents
        self.retrain_model()
        self.update_unique_topics()


    def remove_topic(self, topic_name: str) -> None:
        """
        Remove an existing topic by deleting all related files in the corresponding folder under
        Extracted_Sample_Data, updating the mapping CSV, and retraining the model.
        Validates whether the topic exists before removal.
        """
        existing_topic = None
        for topic in self.unique_topics:
            if topic.lower() == topic_name.lower():
                existing_topic = topic
                break

        if not existing_topic:
            print(f"Topic '{topic_name}' does not exist.")
            return

        # Remove the topic folder and its contents
        topic_folder_path = os.path.join("/tmp","Extracted_Sample_Data", existing_topic)
        if os.path.exists(topic_folder_path):
            try:
                shutil.rmtree(topic_folder_path)
                print(f"Deleted folder: {topic_folder_path}")
            except Exception as e:
                print(f"Error deleting folder {topic_folder_path}: {e}")
                return
        else:
            print(f"Folder for topic '{existing_topic}' not found.")

        # Update mapping CSV by removing entries for this topic
        df = self.load_mapping_file()
        original_count = len(df)
        df = df[df['folder_name'].str.lower() != existing_topic.lower()]
        updated_count = len(df)
        if original_count != updated_count:
            self.save_mapping_file(df)
            s3_client.upload_file(self.mapping_file_path, model_bucket, "final_file_topic_mapping.csv")
            print(f"Removed {original_count - updated_count} mapping entries for topic '{existing_topic}'.")
        else:
            print("No mapping entries found for the topic.")
        response = s3_client.list_objects_v2(Bucket=model_bucket, Prefix=f"Extracted_Sample_Data/{existing_topic}/")
        print("response: ", response)
        if 'Contents' in response:
            # Prepare list of object keys
            objects = [{'Key': obj['Key']} for obj in response['Contents']]
            
            print(f"Deleting {len(objects)} objects:")
            for obj in objects:
                print(f"- {obj['Key']}")
            
            # Batch delete
            s3_client.delete_objects(
                Bucket=model_bucket,
                Delete={'Objects': objects}
            )

        print("Topic sample data deleted from S3")
        self.retrain_model()
        self.update_unique_topics()
        print(f"Topic '{existing_topic}' has been successfully removed.")

    def load_models(self) -> None:
        """
        Load the trained TF-IDF vectorizer and Random Forest classifier.
        """
        try:
            print(" Loading Trained TF-IDF Vectorizer and Random Forest Model...",flush=True)
            os.environ["JOBLIB_TEMP_FOLDER"] = "/tmp"
            with parallel_backend("threading"):  # Forces threading instead of multiprocessing
                if not os.path.exists(self.vectorizer_path):
                    print("Downloading tfidf vectorizer from S3...", flush=True)
                    s3_client.download_file(model_bucket, "tfidf_vectorizer.pkl", self.vectorizer_path)
                self.tfidf_vectorizer = joblib.load(self.vectorizer_path)
                if not os.path.exists(self.model_path):
                    print("Downloading rf model from S3...", flush=True)
                    s3_client.download_file(model_bucket, "rf_model.pkl", self.model_path)
                self.rf_model = joblib.load(self.model_path)
            print("Models loaded successfully.")
        except Exception as e:
            print("Error loading models. Make sure the model files exist.", e)
            self.tfidf_vectorizer, self.rf_model = None, None

    def classify_document(self, file_path: str, filename: str) -> tuple[str, str, float, str, str]:
        """
        Classify a document using the uploaded test document.
        Returns a tuple: (filename, predicted_topic, confidence, explanation, source).
        Note: The test document metadata is stored separately (with full file path).
        """

        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        sampled_text = self.extract_intro_middle_conclusion(content)
        predicted_topic, confidence = self.rf_classify_document(sampled_text)

        if predicted_topic:
            print(f"Random Forest Classification: {predicted_topic} (Confidence: {confidence:.2f})")
            return filename, predicted_topic, confidence, "-", "Random Forest Classification"

        predicted_topic, explanation = self.evaluate_topic_with_llama(sampled_text)
        print(f"LLM Classification: {predicted_topic}")
        return filename, predicted_topic, -1, explanation, "LLM Classification"

    def rf_classify_document(self, text: str, confidence_threshold: float = 0.99) -> tuple[str, float]:
        text_tfidf = self.tfidf_vectorizer.transform([text])
        y_pred_proba = self.rf_model.predict_proba(text_tfidf)[0]
        max_prob = max(y_pred_proba)
        predicted_topic = self.rf_model.classes_[y_pred_proba.argmax()]
        if max_prob < confidence_threshold:
            return None, max_prob
        return predicted_topic, max_prob

    def extract_intro_middle_conclusion(self, text: str, max_tokens: int = 20000) -> str:
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

    def evaluate_topic_with_llama(self, text: str) -> tuple[str, str]:
        """
        Use AWS Bedrock (LLM) as a fallback to classify the document if the classifier's confidence is low.
        This method uses the preloaded unique_topics_str.
        """
        try:
            prompt = f"""
            Analyze the following document sample and classify it into only one of these topics: {self.unique_topics_str}.
            After explaining your reasoning, clearly state the final topic at the end.
            
            Document:
            {text}
            
            Explanation: <Your explanation>
            Final Topic: <One of the topics from the list>
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

modelManager = ModelManager()
documentProcessor = DocumentProcessor()