FROM python:3.12-slim
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY . /app
CMD ["python", "cli.py", "init"]
