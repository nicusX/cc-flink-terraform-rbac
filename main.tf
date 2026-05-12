terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.72.0"
    }
  }
}

locals {
  cloud  = var.cloud_provider
  region = var.cloud_region
}

# Use the Cloud Resource Management Key credentials
provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# Get the Organization based on the Cloud Resource Management Key
data "confluent_organization" "main" {}

// Single environment 
data "confluent_environment" "dev" {
  id = var.environment_id
}

# statement-runner Service Account
data "confluent_service_account" "statements_runner" {
  id = var.statements_runner_service_account_id
}


# Get the Kafka Cluster - must already exists
data "confluent_kafka_cluster" "main" {
  id = var.kafka_cluster_id
  environment {
    id = var.environment_id
  }
}


data "confluent_flink_region" "main" {
  cloud  = local.cloud
  region = local.region
}


# Get the Compute Pool - must already exists
data "confluent_flink_compute_pool" "main" {
  id = var.compute_pool_id
  environment {
    id = data.confluent_environment.dev.id
  }
}

# Statement: CREATE TABLE customers-pk
resource "confluent_flink_statement" "ct-customers-pk" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = data.confluent_environment.dev.id
  }
  compute_pool {
    id = data.confluent_flink_compute_pool.main.id
  }
  rest_endpoint = data.confluent_flink_region.main.rest_endpoint

  // Principal (statement owner): statements-runner Service Account 
  principal {
    id = data.confluent_service_account.statements_runner.id
  }

  // Use the Flink Region Key credentials to create the statement
  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  // Catalog and Database are the Environment and Kafka cluster, respectively
  properties = {
    "sql.current-catalog"  = data.confluent_environment.dev.display_name
    "sql.current-database" = data.confluent_kafka_cluster.main.display_name
  }

  statement = file("./sql/ct-customers-pk.sql")
}

# Statement: CREATE TABLE customers_faker
resource "confluent_flink_statement" "ct-customers-faker" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = data.confluent_environment.dev.id
  }
  compute_pool {
    id = data.confluent_flink_compute_pool.main.id
  }
  rest_endpoint = data.confluent_flink_region.main.rest_endpoint

  principal {
    id = data.confluent_service_account.statements_runner.id
  }

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  properties = {
    "sql.current-catalog"  = data.confluent_environment.dev.display_name
    "sql.current-database" = data.confluent_kafka_cluster.main.display_name
  }

  statement = file("./sql/ct-customer-faker.sql")
}


# Statement: INSERT INTO customers-pk FROM SELECT customer-faker
resource "confluent_flink_statement" "insert-into-customers-pk" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = data.confluent_environment.dev.id
  }
  compute_pool {
    id = data.confluent_flink_compute_pool.main.id
  }
  rest_endpoint = data.confluent_flink_region.main.rest_endpoint

  principal {
    id = data.confluent_service_account.statements_runner.id
  }

  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }

  properties = {
    "sql.current-catalog"  = data.confluent_environment.dev.display_name
    "sql.current-database" = data.confluent_kafka_cluster.main.display_name
  }
  statement = file("./sql/insert-into-customers-pk.sql")

  // This statement depends on both creating customers-pk and customers-faker
  depends_on = [confluent_flink_statement.ct-customers-pk, confluent_flink_statement.ct-customers-faker]
}
