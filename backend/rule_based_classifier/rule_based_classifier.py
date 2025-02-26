import os
import pandas as pd
import time
import re
import math
from collections import defaultdict
from nltk.stem import WordNetLemmatizer
from sklearn.feature_extraction.text import CountVectorizer

# ----------------------------
#  **Step 1: Load Keyword Data**
# ----------------------------
top_keywords_per_topic = {}
main_topics = set()

df = pd.read_csv("refined_tfidf_bigrams_v4.csv")

for index, row in df.iterrows():
    topic_name = row.iloc[0].strip()
    keywords = [row[col] for col in df.columns[1:] if pd.notna(row[col])]
    
    if keywords:
        top_keywords_per_topic[topic_name] = keywords[:150]  
        main_topics.add(topic_name.split("/")[0])  

print(f" Loaded {len(top_keywords_per_topic)} topics from extracted words.")

# ----------------------------
#  **Step 2: Preprocessing & Tokenization**
# ----------------------------
vectorizer = CountVectorizer(
    stop_words="english",
    lowercase=True,
    token_pattern=r"(?u)\b\w+\b",
    ngram_range=(1, 2)
)

def fast_tokenize(text):
    """Tokenizes text using CountVectorizer to include both words & bigrams."""
    return set(vectorizer.build_analyzer()(text))

# ----------------------------
#  **Step 3: Rule-Based Classification**
# ----------------------------

CONFIDENCE_THRESHOLD = 0.90  # Minimum confidence to classify
MIN_MATCHED_WORDS = 30  # Minimum keyword matches
LENGTH_PENALTY_SCALING = 70  # Adjusts penalty for document length

def apply_length_penalty(score, doc_length):
    """Applies a logarithmic penalty for long documents to prevent inflated confidence."""
    return score / (1 + math.log(1 + doc_length) / LENGTH_PENALTY_SCALING)

def classify_document(text):
    """Classifies a document using the rule-based model."""
    
    doc_words = fast_tokenize(text)
    doc_length = len(doc_words)

    if doc_length < 100:  
        return None, 0.0  #  Skip classification instead of returning "LLM Needed"

    best_match, best_score = None, 0

    for topic in main_topics:
        topic_keywords = set(word for subtopic in top_keywords_per_topic if subtopic.startswith(topic) for word in top_keywords_per_topic[subtopic])
        matched_words = doc_words.intersection(topic_keywords)

        weighted_score = sum(1.0 * (0.85 ** idx) for idx, word in enumerate(matched_words))
        max_possible_score = sum(1.0 * (0.85 ** idx) for idx in range(len(topic_keywords)))
        normalized_score = weighted_score / max_possible_score if max_possible_score > 0 else 0

        adjusted_score = apply_length_penalty(normalized_score, doc_length)

        if adjusted_score > best_score and len(matched_words) >= MIN_MATCHED_WORDS:
            best_score = adjusted_score
            best_match = topic

    if best_score < CONFIDENCE_THRESHOLD:
        return None, best_score  #  Skip classification instead of returning "LLM Needed"

    return best_match, best_score

# ----------------------------
#  **Step 4: Process Documents & Save CSV**
# ----------------------------

def classify_documents(input_dir):
    """Processes text documents in a directory and outputs classification results to a timestamped CSV file."""
    
    document_results = []
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    output_csv = f"classified_documents_{timestamp}.csv"
    
    for root, _, files in os.walk(input_dir):
        for file in files:
            if file.endswith(".txt"):
                file_path = os.path.join(root, file)

                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()

                predicted_topic, confidence = classify_document(content)

                if predicted_topic is not None:  #  Only save classified documents
                    document_results.append({
                        "Filename": file,
                        "Predicted Topic": predicted_topic,
                        "Confidence": confidence
                    })

    df_results = pd.DataFrame(document_results)

    if not df_results.empty:
        df_results.to_csv(output_csv, index=False)
        print(f"Classification completed. Results saved to {output_csv}")
    else:
        print("No documents were classified with high confidence. No CSV file generated.")

# ----------------------------
#  **Run Classification**
# ----------------------------

if __name__ == "__main__":
    input_directory = "Cleaned_Data_v5"  # Change this to your actual data directory
    classify_documents(input_directory)
