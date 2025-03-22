FROM public.ecr.aws/lambda/python:3.9

# Install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

RUN python -m nltk.downloader -d /usr/local/share/nltk_data stopwords

# Copy Lambda function code
COPY . /var/task
