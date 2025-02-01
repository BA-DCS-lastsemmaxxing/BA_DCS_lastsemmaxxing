import mysql.connector
import json

def get_db_connection():
    return mysql.connector.connect(
        host='localhost',
        user='root',  # use your MySQL username
        database='user_database'
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
    def __init__(self, id, name, uploadedAt, status, summary=None, tags=None):
        self.id = id
        self.name = name
        self.uploadedAt = uploadedAt
        self.status = status
        self.summary = summary
        self.tags = tags.split(",") if tags else None

    @staticmethod
    def store_metadata(filename, status="processing"):
        """Store document metadata in the database."""
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            "INSERT INTO documents (name, uploaded_at, status) VALUES (%s, NOW(), %s)",
            (filename, status)
        )
        connection.commit()
        cursor.close()
        connection.close()

    @staticmethod
    def get_documents(query=None):
        """Retrieve document metadata from the database."""
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
                tags=row["tags"]
            ).__dict__
            for row in results
        ]

        cursor.close()
        connection.close()

        return documents
    
    
    @staticmethod
    def store_metadata(filename, status="processing"):
        """Store document metadata in the database with dummy values."""
        connection = get_db_connection()
        cursor = connection.cursor()

        dummy_summary = "This is a dummy summary."
        dummy_tags = json.dumps(["tag1", "tag2", "tag3"])  # Convert tags to a JSON array

        cursor.execute(
            "INSERT INTO documents (name, uploadedAt, status, summary, tags) VALUES (%s, NOW(), %s, %s, %s)",
            (filename, status, dummy_summary, dummy_tags)
        )
        connection.commit()
        cursor.close()
        connection.close()