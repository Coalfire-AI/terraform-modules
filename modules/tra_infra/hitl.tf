# Handler Configuration
# Deploys either Slack or Teams handler based on handler_platform variable.
# Only one platform can be active per deployment (mutually exclusive).

###############################################################################
# Slack Handler Module
# Creates Lambda, API Gateway, and DynamoDB for Slack handler workflow
###############################################################################

module "slack_handler" {
  source = "../slack_handler"
  count  = var.handler_platform == "slack" ? 1 : 0

  deployment_name = var.deployment_name
  aws_region      = data.aws_region.current.region

  # Container image for Lambda
  container_uri = var.handler_config.container_uri

  # Primary orchestrator ARN from deployed agents
  primary_orchestrator_arn = module.agent[var.handler_config.primary_orchestrator_name].agent_runtime_arn

  # KMS key for SSM parameter decryption
  kms_key_arn = var.kms_key_arn

  # SSM parameter prefix
  ssm_parameter_prefix = var.handler_config.ssm_parameter_prefix

  # S3 bucket for docs, templates, inputs, outputs (enables /tra docs and /tra templates)
  object_store_bucket_arn = var.s3_bucket_arn

  # Optional VPC configuration
  vpc_config = var.handler_config.vpc_config

  # Lambda configuration
  lambda_timeout          = var.handler_config.lambda_timeout
  lambda_memory_size      = var.handler_config.lambda_memory_size
  provisioned_concurrency = var.handler_config.provisioned_concurrency

  # Tags
  tags = merge(
    {
      Deployment   = var.deployment_name
      System       = "TRA"
      Component    = "SlackHITL"
      HITLPlatform = "slack"
    },
    var.tags
  )

  # Ensure agents are deployed first
  depends_on = [module.agent]
}

###############################################################################
# Teams Handler Module
# Creates Lambda, API Gateway, and DynamoDB for Microsoft Teams handler workflow
###############################################################################

module "teams_handler" {
  source = "../teams_handler"
  count  = var.handler_platform == "teams" ? 1 : 0

  deployment_name = var.deployment_name
  aws_region      = data.aws_region.current.region

  # Container image for Lambda
  container_uri = var.handler_config.container_uri

  # Primary orchestrator ARN from deployed agents
  primary_orchestrator_arn = module.agent[var.handler_config.primary_orchestrator_name].agent_runtime_arn

  # KMS key for SSM parameter decryption
  kms_key_arn = var.kms_key_arn

  # SSM parameter prefix
  ssm_parameter_prefix = var.handler_config.ssm_parameter_prefix

  # Optional VPC configuration
  vpc_config = var.handler_config.vpc_config

  # Lambda configuration
  lambda_timeout     = var.handler_config.lambda_timeout
  lambda_memory_size = var.handler_config.lambda_memory_size

  # Tags
  tags = merge(
    {
      Deployment   = var.deployment_name
      System       = "TRA"
      Component    = "TeamsHITL"
      HITLPlatform = "teams"
    },
    var.tags
  )

  # Ensure agents are deployed first
  depends_on = [module.agent]
}
