# Variables for Log Retention Enforcer Module

variable "deployment_name" {
  description = "Name of the deployment (used for resource naming)"
  type        = string
}

variable "log_group_prefix" {
  description = "Prefix for log groups to monitor (e.g., '/aws/bedrock-agentcore/runtimes/')"
  type        = string
  default     = "/aws/bedrock-agentcore/runtimes/"
}

variable "retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.retention_days)
    error_message = "retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
