import mysql.connector
import json
import os
import datetime
import pytz
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Define local timezone (Change accordingly)
LOCAL_TZ = pytz.timezone("Asia/Singapore")  # Example: Singapore Time

host=os.getenv('DB_HOST'),
user=os.getenv('DB_USER'),
password=os.getenv('DB_PASSWORD'),
database=os.getenv('DB_NAME')

def get_db_connection():
    """Establish a connection to the MySQL database."""
    return mysql.connector.connect(
        host=host,
        user=user,
        password=password,
        database=database,
        port=3306
    )

def convert_to_local_time(utc_time):
    """Convert UTC time from MySQL to local timezone."""
    if isinstance(utc_time, datetime.datetime):
        utc_dt = utc_time.replace(tzinfo=pytz.utc)  # Mark as UTC
        local_dt = utc_dt.astimezone(LOCAL_TZ)  # Convert to local time
        return local_dt.strftime("%d-%m-%y %H:%M")  # Format for consistency
    return utc_time

##############################################################################################################
# 🔐 User Authentication Model
##############################################################################################################
class User:
    def __init__(self, id, email, password):
        self.id = id
        self.email = email
        self.password = password

    @staticmethod
    def find_by_email(email):
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        result = cursor.fetchone()
        cursor.close()
        connection.close()
        if result:
            return User(result['id'], result['email'], result['password'])
        return None

##############################################################################################################
# 📄 Document Model
##############################################################################################################
class Document:
    def __init__(self, id, name, uploadedAt, status, summary=None, topics=None, classification=None):
        self.id = id
        self.name = name
        self.uploadedAt = uploadedAt
        self.status = status
        self.summary = summary
        self.topics = topics
        self.classification = classification

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

        # Convert timestamps to local time
        documents = [
            Document(
                id=row["id"],
                name=row["name"],
                uploadedAt=convert_to_local_time(row["uploadedAt"]),  # Convert MySQL UTC to local time
                status=row["status"],
                summary=row["summary"],
                topics=json.loads(row["topics"]) if row["topics"] else None,  
                classification=row["classification"] if row['classification'] else None
            ).__dict__
            for row in results
        ]

        cursor.close()
        connection.close()
        return documents

    @staticmethod
    def insert_file_record(filename):
        """Store document metadata in the database with Python-generated timestamp."""
        connection = get_db_connection()
        cursor = connection.cursor()

        # Generate timestamp in UTC and store it in MySQL
        now_utc = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)

        cursor.execute(
            "INSERT INTO documents (name, uploadedAt, status, summary) VALUES (%s, %s, 'processing', 'This is a dummy summary.')",
            (filename, now_utc)
        )
        doc_id = cursor.lastrowid
        connection.commit()
        cursor.close()
        connection.close()
        return doc_id

    @staticmethod
    def update_file_classification(file_id, summary, classification):
        """Update document classification and status."""
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            "UPDATE documents SET summary = %s, classification = %s, status='completed' WHERE id = %s;",
            (summary, classification, file_id)
        )
        connection.commit()
        cursor.close()
        connection.close()
