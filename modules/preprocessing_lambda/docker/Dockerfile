# Dockerfile for NIST Document Preprocessing Lambda
# Uses Docling for PDF/DOCX parsing with NIST metadata extraction
# Optimized for ARM64 Graviton2

# =============================================================================
# Single-stage build using Lambda base to ensure glibc compatibility
# =============================================================================
FROM public.ecr.aws/lambda/python:3.13-arm64

# Install build dependencies and runtime libraries (available in AL2023)
# mesa-libGL provides libGL.so.1 needed by Docling/image processing
RUN dnf install -y gcc gcc-c++ make cmake mesa-libGL && \
    dnf clean all

# Install uv for fast dependency installation
RUN pip install --no-cache-dir uv

WORKDIR ${LAMBDA_TASK_ROOT}

# Install dependencies using uv (10-100x faster than pip)
# Install CPU-only PyTorch first from PyTorch index
RUN uv pip install --system --compile-bytecode \
    --index-url https://download.pytorch.org/whl/cpu \
    "torch>=2.0.0,<3.0.0"

# Install remaining dependencies from PyPI
# onnxruntime is required by RapidOCR for running OCR models
# tiktoken is required for accurate token counting in chunking module
RUN uv pip install --system --compile-bytecode \
    "numpy>=1.26.0,<2.0.0" \
    "docling>=2.0.0,<3.0.0" \
    "pymupdf>=1.24.0,<2.0.0" \
    "boto3>=1.34.0,<2.0.0" \
    "botocore>=1.34.0,<2.0.0" \
    "python-dateutil>=2.8.0,<3.0.0" \
    "onnxruntime>=1.18.0,<2.0.0" \
    "tiktoken>=0.9.0,<1.0.0"

# Pre-download OCR models during build (RapidOCR needs these at runtime)
# This triggers model download to site-packages which will be baked into the image
RUN python -c "from rapidocr import RapidOCR; ocr = RapidOCR()" || true

# Copy Lambda handler code, chunking module, and extractors module
COPY --chmod=644 src/handler.py ${LAMBDA_TASK_ROOT}/
COPY --chmod=644 src/chunking.py ${LAMBDA_TASK_ROOT}/
COPY --chmod=755 src/extractors/ ${LAMBDA_TASK_ROOT}/extractors/

# Set environment variables
ENV PYTHONPATH=${LAMBDA_TASK_ROOT}
ENV PYTHONUNBUFFERED=1

# Redirect all cache/home directories to /tmp (Lambda has read-only filesystem except /tmp)
ENV HOME=/tmp
ENV XDG_CACHE_HOME=/tmp/.cache
ENV HF_HOME=/tmp/.cache/huggingface
ENV TRANSFORMERS_CACHE=/tmp/.cache/transformers
ENV TORCH_HOME=/tmp/.cache/torch
ENV DOCLING_CACHE_DIR=/tmp/.cache/docling

# Lambda handler
CMD ["handler.handler"]