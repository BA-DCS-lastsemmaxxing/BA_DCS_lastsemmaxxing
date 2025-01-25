import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY')
    SQLALCHEMY_DATABASE_URI = "mysql+mysqlconnector://root@localhost:3306/user_database"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
