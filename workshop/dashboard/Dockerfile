# syntax=docker/dockerfile:1

FROM python:3.10

WORKDIR /app

COPY requirements.txt requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

RUN sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list && DEBIAN_FRONTEND=noninteractive apt-get update -q
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y xfonts-traditional xfonts-100dpi xfonts-base ttf-mscorefonts-installer

COPY . .

CMD [ "python3", "/app/graph.py" ]
