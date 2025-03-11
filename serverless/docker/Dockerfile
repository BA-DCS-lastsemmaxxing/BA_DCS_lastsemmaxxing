FROM public.ecr.aws/lambda/python:3.9

# Install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy Lambda function code
COPY app.py /var/task
COPY models.py /var/task

# Set the CMD to the Lambda function handler
CMD ["app.lambda_handler"]
