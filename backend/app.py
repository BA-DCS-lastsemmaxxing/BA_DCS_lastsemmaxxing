from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/')
def home():
    return jsonify({"message": "Welcome to Flask!"})

@app.route('/classify', methods=["POST"])
def classify():
    data = {'response': "This document appears to be regarding MAS's annual financial report for 2024.",
    'classifications': ["Financial", "Report", "Annual", "Confidential", "test"]}
    return jsonify(data), 200

if __name__ == '__main__':
    app.run(debug=True, port=5001)
