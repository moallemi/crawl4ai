# syntax=docker/dockerfile:1.4

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Other build arguments
ARG PYTHON_VERSION=3.10

# Base stage with system dependencies
FROM python:${PYTHON_VERSION}-slim as base

# Declare ARG variables again within the build stage
ARG INSTALL_TYPE=all
ARG ENABLE_GPU=false

# Platform-specific labels
LABEL maintainer="unclecode"
LABEL description="🔥🕷️ Crawl4AI: Open-source LLM Friendly Web Crawler & scraper"
LABEL version="1.0"

# Environment setup
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=100 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    gnupg \
    git \
    cmake \
    pkg-config \
    python3-dev \
    libjpeg-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Playwright system dependencies for Linux
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxcb1 \
    libxkbcommon0 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*


# Update package list*
RUN apt-get update

# Install GStreamer and related packages
RUN apt-get install -y \
    libgstreamer1.0-0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav


# Install media codecs and libraries
RUN apt-get install -y \
    libxslt1.1 \
    libvpx7 \
    libevent-2.1-7 \
    libopus0 \
    libwebp7 \
    libwebpdemux2 \
    libwebpmux3 \
    libavif15


# Install text processing and rendering libraries
RUN apt-get install -y \
    libharfbuzz-icu0 \
    libenchant-2-2 \
    libsecret-1-0 \
    libhyphen0

# Install gaming and graphics libraries*
RUN apt-get install -y \
    libmanette-0.2-0 \
    libgles2

# Install speech synthesis libraries*
RUN apt-get install -y \
    flite1-dev

# Install video encoding libraries*
RUN apt-get install -y \
    libx264-dev

# Install woff2 library*
RUN apt-get install -y \
    libwoff1

# GPU support if enabled and architecture is supported
RUN if [ "$ENABLE_GPU" = "true" ] && [ "$TARGETPLATFORM" = "linux/amd64" ] ; then \
    apt-get update && apt-get install -y --no-install-recommends \
    nvidia-cuda-toolkit \
    && rm -rf /var/lib/apt/lists/* ; \
else \
    echo "Skipping NVIDIA CUDA Toolkit installation (unsupported platform or GPU disabled)"; \
fi

# Create and set working directory
WORKDIR /app

# Copy the entire project
COPY . .

# Install base requirements
RUN pip install --no-cache-dir -r requirements.txt

# Install required library for FastAPI
RUN pip install fastapi uvicorn psutil

# Install ML dependencies first for better layer caching
RUN if [ "$INSTALL_TYPE" = "all" ] ; then \
        pip install --no-cache-dir \
            torch \
            torchvision \
            torchaudio \
            scikit-learn \
            nltk \
            transformers \
            tokenizers && \
        python -m nltk.downloader punkt stopwords ; \
    fi

# Install the package
RUN if [ "$INSTALL_TYPE" = "all" ] ; then \
        pip install ".[all]" && \
        python -m crawl4ai.model_loader ; \
    elif [ "$INSTALL_TYPE" = "torch" ] ; then \
        pip install ".[torch]" ; \
    elif [ "$INSTALL_TYPE" = "transformer" ] ; then \
        pip install ".[transformer]" && \
        python -m crawl4ai.model_loader ; \
    else \
        pip install "." ; \
    fi

    # Install MkDocs and required plugins
RUN pip install --no-cache-dir \
    mkdocs \
    mkdocs-material \
    mkdocs-terminal \
    pymdown-extensions

# Build MkDocs documentation
RUN mkdocs build

# Install Playwright and browsers
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    playwright install chromium; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    playwright install chromium; \
    fi

# Expose port
EXPOSE 8000 11235 9222 8080

# Start the FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "11235"]