import mysql.connector

def get_db_connection():
    return mysql.connector.connect(
        host='localhost',
        user='root',  # use your MySQL username
        database='user_database'
    )

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
