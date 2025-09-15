# Stage 1: Build environment
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_ROOT_USER_ACTION=ignore

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3.10-dev \
    build-essential \
    libcudnn8-dev \
    libnss3 \
    libatk1.0-0 \
    libxkbcommon0 \
    libgl1 \
    libglib2.0-0 \
    && rm -f /usr/bin/python /usr/bin/python3 \
    && ln -s /usr/bin/python3.10 /usr/bin/python \
    && ln -s /usr/bin/python3.10 /usr/bin/python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .

# Install Python dependencies (added scikit-image)
RUN pip install --user --no-cache-dir -r requirements.txt \
    && pip install --user playwright==1.48.0 numpy==1.24.4 scikit-image \
    && pip install --user https://github.com/explosion/spacy-models/releases/download/en_core_web_lg-3.7.0/en_core_web_lg-3.7.0-py3-none-any.whl

# Install Playwright browsers
RUN python -m playwright install chromium

# Stage 2: Runtime image
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/root/.local/bin:$PATH

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    python3.10-minimal \
    libcudnn8 \
    libnss3 \
    libatk1.0-0 \
    libxkbcommon0 \
    tesseract-ocr \
    libgl1 \
    libglib2.0-0 \
    && rm -f /usr/bin/python /usr/bin/python3 \
    && ln -s /usr/bin/python3.10 /usr/bin/python \
    && ln -s /usr/bin/python3.10 /usr/bin/python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy from builder
COPY --chown=root:root --from=builder /root/.local /root/.local
COPY --chown=root:root --from=builder /root/.cache/ms-playwright /root/.cache/ms-playwright

# Verify installations
RUN python -c "import en_core_web_lg, skimage; print('All dependencies loaded successfully')" \
    || { echo "Failed to load dependencies"; exit 1; }

# Fix shebang lines
RUN find /root/.local -type f -name 'uvicorn*' -exec sed -i '1s|^.*$|#!/usr/bin/python3|' {} + \
    && find /root/.local -type f -executable -exec sed -i '1s|/usr/bin/python3|/usr/bin/python3.10|' {} + 2>/dev/null || true

# Copy application
COPY . .

# Environment variables
ENV CUDA_VISIBLE_DEVICES=0 \
    HOST=0.0.0.0 \
    PORT=8000

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
