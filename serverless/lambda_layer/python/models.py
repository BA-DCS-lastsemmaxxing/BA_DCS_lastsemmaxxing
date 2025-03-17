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
    def __init__(self, id, name, uploadedAt, status, summary=None, topics=None, classification=None, confidence=None):
        self.id = id
        self.name = name
        self.uploadedAt = uploadedAt
        self.status = status
        self.summary = summary
        self.topics = topics
        self.classification = classification
        self.confidence = confidence

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
            # Convert uploadedAt to local timezone
            uploaded_at = row["uploadedAt"].astimezone(local_tz) if row["uploadedAt"] else None
            documents.append(
                Document(
                    id=row["id"],
                    name=row["name"],
                    uploadedAt=uploaded_at.strftime("%d-%m-%y %H:%M:%S") if uploaded_at else None,
                    status=row["status"],
                    summary=row["summary"],
                    topics=json.loads(row["topics"]) if row["topics"] else None,
                    classification=row["classification"] if row['classification'] else None,
                    confidence = float(row["confidence"]) if row["confidence"] else None
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
        current_time = datetime.now(local_tz).strftime('%Y-%m-%d %H:%M:%S')
        print("current time for insert: ",current_time, flush=True)

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