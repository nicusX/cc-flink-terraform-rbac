variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID) with EnvironmentAdmin and AccountAdmin roles provided by Kafka Ops team"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "flink_api_key" {
  description = "Flink API key"
  type        = string
  sensitive   = true
}

variable "flink_api_secret" {
  description = "Flink API secret"
  type        = string
  sensitive   = true
}

variable "environment_id" {
  description = "The ID of the managed environment"
  type        = string
}

variable "statements_runner_service_account_id" {
  description = "statements-runner Service Account ID"
  type        = string
}

variable "compute_pool_id" {
  description = "Flink Compute Pool ID"
  type        = string
}

variable "kafka_cluster_id" {
  description = "Kafka Cluster ID"
  type        = string
}

variable "cloud_provider" {
  description = "Cloud provider"
  type        = string
  default     = "AWS"
}

variable "cloud_region" {
  description = "Cloud Provider region for Confluent Cloud resources"
  type        = string
  default     = "eu-west-1"
}
