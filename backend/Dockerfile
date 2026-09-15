FROM python:3.13-slim

WORKDIR /app

# Requirements first: this layer is cached until the file itself changes,
# so editing main.py does not trigger a full pip install.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]