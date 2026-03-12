# Chunk Metadata Transformer Lambda
# Python container for POST_CHUNKING metadata enrichment
# NOTE: Chunking is now handled by preprocessing_lambda; this Lambda only enriches metadata

# Use Python 3.13 Lambda base image (AL2023, glibc 2.34)
FROM public.ecr.aws/lambda/python:3.13

# Set working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# No additional dependencies needed - boto3 is included in Lambda base image
# The extractors module uses only standard library for regex matching

# Copy handler code and extractors with explicit permissions
# Lambda runs as non-root user (sbx_userXXXX), needs read permissions
COPY --chmod=644 src/handler.py ${LAMBDA_TASK_ROOT}/
COPY --chmod=755 src/extractors/ ${LAMBDA_TASK_ROOT}/extractors/

# Set the handler
CMD ["handler.handler"]