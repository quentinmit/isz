# syntax=docker/dockerfile:1

FROM python:3.10

WORKDIR /app

COPY requirements.txt requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD [ "python3", "/app/graph.py" ]
