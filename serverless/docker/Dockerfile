FROM public.ecr.aws/lambda/python:3.9

# Install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy Lambda function code
COPY app.py /var/task
COPY models.py /var/task
COPY final_file_topic_mapping.csv /var/task
COPY refined_tfidf_bigrams.csv /var/task

# Set the CMD to the Lambda function handler
CMD ["app.lambda_handler"]
