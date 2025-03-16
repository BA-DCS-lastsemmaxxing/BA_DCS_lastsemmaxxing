import os
import pymysql
import boto3

# AWS Clients
s3 = boto3.client("s3")

# Lambda function handler
def lambda_handler(event, context):
    try:
        # Fetch DB credentials from SSM
        db_host = os.getenv("DB_HOST")
        db_user = os.getenv("DB_USER")
        db_pass = os.getenv("DB_PASSWORD")
        db_name = os.getenv("DB_NAME")
        s3_bucket = os.getenv("S3_BUCKET")
        sql_file_key = os.getenv("SQL_FILE_KEY")

        # Download SQL script from S3
        sql_file_path = "/tmp/rds_init_script.sql"
        s3.download_file(s3_bucket, sql_file_key, sql_file_path)

        # Connect to MySQL RDS
        conn = pymysql.connect(host=db_host, user=db_user, password=db_pass, database=db_name)
        cursor = conn.cursor()

        # Read and execute SQL commands
        with open(sql_file_path, "r") as file:
            sql_commands = file.read()

        for command in sql_commands.split(";"):
            if command.strip():
                cursor.execute(command)

        conn.commit()
        cursor.close()
        conn.close()

        return {"statusCode": 200, "message": "SQL script executed successfully"}

    except Exception as e:
        return {"statusCode": 500, "error": str(e)}
