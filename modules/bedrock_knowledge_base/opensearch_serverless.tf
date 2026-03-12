# OpenSearch Serverless Resources for Bedrock Knowledge Base
# This file contains all OpenSearch Serverless resources, conditionally created
# when vector_store_type = "OPENSEARCH_SERVERLESS"

# =============================================================================
# Encryption Security Policy (REQUIRED - must be created before collection)
# =============================================================================

resource "aws_opensearchserverless_security_policy" "encryption" {
  count = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? 1 : 0

  # OpenSearch policy names have a 32 character limit
  name        = substr("${var.name}-enc", 0, 32)
  type        = "encryption"
  description = "Encryption policy for ${var.name} knowledge base collection"

  policy = jsonencode({
    Rules = [
      {
        Resource     = ["collection/${local.opensearch_collection_name}"]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = var.opensearch_use_aws_owned_key
  })
}

# =============================================================================
# Network Security Policy
# =============================================================================
# When public access is disabled, AWS service private access is enabled for
# Bedrock (bedrock.amazonaws.com) so the Knowledge Base can still access the
# collection. See: https://repost.aws/knowledge-center/bedrock-knowledge-base-private-network-policy
# =============================================================================

resource "aws_opensearchserverless_security_policy" "network" {
  count = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? 1 : 0

  # OpenSearch policy names have a 32 character limit
  name        = substr("${var.name}-net", 0, 32)
  type        = "network"
  description = "Network policy for ${var.name} knowledge base collection"

  policy = jsonencode([
    merge(
      {
        Description = var.opensearch_allow_public_access ? "Public access for ${var.name} collection" : "Private access with Bedrock service access for ${var.name} collection"
        Rules = [
          {
            Resource     = ["collection/${local.opensearch_collection_name}"]
            ResourceType = "collection"
          },
          {
            Resource     = ["collection/${local.opensearch_collection_name}"]
            ResourceType = "dashboard"
          }
        ]
        AllowFromPublic = var.opensearch_allow_public_access
      },
      # When public access is disabled, enable AWS service private access for Bedrock
      # This allows Bedrock Knowledge Base to access the private collection
      var.opensearch_allow_public_access ? {} : { SourceServices = ["bedrock.amazonaws.com"] }
    )
  ])

  depends_on = [aws_opensearchserverless_security_policy.encryption]
}

# =============================================================================
# Data Access Policy (grants Bedrock role access to collection)
# =============================================================================

resource "aws_opensearchserverless_access_policy" "data" {
  count = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? 1 : 0

  # OpenSearch policy names have a 32 character limit
  name        = substr("${var.name}-data", 0, 32)
  type        = "data"
  description = "Data access policy for ${var.name} knowledge base"

  policy = jsonencode([
    {
      Description = "Allow Bedrock knowledge base to access collection"
      Rules = [
        {
          Resource = ["collection/${local.opensearch_collection_name}"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
          ResourceType = "collection"
        },
        {
          Resource = ["index/${local.opensearch_collection_name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
          ResourceType = "index"
        }
      ]
      # Principal list includes:
      # - Bedrock KB execution role (always required)
      # - Additional principals for index creation (e.g., Terraform deployment role)
      # Note: Use IAM role ARNs, not STS assumed-role ARNs, as OpenSearch validates
      # the underlying IAM principal, not the specific session.
      Principal = concat(
        [local.role_arn],
        var.opensearch_additional_data_access_principals
      )
    }
  ])

  depends_on = [aws_opensearchserverless_security_policy.network]
}

# =============================================================================
# OpenSearch Serverless Collection
# =============================================================================

resource "aws_opensearchserverless_collection" "knowledge_base" {
  count = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? 1 : 0

  name             = local.opensearch_collection_name
  description      = "Vector store for ${var.name} Bedrock knowledge base"
  type             = "VECTORSEARCH"
  standby_replicas = var.opensearch_standby_replicas

  tags = local.common_tags

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data
  ]
}

# =============================================================================
# Wait for Collection to be Active
# =============================================================================

resource "time_sleep" "wait_for_collection" {
  count = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? 1 : 0

  depends_on = [aws_opensearchserverless_collection.knowledge_base]

  create_duration = var.opensearch_collection_wait_duration
}

# =============================================================================
# Vector Index Configuration Output
#
# The vector index must be created AFTER the collection is active. Since there's
# no native AWS Terraform resource for OpenSearch Serverless indexes, and the
# opensearch provider requires the endpoint URL at plan time, users must create
# the index in a separate step.
#
# Options for creating the index:
# 1. Use the opensearch provider in a separate Terraform configuration
# 2. Use the AWS Console (OpenSearch Serverless > Collections > Indexes)
# 3. Use the OpenSearch Dashboards Dev Tools
#
# This module outputs all necessary configuration for index creation.
# See the opensearch_index_config output for the complete mapping.
# =============================================================================

# Generate the index mapping configuration as an output
# Users can use this with the opensearch provider or copy to OpenSearch Dashboards
locals {
  # Only compute when using OpenSearch Serverless
  opensearch_index_mapping = var.vector_store_type == "OPENSEARCH_SERVERLESS" ? jsonencode({
    settings = {
      "index.knn" = true
    }
    mappings = {
      properties = {
        (var.opensearch_vector_field_name) = {
          type      = "knn_vector"
          dimension = var.embedding_dimensions
          method = {
            engine     = "faiss"
            name       = "hnsw"
            space_type = local.opensearch_space_type
            parameters = {
              ef_construction = 512
              m               = 16
            }
          }
        }
        (var.opensearch_text_field_name) = {
          type = "text"
        }
        (var.opensearch_metadata_field_name) = {
          type = "text"
        }
      }
    }
  }) : null
}