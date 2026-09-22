# Wind Turbine Anomaly Detection: End-to-End AWS Production ETL Pipeline

A production-grade, event-driven data pipeline that ingests wind turbine sensor
readings, applies a medallion architecture (Bronze to Silver to Gold) using PySpark,
detects power output anomalies, and stores results in Amazon RDS PostgreSQL and S3
Parquet. All infrastructure is provisioned with Terraform and destroyable with one command.

---

## Architecture

    Local Downloads/
          |
          |  downloads_to_s3.py (laptop agent)
          v
    S3 landing/
          |
          |  EventBridge (Object Created)
          v
    AWS Lambda: ingest_trigger
      - Validates file headers
      - Unpacks zip to raw CSVs
      - Moves original to archive/ or quarantine/ if invalid
      - Starts Glue job or queues a rerun if already running
          |
          v
    S3 raw/ (validated CSVs)
          |
          |  AWS Glue 5.0 PySpark runs unmodified main.py
          v
    Medallion Architecture
      Bronze -> Silver -> Gold
          |
          |-- S3 curated/latest/ (Parquet)
          +-- RDS PostgreSQL
                - Processed_data
                - gold_summary_statistics
                - gold_anomalies
          |
          v
    AWS Lambda: post_run + SNS alerts

Alternative compute: the same main.py runs unchanged on Amazon EMR.

---

## Technologies

| Layer          | Technology                                        |
|----------------|---------------------------------------------------|
| Processing     | PySpark (AWS Glue 5.0 / Amazon EMR 7.5)          |
| Orchestration  | AWS Lambda (Python 3.12), Amazon EventBridge      |
| Storage        | Amazon S3 (data lake), RDS PostgreSQL db.t3.micro |
| Infrastructure | Terraform 1.10+ (10 reusable modules)             |
| Alerting       | Amazon SNS                                        |
| Secrets        | AWS Secrets Manager                               |
| Networking     | VPC, private subnets, VPC endpoints, bastion EC2  |
| DB client      | DBeaver via SSH tunnel through bastion            |
| Local agent    | Python boto3 uploader script                      |

---

## Repository Structure

    wind_turbine_challenge_2026/
    |-- main.py                     Pipeline entry point (local or AWS)
    |-- requirements.txt
    |-- .env                        Local DB credentials (gitignored)
    |-- src/
    |   |-- ingestion/ingest.py     Unzips source data, reads CSVs
    |   |-- pipelines/
    |   |   |-- bronze.py           Lands raw files, adds metadata
    |   |   |-- silver.py           Cleans data, writes to Parquet + PostgreSQL
    |   |   +-- gold.py             Summary statistics + anomaly detection
    |   |-- processing/
    |   |   |-- cleaning.py         Dedup, null handling, imputation
    |   |   |-- statistics.py       Windowed min/max/avg/stddev per turbine
    |   |   +-- anomaly.py          2-stddev anomaly detection per turbine
    |   +-- utils/
    |       |-- config.py           Central config: paths, thresholds, DB
    |       +-- helpers.py          Shared write and metadata utilities
    |-- aws_dropin/                 AWS adapter layer (src/ unchanged)
    |   |-- glue/aws_entrypoint.py  Glue/EMR entry: calls main.main()
    |   |-- lambda/
    |   |   |-- ingest_trigger/     Validates files, starts Glue
    |   |   |-- post_run/           Starts queued reruns
    |   |   +-- snowflake_loader/   Optional Snowflake loader
    |   |-- local_agent/            Watches Downloads/, uploads to S3
    |   |-- emr/                    EMR bootstrap + launcher
    |   |-- snowflake/setup.sql     One-time Snowflake setup
    |   +-- scripts/build.sh        Packages app.zip + wheels
    +-- terraform-wind-turbine/
        |-- Makefile               make bootstrap, apply, destroy
        |-- bootstrap/             Creates S3 state bucket (run once)
        |-- environments/dev/      Dev environment root
        +-- modules/
            |-- network/           VPC, subnets, endpoints, bastion
            |-- storage/           S3 data lake + scripts bucket
            |-- database/          RDS PostgreSQL + credentials secret
            |-- alerting/          SNS topic + email subscription
            |-- artifacts/         Uploads app.zip, wheels to S3
            |-- glue_pipeline/     Glue job, IAM role, VPC connection
            |-- orchestration/     Lambda + EventBridge rules
            |-- snowflake_loader/  Optional Snowflake loader Lambda
            |-- uploader/          IAM user for laptop uploader
            +-- emr/              Optional EMR roles + security groups

---

## Part 1: Run Locally

### Prerequisites

- Python 3.12+
- Java (required by PySpark): check with java -version
- PostgreSQL 16+
- Git

### 1. Clone the repository

    git clone https://github.com/ifistic/end_to_end_aws_prod_etl_WindTurbine_Project.git
    cd end_to_end_aws_prod_etl_WindTurbine_Project

### 2. Create and activate a virtual environment

    python3 -m venv project_venv
    source project_venv/bin/activate

### 3. Install Python dependencies

    pip install -r requirements.txt

### 4. Install and start PostgreSQL

    sudo apt install postgresql
    sudo systemctl start postgresql
    sudo -u postgres createdb wind_turbine_db
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"

### 5. Configure environment variables

Create a .env file in the project root:

    POSTGRES_HOST=localhost
    POSTGRES_PORT=5432
    POSTGRES_DB=wind_turbine_db
    POSTGRES_USER=postgres
    POSTGRES_PASSWORD=postgres

### 6. Add raw data

Place data.zip containing data_group_1.csv, data_group_2.csv and
data_group_3.csv into your ~/Downloads/ folder.

### 7. Run the pipeline

    python main.py

This runs all stages and writes:
- Parquet files to data/bronze/, data/silver/, data/gold/
- Tables to PostgreSQL: Processed_data, gold_summary_statistics, gold_anomalies

### 8. Query locally

    psql -h localhost -U postgres -d wind_turbine_db

    SELECT COUNT(*) FROM "Processed_data";
    SELECT COUNT(*) FROM gold_anomalies;
    SELECT turbine_id, COUNT(*) FROM gold_anomalies GROUP BY turbine_id ORDER BY 1;

---

## Part 2: Deploy to AWS

### Prerequisites

- AWS account with an IAM admin user (not root)
- AWS CLI v2 installed and configured
- Terraform 1.10+
- Python 3.x

### Step 1: Bootstrap remote state (run once only)

    cd terraform-wind-turbine
    terraform -chdir=bootstrap init
    terraform -chdir=bootstrap apply

This writes environments/dev/backend.hcl automatically.

### Step 2: Create EC2 key pair for bastion SSH

    aws ec2 create-key-pair \
      --key-name wind-turbine-bastion \
      --query KeyMaterial \
      --output text \
      --profile YOUR_ADMIN_PROFILE > ~/.ssh/wind-turbine-bastion.pem

    chmod 400 ~/.ssh/wind-turbine-bastion.pem

### Step 3: Get your public IP

    curl https://checkip.amazonaws.com

### Step 4: Configure your environment

    cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
    nano environments/dev/terraform.tfvars

Set these values:

    alert_email       = "your@email.com"
    create_bastion    = true
    bastion_key_name  = "wind-turbine-bastion"
    my_ip_cidr        = "YOUR_IP/32"
    db_instance_class = "db.t3.micro"

### Step 5: Build artefacts

    bash aws_dropin/scripts/build.sh

### Step 6: Deploy all infrastructure

    cd environments/dev
    terraform init -backend-config=backend.hcl
    terraform apply

Type yes when prompted. RDS takes about 6 minutes. Outputs at the end:

    bastion_public_ip      = x.x.x.x
    data_lake_bucket       = wind-turbine-pipeline-xxxxxxxx
    rds_endpoint           = wind-turbine-pipeline-dev.xxxx.eu-west-2.rds.amazonaws.com:5432
    glue_pipeline_job_name = wind-turbine-pipeline-pipeline
    uploader_access_key_id = AKIAxxxxxxxxxxxxxxxx

### Step 7: Configure the laptop uploader

    terraform output -raw uploader_secret_access_key
    aws configure --profile turbine-uploader

Enter the access key ID from Terraform output and the secret key from above.
Region: eu-west-2. Output format: json.

### Step 8: Confirm SNS email subscription

Check your email for an AWS notification and click Confirm subscription.
Without this you will not receive pipeline alerts.

### Step 9: Run the pipeline

Place data.zip in ~/Downloads/ then:

    AWS_PROFILE=turbine-uploader python3 aws_dropin/local_agent/downloads_to_s3.py \
      --bucket YOUR_DATA_LAKE_BUCKET \
      --once

This uploads to S3 landing/ and triggers the full pipeline automatically.

### Step 10: Monitor

    aws glue get-job-runs \
      --job-name wind-turbine-pipeline-pipeline \
      --max-results 1 \
      --query 'JobRuns[0].{Status:JobRunState,Started:StartedOn,Completed:CompletedOn}' \
      --profile YOUR_ADMIN_PROFILE

The Glue job takes about 3 minutes. You will receive an email when it completes.

---

## Connecting DBeaver to RDS via SSH Tunnel

RDS is in a private subnet with no public IP. DBeaver connects through
the bastion EC2 instance using an SSH tunnel.

### Get the RDS password

    aws secretsmanager get-secret-value \
      --secret-id wind-turbine-pipeline/dev/db-credentials \
      --query SecretString \
      --output text \
      --profile YOUR_ADMIN_PROFILE

### DBeaver Main tab

| Field    | Value                                          |
|----------|------------------------------------------------|
| Host     | rds_endpoint value without the :5432           |
| Port     | 5432                                           |
| Database | wind_turbine_db                                |
| Username | postgres                                       |
| Password | password from the secretsmanager command above |

### DBeaver SSH tab: tick Use SSH tunnel

| Field          | Value                             |
|----------------|-----------------------------------|
| Host/IP        | bastion_public_ip from tf output  |
| Port           | 22                                |
| Username       | ec2-user                          |
| Authentication | Public Key                        |
| Private key    | ~/.ssh/wind-turbine-bastion.pem   |
| Passphrase     | leave blank                       |

Untick Use SSL on the SSL tab. Click Test Connection.

### Useful SQL queries

    -- All tables
    SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

    -- Cleaned readings count
    SELECT COUNT(*) FROM "Processed_data";

    -- Anomaly count per turbine
    SELECT turbine_id, COUNT(*) AS anomaly_count
    FROM gold_anomalies GROUP BY turbine_id ORDER BY turbine_id;

    -- Daily summary statistics
    SELECT turbine_id, window_start, avg_power_mw, stddev_power_mw
    FROM gold_summary_statistics ORDER BY turbine_id, window_start;

    -- Anomalous readings
    SELECT turbine_id, timestamp, power_output, mean_power_mw,
           lower_bound_mw, upper_bound_mw
    FROM gold_anomalies WHERE is_anomaly = true
    ORDER BY turbine_id, timestamp LIMIT 20;

---

## S3 Output Structure

    s3://wind-turbine-pipeline-xxxxxxxx/
    |-- landing/      files uploaded from laptop
    |-- archive/      originals after successful processing
    |-- quarantine/   files rejected for invalid headers
    |-- raw/          validated CSVs input to every Glue run
    |-- control/      rerun marker
    +-- curated/
        |-- runs/run_id/bronze/ silver/ gold/
        +-- latest/bronze/ silver/ gold/anomalies/ summary_statistics/

---

## Running on EMR: Alternative to Glue

The same main.py runs unchanged on Amazon EMR.

    # Enable EMR in terraform.tfvars
    enable_emr = true

    # Apply to create NAT gateway, EMR roles and security groups
    cd terraform-wind-turbine/environments/dev
    terraform apply

    # Launch a self-terminating EMR cluster
    bash aws_dropin/emr/run_on_emr.sh

Wait for TERMINATED before destroying:

    aws emr list-clusters --active --profile YOUR_ADMIN_PROFILE

---

## Destroying All Resources

    cd terraform-wind-turbine/environments/dev
    terraform destroy

All AWS resources are removed. The S3 state bucket survives so you can rebuild.

Rebuild at any time in about 8 minutes:

    bash aws_dropin/scripts/build.sh
    cd terraform-wind-turbine/environments/dev
    terraform apply

---

## Cost Estimate: eu-west-2

| Resource                            | Cost per month running 24/7 |
|-------------------------------------|-----------------------------|
| RDS db.t3.micro                     | ~15 USD                     |
| VPC Interface Endpoints x2 x2 AZ   | ~29 USD                     |
| EC2 t3.nano bastion                 | ~4 USD                      |
| S3, Lambda, EventBridge, SNS        | ~1 USD                      |
| Glue job                            | 0 USD idle, 0.44/DPU-hr/run |
| Total                               | ~49 USD per month           |

Run terraform destroy when not using the project. Costs drop to zero.
Rebuild with terraform apply in about 8 minutes when needed.

---

## Pipeline Design Notes

### Why PySpark
PySpark native F.window() maps directly onto the 24-hour period requirement
for summary statistics and anomaly detection. Scales beyond the current
dataset without a rewrite.

### Why Medallion Architecture
Keeping raw, cleaned and aggregated data in separate layers means each stage
is independently inspectable and re-runnable. A bug in aggregation logic never
risks corrupting the underlying cleaned data.

### Why the Same Code Runs on Glue and EMR
aws_entrypoint.py recreates the local environment inside AWS:
1. Downloads app.zip containing main.py and src/ from S3
2. Reads RDS credentials from Secrets Manager, exports as POSTGRES_* env vars
3. Downloads CSVs from S3 raw/ to local /tmp/raw_data/
4. Pre-creates a local Spark session
5. Calls main.main() so your code never knows it is in AWS
6. Uploads data/bronze, silver and gold back to S3

### Anomaly Detection
Per turbine per 24-hour window. A reading is flagged if it falls outside
mean plus or minus 2 times stddev for that turbine on that day.
Configurable via ANOMALY_STD_THRESHOLD in src/utils/config.py.

### Cleaning Strategy
Missing values are imputed using the per-turbine mean rather than a global mean
because different turbines have different output profiles. Imputed rows are
flagged with is_imputed = true so downstream consumers can filter them.

---

## Troubleshooting

| Problem                                  | Fix                                                         |
|------------------------------------------|-------------------------------------------------------------|
| ModuleNotFoundError: No module named src | Run from project root: python main.py                       |
| FATAL: password authentication failed    | Check .env matches your PostgreSQL password                 |
| DBeaver Read timed out                   | Check RDS status in the AWS console                         |
| DBeaver Connection timed out             | IP changed: update my_ip_cidr in terraform.tfvars and apply |
| Glue job FAILED                          | Check CloudWatch: /aws-glue/jobs/wind-turbine-pipeline      |
| SignatureDoesNotMatch in uploader        | Reconfigure: aws configure --profile turbine-uploader       |
| File goes to quarantine                  | CSV must have: timestamp, turbine_id, wind_speed, wind_direction, power_output |
| Secret already scheduled for deletion    | aws secretsmanager delete-secret --secret-id wind-turbine-pipeline/dev/db-credentials --force-delete-without-recovery then re-apply |
