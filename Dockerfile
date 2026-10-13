# Use official lightweight Python image
FROM python:3.11-slim

# Prevent Python from buffering stdout/stderr and creating .pyc files
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=7860 \
    MODEL_PATH=road_unet_epoch15.pth

WORKDIR /app

# Install system dependencies required by OpenCV and curl for health check
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency specifications
COPY requirements.txt .

# Install CPU-optimized PyTorch first (reduces image size from ~7GB to ~1.5GB)
# followed by the remaining application dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir -r requirements.txt

# Copy application files and model weights
COPY app.py .
COPY road_unet_epoch15.pth .
COPY road_unet_epoch5.pth* ./
COPY unseen.png* ./

# Expose Gradio port
EXPOSE 7860

# Add container health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:7860/ || exit 1

# Launch Gradio inference application
CMD ["python", "app.py"]
