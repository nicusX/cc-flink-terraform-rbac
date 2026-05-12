# Confluent Cloud Flink - Example of RBAC for Flink Statement Management with Terraform

This example shows a simple setup deploying Flink statements with Terraform without using
all-powerful Confluent Cloud API Keys for the deployment. 
The setup uses API keys associated with separate Service Accounts with more limited permissions.


## Prerequisites

The Terraform code does not create the required Kafka Clusters, Flink Compute Pools, Service Accounts (with the required roles), and API Keys. 
In most real scenarios, these resources are created by "someone else" (e.g. a Platform Team) and handed to the team managing the Flink statements.

Creating these resources is out of scope for this example.

### Confluent Cloud Resources

You need the following resources, all in the same Confluent Cloud Environment.

* A Kafka cluster
* A Flink Compute Pool, in the same cloud provider and region as the cluster


### Service Accounts

Create these 3 Service Accounts, with the associated roles and scopes.

1. Service Account: `platform-manager` - associated with the Confluent Cloud API used by Terraform. 
2. Service Account: `app-manager` - used by Terraform to manage the Flink statements.
3. Service Account: `statements-runner` - the Principal of the Flink statements. It determines the permissions inherited by the statements.


#### Permissions

Roles required for each of the Service Accounts. 
Refer to [Grant Role-Based Access in Confluent Cloud for Apache Flink](https://docs.confluent.io/cloud/current/flink/operate-and-deploy/flink-rbac.html) public documentation for explanation of each role.

1. Service Account: `platform-manager`
      - Role: *FlinkAdmin*, Resource: Env = `<environment>`
      - Role: *ResourceOwner*, Resource: Kafka cluster =  `<cluster>`, Topics = `*` (All topics in the Kafka cluster)
2. Service Account: `app-manager`
      - Role: *FlinkDeveloper*, Resource: Compute Pool = `<compute-pool>` (or Env = `<environment>`, for all Compute Pools in the Environment)
      - Role: *ResourceOwner*, Resource: Kafka cluster = `<cluster>`, Topics = `*` (All topics) 
      - Role: *ResourceOwner*, Resource: Kafka cluster = `<cluster>`, Transactions = `_confluent-flink_*` (All transactions with prefix `_confluent-flink_`)
      - Role: *ResourceOwner*, Resource: Env = `<environment>`, Schema Subjects = `*` (All subjects in the Schema Registry of the Environment)
      - Role: *Assigner*, Principal: Service Account = `statements-runner`
3. Service Account: `statements-runner`
      - Role: *FlinkDeveloper*, Resource: Compute Pool = `<compute-pool>` (or Env = `<environment>`)
      - Role: *DeveloperRead*, Resource: Kafka cluster = `<cluster>`, Topics = `*` (All topics) 
      - Role: *DeveloperWrite*, Resource: Kafka cluster = `<cluster>`, Topics = `*` (All topics) 
      - Role: *DeveloperRead*, Resource: Kafka cluster = `<cluster>`, Transactions = `_confluent-flink_*` (All transactions with this prefix)
      - Role: *DeveloperWrite*, Resource: Kafka cluster = `<cluster>`, Transactions = `_confluent-flink_*` (All transactions with this prefix)
      - Role: *DeveloperManage*, Resource: Kafka cluster = `<cluster>`, Topics = `*` (All topics) 
      - Role: *DeveloperWrite*, Resource: Env = `<environment>`, Schema Subjects = `*` (All subjects)

> ℹ️ The "all topics" and "all schema" scopes can be reduced using naming conventions and specifying prefixes to the topic names.

> The roles *DeveloperManage* on all topics, and *DeveloperWrite* on all Schema Registry subjects assigned to `statements-runner` are required only to execute `CREATE TABLE` statements. If you do not have any `CREATE TABLE` statement you can omit them.

> ⚠️ Setting the *Assigner* role in the UI works the other way around: you go to the Access details of `statements-runner` (the target, not the assigner), select "+ Add role assignment", select the `app-manager` Service Account and the role *Assigner*.

### API Keys

Create the following API keys:

1. A *Cloud Resource Management Key* associated with the `platform-manager` Service Account. This is the Confluent Cloud API key passed to Terraform.
2. A *Flink region API Key* associated with the `app-manager` Service Account, scoped to the same Environment and the cloud region of the Compute Pool.


## Passing parameters to Terraform

The Terraform project expects the following variables:

```yaml
## Cloud Resource Management key associated with platform-manager
confluent_cloud_api_key    = "<key>"
confluent_cloud_api_secret = "<secret>"

## Flink API key associated with app-manager 
flink_api_key              = "<key>"
flink_api_secret           = "<secret>"

## Statements-runner ID (e.g. sa-123abcd)
statements_runner_service_account_id = "<sa-id>"

## Environment ID (e.g. env-abc123)
environment_id             = "<env-id>"

## Flink Compute Pool ID (e.g. lfcp-abc123)
compute_pool_id            = "<lfcp-id>"

## Kafka Cluster ID (e.g. lkc-123abc)
kafka_cluster_id           = "<lkc-id>"

## Cloud provider (default: "AWS")
cloud_provider             = "<cloud>"

## Cloud region (default: "eu-west-1")
cloud_region               = "<region>"
```

## Resources created by this Terraform code

The goal of this project is to demonstrate the deployment of multiple statements, including `CREATE TABLE` and long-running jobs (`INSERT INTO`...).

* `customers_faker` table : a "faker" table to generate data; not associated with any topic.
* `customers_pk` table : a normal Flink table, with an associated schema and topic.
* An `INSERT INTO...` statement which copies data into `customers_pk`. This is the only statement which will be running after Terraform has finished.  


## Materialized Tables

TODO

## Known limitation of the Terraform Provider

### Destroying tables

Terraform handles a SQL statement as a *resource*, not a Flink Table.

If you create a `CREATE TABLE` statement, this will run, create the table, and stop when completed.
Deleting the statement will only delete the stopped statement. It will not affect the table.

To delete the table you need to run a separate `DROP TABLE` statement, for example using the CLI.

Note that, if topic and schema are created externally from Flink you do not need to run any `CREATE TABLE` statement. However, you may still need an `ALTER TABLE` statement to configure metadata not derivable from the schema, like watermarks.


### CTAS (`CREATE TABLE AS SELECT`) statements vs `CREATE TABLE` + `INSERT INTO`

A CTAS (`CREATE TABLE AS SELECT`) would have the same problem as `CREATE TABLE`: if you make any changes to the statement and apply the change, submitting the new statement will fail because the table already exists.
Conversely, `INSERT INTO` statements can be destroyed and re-created by Terraform if the statement changes. 

With Terraform, you should separate `CREATE TABLE` and `INSERT INTO` into different statements.

### Carry-over Offset in Terraform

To use [Carry-over Offsets](https://docs.confluent.io/cloud/current/flink/operate-and-deploy/carry-over-offsets.html), you need to specify the ID of the old statement when you deploy a new statement to replace the old one.

The Terraform provider does not support Carry-over Offset when you replace a statement.

Instead, you need to create different versions of the statement, as separate resources, and use the workaround described in [CLI-3621: Terraform Flink provider and flink enforcement rules mismatch - flink-carry-over-offset-between-statements](https://github.com/confluentinc/terraform-provider-confluent/issues/687).

