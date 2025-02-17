import mysql.connector
import json
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# For RDS

# def get_db_connection():
#     # Use the RDS endpoint from the environment variable
#     host = os.getenv('DB_HOST')
#     user = os.getenv('DB_USER')
#     password = os.getenv('DB_PASSWORD')
#     database = os.getenv('DB_NAME')

#     return mysql.connector.connect(
#         host=host,
#         user=user,
#         password=password,
#         database=database
#     )

# For local demo
def get_db_connection():
    host = os.getenv('DB_HOST', 'db')  # Default to 'db' for Docker networking
    password = os.getenv('DB_PASSWORD','rootpassword')
    return mysql.connector.connect(
        host=host,
        user='root',  # Use your MySQL username
        password=password,  # MySQL root password
        database='user_database', # Database name
        port = 3306
    )

###############################################################Login##############################################################################################################
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

###############################################################Document##############################################################################################################
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
        documents = [
            Document(
                id=row["id"],
                name=row["name"],
                uploadedAt=row["uploadedAt"].strftime("%d-%m-%y %H:%M"),
                status=row["status"],
                summary=row["summary"],
                topics=json.loads(row["topics"]) if row["topics"] else None,  # Handle topics instead of tags
                classification=row["classification"] if row['classification'] else None
            ).__dict__
            for row in results
        ]

        cursor.close()
        connection.close()

        return documents
    
    @staticmethod
    def insert_file_record(filename):
        print("filename: ", filename)
        """Store document metadata in the database with dummy values."""
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            "INSERT INTO documents (name, uploadedAt, status, summary) VALUES (%s, NOW(), 'processing' , 'This is a dummy summary.')",
            (filename,)
        )
        doc_id = cursor.lastrowid
        connection.commit()
        cursor.close()
        connection.close()
        return doc_id

    @staticmethod
    def update_file_classification(file_id, classification):
        """Store document metadata in the database with dummy values."""
        connection = get_db_connection()
        cursor = connection.cursor()
        print(classification)
        cursor.execute(
            "UPDATE documents SET classification = %s, status='completed' WHERE id = %s;",
            (classification[0], file_id)
        )
        connection.commit()
        cursor.close()
        connection.close()
