# CloudWatch Logging for Bedrock Knowledge Base
# Enables APPLICATION_LOGS for data ingestion job monitoring

# =============================================================================
# CloudWatch Log Group for Knowledge Base
# =============================================================================

resource "aws_cloudwatch_log_group" "knowledge_base" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/vendedlogs/bedrock/knowledge-base/${var.name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# =============================================================================
# CloudWatch Logs Delivery Source
# =============================================================================

resource "aws_cloudwatch_log_delivery_source" "knowledge_base" {
  count = var.enable_logging && var.create_knowledge_base ? 1 : 0

  name         = "${var.name}-delivery-source"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagent_knowledge_base.this[0].arn

  tags = var.tags

  depends_on = [aws_bedrockagent_knowledge_base.this]
}

# =============================================================================
# CloudWatch Logs Delivery Destination
# =============================================================================

resource "aws_cloudwatch_log_delivery_destination" "knowledge_base" {
  count = var.enable_logging && var.create_knowledge_base ? 1 : 0

  name = "${var.name}-delivery-destination"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.knowledge_base[0].arn
  }

  tags = var.tags
}

# =============================================================================
# CloudWatch Logs Delivery (links source to destination)
# =============================================================================

resource "aws_cloudwatch_log_delivery" "knowledge_base" {
  count = var.enable_logging && var.create_knowledge_base ? 1 : 0

  delivery_source_name     = aws_cloudwatch_log_delivery_source.knowledge_base[0].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.knowledge_base[0].arn

  tags = var.tags
}