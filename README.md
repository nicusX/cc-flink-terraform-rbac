# Confluent Cloud Flink - Example of RBAC for Flink Statement Management with Terraform

This example shows a simple setup deploying Flink statements with Terraform without using
all-powerful Confluent Cloud API Keys for the deployment. 
The setup uses API keys associated with separate Service Accounts with more limited permissions.


## Prerequisites

The Terraform code does not create the required Clusters, Flink Compute Pools, Service Accounts, and Keys. 
In most real scenarios, these resources are created by "someone else" (e.g. a Platform Team) and handed to the team managing the Flink statements.

> You can use the UI, CLI, or Terraform to create these resources beforehand. Their creation is out of scope of this example. 

### Confluent Cloud Resources

You need the following resources, all in the same Confluent Cloud Environment.

* A Kafka cluster
* A Flink Compute Pool, in the same cloud provider and region as the cluster


### Service Accounts

Create these 3 Service Accounts, with the associated roles and scopes.

1. Service Account: `platform-manager` - associated with the Confluent Cloud API used by Terraform. 
      - Role: *FlinkAdmin*, Resource: `<environment>`
      - Role: *ResourceOwner*, Resource: `<cluster>` - Topics: All topics
2. Service Account: `app-manager` - used by Terraform to manage the Flink statements.
      - Role: *FlinkDeveloper*, Resource: `<environment>`
      - Role: *FlinkFunctionDeveloper*, Resource: `<environment>` (for UDFs)
      - Role: *FlinkDeveloper*, Resource: `<compute-pool>`
      - Role: *ResourceOwner*, Resource: `<cluster>` - Topics: All topics
      - Role: *ResourceOwner*, Resource: `<environment>` - Schema: All schema subjects
      - Role: *ResourceOwner*, Resource: `<cluster>` - Transactions: prefix `_confluent-flink_`
      - Role-binding: *Assigner* to Service Account `statements-runner`
3. Service Account: `statements-runner` - used as Principal of the Flink statements.
      - Role: *FlinkDeveloper*, Resource: `<compute-pool>` (or `<environment>`)
      - Role: *DeveloperRead*, Resource: `<cluster>` - Topics: All topics
      - Role: *DeveloperWrite*, Resource: `<cluster>` - Topics: All topics
      - Role: *DeveloperRead*, Resource: `<cluster>` - Transactions: prefix `_confluent-flink_`
      - Role: *DeveloperWrite*, Resource: `<cluster>` - Transactions: prefix `_confluent-flink_`
      - Role: *DeveloperManage*, Resource: `<cluster>` - Topics: All topics
      - Role: *DeveloperWrite*, Resource: `<cluster>` - Schema: All schema subjects

> ℹ️ The "all topics" and "all schema" scopes can be reduced using naming conventions and specifying prefixes to the topic names.

#### How to add the Assigner role to `app-manager`

⚠️ At the moment, the UI does not support adding an Assigner role to a Service Account. You can use the CLI instead. The role-binding is also only visible via CLI.


```shell
## Add Assigner role to app-manager service account
confluent iam rbac role-binding create \
  --principal "User:<app-manager-sa-id>" \
  --role Assigner \
  --resource "service-account:<statements-runner-sa-id>" 

## Verify role-binding is set
confluent iam rbac role-binding list --principal "User:<app-manager-sa-id>"  
```

Replace `<app-manager-sa-id>` and `<statements-runner-sa-id>` with the IDs of the `app-manager` and `statements-runner` Service Accounts, respectively. 


### API Keys

Create the following API keys:

* Cloud Resource Management Key associated with the `platform-manager` Service Account. 
  This is the Confluent Cloud API key passed to Terraform.
* Flink region API key associated with the `app-manager` Service Account, scoped to the same Environment and Region.


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

## Resources created by Terraform

The goal of this project is to demonstrate the deployment of multiple statements, including `CREATE TABLE` and long-running jobs (`INSERT INTO`...).

* `customers_faker2` table : a "faker" table to generate data; not associated with any topic.
* `customers_pk2` table : a normal Flink table, with an associated schema and topic.
* An `INSERT INTO...` statement which copies data into `customers_pk2`. This is the only statement which will be running after Terraform has finished.  


## Known limitations


### Destroying tables

The tables created via `CREATE TABLE` statements are not destroyed when the corresponding statement is destroyed.

If you need to destroy and recreate a table, you need to run a `DROP TABLE` statement, for example using the CLI.

Note that, if you delete the topic instead, you also need to manually delete the associated schema.
Also, there is no topic associated with "virtual" tables like faker tables.

### CTAS (`CREATE TABLE AS SELECT`) statements vs `CREATE TABLE` + `INSERT INTO`


A CTAS (`CREATE TABLE AS SELECT`) would have the same problem as `CREATE TABLE`: if you make any changes to the statement and apply the change, submitting the new statement will fail because the table already exists.
Conversely, `INSERT INTO` statements can be destroyed and re-created by Terraform if the statement changes. 

For this reason, when using Terraform, it is more convenient to use two separate `CREATE TABLE` and `INSERT INTO` statements instead of a single CTAS statement.

### Similar permissions for `app-manager` and `statements-runner`

You may have noticed that the `app-manager` and `statements-runner` require similar permissions. 
This reduces the actual separation of concerns between the Service Account used to create the statements and the Service Account used to operate them (start, stop, ...). 

To simplify the setup, you may merge `app-manager` and `statements-runner`.

### Carry-over Offset in Terraform

To use [Carry-over Offsets](https://docs.confluent.io/cloud/current/flink/operate-and-deploy/carry-over-offsets.html), you need to specify the ID of the old statement when you deploy a new statement to replace the old one.

The Terraform provider does not support Carry-over Offset when you replace a statement.

Instead, you need to create different versions of the statement, as separate resources, and use the workaround described in [CLI-3621: Terraform Flink provider and flink enforcement rules mismatch - flink-carry-over-offset-between-statements](https://github.com/confluentinc/terraform-provider-confluent/issues/687).
