# Outputs for AgentCore Agent Module

output "agent_runtime_id" {
  description = "The unique identifier of the agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_id
}

output "agent_runtime_arn" {
  description = "The ARN of the agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_arn
}

output "agent_runtime_name" {
  description = "The name of the agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_name
}

output "agent_runtime_version" {
  description = "The version of the agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.agent.agent_runtime_version
}

output "workload_identity_arn" {
  description = "The ARN of the workload identity associated with the agent runtime"
  value       = try(aws_bedrockagentcore_agent_runtime.agent.workload_identity_details[0].workload_identity_arn, null)
}

output "container_uri" {
  description = "The full container URI used by the agent runtime"
  value       = var.container_uri
}

output "endpoints" {
  description = "Map of endpoint details for this agent runtime"
  value = {
    for k, v in aws_bedrockagentcore_agent_runtime_endpoint.endpoint : k => {
      name                       = v.name
      agent_runtime_endpoint_arn = v.agent_runtime_endpoint_arn
      agent_runtime_arn          = v.agent_runtime_arn
      agent_runtime_version      = v.agent_runtime_version
    }
  }
}
