terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.62.0"
    }
  }
}

locals {
  cloud  = var.cloud_provider
  region = var.cloud_region
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

data "confluent_organization" "main" {}

// Single environment 
data "confluent_environment" "dev" {
  id = var.environment_id
}


data "confluent_service_account" "statements_runner" {
  id = var.statements_runner_service_account_id
}



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


data "confluent_flink_compute_pool" "main" {
  id = var.compute_pool_id
  environment {
    id = data.confluent_environment.dev.id
  }
}


resource "confluent_flink_statement" "ct-customers-pk2" {
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

  // statements-runner Service Account 
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
  statement = file("./sql/ct-customers-pk2.sql")

}

resource "confluent_flink_statement" "ct-customers-faker2" {
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
  statement = file("./sql/ct-customer-faker2.sql")
}



resource "confluent_flink_statement" "insert-into-customers-pk2" {
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
  statement = file("./sql/insert-into-customers-pk2.sql")

  depends_on = [confluent_flink_statement.ct-customers-pk2, confluent_flink_statement.ct-customers-faker2]
}
