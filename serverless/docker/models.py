import mysql.connector
import json
import os
from datetime import datetime
import pytz


# For RDS
def get_db_connection():
    """Establish a connection to the database using environment variables."""
    host = os.getenv('DB_HOST')
    user = os.getenv('DB_USER')
    password = os.getenv('DB_PASSWORD')
    database = os.getenv('DB_NAME')

    return mysql.connector.connect(
        host=host,
        user=user,
        password=password,
        database=database
    )

# Define timezone (Asia/Singapore)
local_tz = pytz.timezone("Asia/Singapore")

############################################################### ModelState ##############################################################################################################
class ModelState:
    def __init__(self, state):
        self.state = state

    @staticmethod
    def get_state():
        """Get the current state of the ML model"""
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM ModelState")
        result = cursor.fetchone()
        cursor.close()
        connection.close()
        if result:
            return json.loads(result['state']) if isinstance(result['state'], str) else result['state']
        return None

    @staticmethod
    def update_state(new_state):
        """Get the current state of the ML model"""
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        state_json = json.dumps(new_state) if not isinstance(new_state, str) else new_state
        cursor.execute("UPDATE ModelState SET state=(%s) WHERE id = 1;",
        (state_json,))
        connection.commit()
        print(f"Successfully updated model state")
        cursor.close()
        connection.close()
        return

############################################################### Login ##############################################################################################################
class User:
    def __init__(self, id, email, password):
        self.id = id
        self.email = email
        self.password = password

    @staticmethod
    def find_by_email(email):
        """Find a user by their email."""
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        result = cursor.fetchone()
        cursor.close()
        connection.close()
        if result:
            return User(int(result['id']), result['email'], result['password'])
        return None

############################################################### Document ##############################################################################################################
class Document:
    def __init__(self, id, name, uploadedAt, status, summary=None, topics=None, classification=None, confidence=None, user_corrected_category=None, feedback=None):
        self.id = id
        self.name = name
        self.uploadedAt = uploadedAt
        self.status = status
        self.summary = summary
        self.topics = topics
        self.classification = classification
        self.confidence = confidence
        self.user_corrected_category = user_corrected_category
        self.feedback = feedback

    @staticmethod
    def get_documents(query=None):
        """Retrieve document metadata from the database with topics and classification."""
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        sql = "SELECT * FROM documents WHERE 1"
        params = []
        if query:
            sql += " AND name LIKE %s"
            params.append(f"%{query}%")

        cursor.execute(sql, params)
        results = cursor.fetchall()
        documents = []

        for row in results:
            uploaded_at = row["uploadedAt"] if row["uploadedAt"] else None
            documents.append(
                Document(
                    id=row["id"],
                    name=row["name"],
                    uploadedAt=uploaded_at.strftime("%Y-%m-%d %H:%M:%S") if uploaded_at else None,
                    status=row["status"],
                    summary=row["summary"],
                    topics=json.loads(row["topics"]) if row["topics"] else None,
                    classification=row["classification"] if row['classification'] else None,
                    confidence = float(row["confidence"]) if row["confidence"] else None,
                    user_corrected_category=row["user_corrected_category"],
                    feedback=row["feedback"]
                ).__dict__
            )

        cursor.close()
        connection.close()

        return documents
    
    @staticmethod
    def get_corrected_documents():
        """Retrieve corrected document metadata from the database with topics and classification."""
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        sql = "SELECT * FROM documents WHERE user_corrected_category IS NOT NULL"
        params = []

        cursor.execute(sql, params)
        results = cursor.fetchall()
        documents = []

        for row in results:
            uploaded_at = row["uploadedAt"] if row["uploadedAt"] else None
            documents.append(
                Document(
                    id=row["id"],
                    name=row["name"],
                    uploadedAt=uploaded_at.strftime("%Y-%m-%d %H:%M:%S") if uploaded_at else None,
                    status=row["status"],
                    summary=row["summary"],
                    topics=json.loads(row["topics"]) if row["topics"] else None,
                    classification=row["classification"] if row['classification'] else None,
                    confidence = float(row["confidence"]) if row["confidence"] else None,
                    user_corrected_category=row["user_corrected_category"],
                    feedback=row["feedback"]
                ).__dict__
            )

        cursor.close()
        connection.close()

        return documents
    
    @staticmethod
    def insert_file_record(fileid, filename):
        """Store document metadata in the database with dummy values."""
        connection = get_db_connection()
        cursor = connection.cursor()

        # Get current time in local timezone
        current_time = datetime.now(local_tz)

        cursor.execute(
            "INSERT INTO documents (id, name, uploadedAt, status, summary, confidence) VALUES (%s, %s, %s, 'processing' , null, null)",
            (fileid, filename, current_time)
        )

        connection.commit()
        cursor.close()
        connection.close()
        return

    @staticmethod
    def update_file_classification(file_id, summary, classification, confidence):
        """Store document metadata in the database with updated classification and summary."""
        print("file_id type: ", type(file_id),flush=True)
        connection = get_db_connection()
        cursor = connection.cursor()
        cursor.execute(
            "UPDATE documents SET summary = %s, classification = %s, confidence = %s, status='completed' WHERE id = %s;",
            (summary, classification, confidence, file_id)
        )
        connection.commit()
        cursor.close()
        connection.close()

    @staticmethod
    def delete_document(doc_id):
        """Delete a document from the database by its ID."""
        try:
            connection = get_db_connection()
            cursor = connection.cursor()
            
            # Delete the document by its ID
            cursor.execute("DELETE FROM documents WHERE id = %s;", (doc_id,))
            connection.commit()
            
            # Check if the document was successfully deleted
            if cursor.rowcount == 0:
                print(f"No document found with ID {doc_id}.")
                return False
            print(f"Document with ID {doc_id} has been deleted successfully.")
            cursor.close()
            connection.close()
            return True
        except Exception as e:
            print(f"Error deleting document: {e}")
            return False

    @staticmethod
    def add_feedback(doc_id, corrected_topic, feedback):
        """Delete a document from the database by its ID."""
        try:
            connection = get_db_connection()
            cursor = connection.cursor()
            
            # Add corrected category and feedback by document ID
            cursor.execute(
                "UPDATE documents SET user_corrected_category = (%s), feedback = (%s) WHERE id = (%s);", 
                (corrected_topic, feedback, doc_id,))
            connection.commit()
            print(f"Successfully corrected document with ID {doc_id} to {corrected_topic} category with reason: {feedback}")
            cursor.close()
            connection.close()
            return True
        except Exception as e:
            print(f"Error adding feedback for document: {e}")
            return False
    
    @staticmethod
    def correct_file_topic(doc_id, corrected_topic, feedback):
        """Delete a document from the database by its ID."""
        try:
            connection = get_db_connection()
            cursor = connection.cursor()
            
            summary = f"This document's classification has been manually overwritten based on the following feedback: \n\n{feedback}"
            # Add corrected category and feedback by document ID
            cursor.execute(
                "UPDATE documents SET user_corrected_category = NULL, feedback = NULL, classification = (%s), confidence = 1 summary = (%s) WHERE id = (%s);", 
                (corrected_topic, summary, doc_id,))
            connection.commit()
            print(f"Successfully corrected document with ID {doc_id} to {corrected_topic} category with reason: {feedback}")
            cursor.close()
            connection.close()
            return True
        except Exception as e:
            print(f"Error correcting file topic for document: {e}")
            return False

############################################################### Topic ##############################################################################################################

class Topic:
    def __init__(self, topic_name, created_at, document_count, status = "Pending"):
        self.topic_name = topic_name
        self.created_at = created_at
        self.document_count = document_count
        self.status = status

    @staticmethod
    def get_all_topics():
        """Retrieve all topics from the topics table."""
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM topics;")
        results = cursor.fetchall()
        topics = []

        for row in results:
            topics.append(
                Topic(
                    topic_name=row["topic_name"],
                    created_at=row["created_at"].strftime("%Y-%m-%d %H:%M:%S") if row["created_at"] else None,
                    document_count=row["document_count"],
                    status=row["status"]
                ).__dict__
            )

        cursor.close()
        connection.close()
        return topics

    @staticmethod
    def insert_topic(topic_name):
        """Insert a new topic into the topics table."""
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            "INSERT INTO topics (topic_name) VALUES (%s);",
            (topic_name,)
        )

        connection.commit()
        cursor.close()
        connection.close()

    @staticmethod
    def update_topic_status(topic_name, new_status):
        """Update the status of an existing topic in the table."""
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            "UPDATE topics SET status = (%s) WHERE topic_name = (%s);",
            (new_status, topic_name,)
        )

        connection.commit()
        cursor.close()
        connection.close()

    @staticmethod
    def delete_topic(topic_name):
        """Delete a topic from the topics table by its name."""
        try:
            connection = get_db_connection()
            cursor = connection.cursor()

            # Delete the topic by its name
            cursor.execute("DELETE FROM topics WHERE topic_name = %s;", (topic_name,))
            connection.commit()

            # Check if the topic was successfully deleted
            if cursor.rowcount == 0:
                print(f"No topic found with name {topic_name}.")
                cursor.close()
                connection.close()
                return False
            print(f"Topic with name {topic_name} has been deleted successfully.")
            cursor.close()
            connection.close()
            return True
        except Exception as e:
            print(f"Error deleting topic: {e}")
            return False
