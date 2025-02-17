import mysql.connector
import json
import os

def get_db_connection():
    # Use the RDS endpoint from the environment variable
    host = os.getenv('DB_HOST', 'terraform-20250216045524406600000003.cpk00i8mcpir.ap-southeast-1.rds.amazonaws.com')  # Replace with your RDS endpoint
    return mysql.connector.connect(
        host=host,
        user=os.getenv('DB_USER', 'admin'),  # Use MySQL username from environment variable
        password=os.getenv('DB_PASSWORD', 'testpassword'),  # Use MySQL password from environment variable
        database=os.getenv('DB_NAME', 'user_database')  # Database name from environment variable
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
    def store_metadata(filename, status="processing", classification=None):
        """Store document metadata in the database with topics and classification."""
        connection = get_db_connection()
        cursor = connection.cursor()

        dummy_summary = "This is a dummy summary."
        dummy_topics = json.dumps(["topic1", "topic2", "topic3"])  # Convert topics to a JSON array

        cursor.execute(
            "INSERT INTO documents (name, uploadedAt, status, summary, topics, classification) VALUES (%s, NOW(), %s, %s, %s, %s)",
            (filename, status, dummy_summary, dummy_topics, classification)
        )
        connection.commit()
        cursor.close()
        connection.close()

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
                classification=row["classification"]
            ).__dict__
            for row in results
        ]

        cursor.close()
        connection.close()

        return documents
