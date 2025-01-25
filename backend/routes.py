from flask import Blueprint, request, jsonify
import bcrypt
from models import User

auth_blueprint = Blueprint('auth', __name__)

@auth_blueprint.route('/login', methods=['POST'])
def login():
    data = request.get_json()

    email = data.get('email')
    password = data.get('password')

    # Check if email and password are provided
    if not email or not password:
        return jsonify({"message": "Email and password are required"}), 400

    # Retrieve user from database
    user = User.find_by_email(email)
    
    if user:
        print(f"User found: {user}")  # Debugging: Log the user object (avoid printing sensitive info in production)

        # Check if password matches the hashed password
        if bcrypt.checkpw(password.encode('utf-8'), user.password.encode('utf-8')):
            return jsonify({"message": "Login successful"}), 200
        else:
            print(f"Password mismatch for user: {email}")  # Debugging: Log password mismatch
            return jsonify({"message": "Invalid credentials"}), 401
    else:
        print(f"User not found for email: {email}")  # Debugging: Log if user is not found
        return jsonify({"message": "Invalid credentials"}), 401
