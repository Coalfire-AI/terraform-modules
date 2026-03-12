# IAM Role and Policies for Bedrock Knowledge Base

resource "aws_iam_role" "knowledge_base" {
  count = var.create_iam_role ? 1 : 0

  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Policy for accessing the embedding model
resource "aws_iam_role_policy" "bedrock_model_access" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.name}-bedrock-model-access"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeEmbeddingModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          local.embedding_model_arn
        ]
      }
    ]
  })
}

# Policy for accessing S3 data source bucket
resource "aws_iam_role_policy" "s3_data_source_access" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.name}-s3-data-source-access"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          local.data_source_bucket_arn
        ]
      },
      {
        Sid    = "S3GetObject"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${local.data_source_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Policy for accessing S3 vector bucket (only when using S3_VECTORS)
resource "aws_iam_role_policy" "s3_vectors_access" {
  count = var.create_iam_role && var.vector_store_type == "S3_VECTORS" ? 1 : 0

  name = "${var.name}-s3-vectors-access"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3VectorsAccess"
        Effect = "Allow"
        Action = [
          "s3vectors:CreateIndex",
          "s3vectors:DeleteIndex",
          "s3vectors:GetIndex",
          "s3vectors:ListIndexes",
          "s3vectors:PutVectors",
          "s3vectors:GetVectors",
          "s3vectors:DeleteVectors",
          "s3vectors:QueryVectors"
        ]
        Resource = [
          aws_s3vectors_vector_bucket.knowledge_base[0].vector_bucket_arn,
          "${aws_s3vectors_vector_bucket.knowledge_base[0].vector_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Policy for accessing OpenSearch Serverless (only when using OPENSEARCH_SERVERLESS)
resource "aws_iam_role_policy" "opensearch_serverless_access" {
  count = var.create_iam_role && var.vector_store_type == "OPENSEARCH_SERVERLESS" ? 1 : 0

  name = "${var.name}-opensearch-serverless-access"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OpenSearchServerlessAPIAccess"
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = [
          aws_opensearchserverless_collection.knowledge_base[0].arn
        ]
      }
    ]
  })
}

# Policy for KMS access
resource "aws_iam_role_policy" "kms_access" {
  # Use input variables to determine count (avoids dependency on computed values)
  count = var.create_iam_role && (var.create_kms_key || var.kms_key_arn != null) ? 1 : 0

  name = "${var.name}-kms-access"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [
          local.kms_key_arn
        ]
      }
    ]
  })
}

# Policy for Lambda invoke (custom transformation)
resource "aws_iam_role_policy" "lambda_invoke" {
  count = var.create_iam_role && var.enable_custom_transformation ? 1 : 0

  name = "${var.name}-lambda-invoke"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLambda"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.transformation_lambda_arn
      }
    ]
  })
}

# Policy for intermediate storage access (custom transformation)
resource "aws_iam_role_policy" "intermediate_storage" {
  count = var.create_iam_role && var.enable_custom_transformation ? 1 : 0

  name = "${var.name}-intermediate-storage"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IntermediateStorageAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${local.intermediate_storage_bucket_arn}/${var.intermediate_storage_prefix}*"
      },
      {
        Sid    = "IntermediateStorageList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = local.intermediate_storage_bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = "${var.intermediate_storage_prefix}*"
          }
        }
      }
    ]
  })
}

# Policy for Foundation Model parsing (if using BEDROCK_FOUNDATION_MODEL parsing)
# Grants permission to invoke the parsing model for document extraction
resource "aws_iam_role_policy" "parsing_model_access" {
  count = var.create_iam_role && var.parsing_strategy == "BEDROCK_FOUNDATION_MODEL" ? 1 : 0

  name = "${var.name}-parsing-model-access"
  role = aws_iam_role.knowledge_base[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeParsingModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = local.parsing_model_arn
      }
    ]
  })
}