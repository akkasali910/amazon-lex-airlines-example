#!/bin/bash

# Deploy Amazon Lex Airline Solution
# This script creates the resources defined in the CloudFormation template

set -e

# Default parameter values
BOT_NAME="AirlinesBot"
BUSINESS_LOGIC_FUNCTION_NAME="AirlinesBusinessLogic"
DYNAMODB_TABLE_NAME="Airlines_db"
CONTACT_FLOW_NAME="AirlinesContactFlow"
CONNECT_INSTANCE_ARN=""
STACK_NAME="AirlineSolution"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --bot-name)
      BOT_NAME="$2"
      shift 2
      ;;
    --function-name)
      BUSINESS_LOGIC_FUNCTION_NAME="$2"
      shift 2
      ;;
    --table-name)
      DYNAMODB_TABLE_NAME="$2"
      shift 2
      ;;
    --contact-flow-name)
      CONTACT_FLOW_NAME="$2"
      shift 2
      ;;
    --connect-instance-arn)
      CONNECT_INSTANCE_ARN="$2"
      shift 2
      ;;
    --stack-name)
      STACK_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
  echo "AWS Region not set, defaulting to $AWS_REGION"
fi

# Map region to S3 bucket name
case $AWS_REGION in
  us-east-1)
    BUCKET_NAME="lex-usecases-us-east-1"
    ;;
  us-west-2)
    BUCKET_NAME="lex-usecases-us-west-2"
    ;;
  eu-west-2)
    BUCKET_NAME="lex-usecases-eu-west-2"
    ;;
  eu-west-1)
    BUCKET_NAME="lex-usecases-eu-west-1"
    ;;
  eu-central-1)
    BUCKET_NAME="lex-usecases-eu-central-1"
    ;;
  ca-central-1)
    BUCKET_NAME="lex-usecases-ca-central-1"
    ;;
  ap-southeast-2)
    BUCKET_NAME="lex-usecases-ap-southeast-2"
    ;;
  ap-southeast-1)
    BUCKET_NAME="lex-usecases-ap-southeast-1"
    ;;
  ap-northeast-2)
    BUCKET_NAME="lex-usecases-ap-northeast-2"
    ;;
  ap-northeast-1)
    BUCKET_NAME="lex-usecases-ap-northeast-1"
    ;;
  af-south-1)
    BUCKET_NAME="lex-usecases-af-south-1"
    ;;
  *)
    echo "Unsupported region: $AWS_REGION"
    exit 1
    ;;
esac

# S3 paths for resources
LEX_IMPORT_SOURCE="travel/airlines/lex_import.zip"
DB_IMPORT_SOURCE="travel/airlines/db_import.zip"
BUSINESS_LOGIC_SOURCE="travel/airlines/lambda_import.zip"
CONNECT_IMPORT_SOURCE="travel/airlines/connect_import.zip"

# Create a directory to save the zip files
mkdir -p airline_files
echo "Downloading Lambda function zip files to airline_files directory..."
aws s3 cp s3://$BUCKET_NAME/$LEX_IMPORT_SOURCE airline_files/
aws s3 cp s3://$BUCKET_NAME/$DB_IMPORT_SOURCE airline_files/
aws s3 cp s3://$BUCKET_NAME/$BUSINESS_LOGIC_SOURCE airline_files/
aws s3 cp s3://$BUCKET_NAME/$CONNECT_IMPORT_SOURCE airline_files/

echo "Creating resources for Amazon Lex Airline Solution..."

# Create IAM roles
echo "Creating IAM roles..."

# Create LexRole
LEX_ROLE_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["lambda.amazonaws.com", "lex.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

LEX_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["polly:SynthesizeSpeech"],
      "Resource": "*"
    }
  ]
}'

LEX_ROLE_NAME="${STACK_NAME}_LexRole"
aws iam create-role --role-name $LEX_ROLE_NAME --assume-role-policy-document "$LEX_ROLE_POLICY_DOC"
aws iam put-role-policy --role-name $LEX_ROLE_NAME --policy-name "${STACK_NAME}_LexPolicy" --policy-document "$LEX_POLICY_DOC"
LEX_ROLE_ARN=$(aws iam get-role --role-name $LEX_ROLE_NAME --query 'Role.Arn' --output text)

# Create LambdaRole
LAMBDA_ROLE_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

LAMBDA_ROLE_NAME="${STACK_NAME}_LambdaRole"
aws iam create-role --role-name $LAMBDA_ROLE_NAME --assume-role-policy-document "$LAMBDA_ROLE_POLICY_DOC"
LAMBDA_ROLE_ARN=$(aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text)

# Create LexImportRole
LEX_IMPORT_ROLE_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

LEX_IMPORT_ROLE_NAME="${STACK_NAME}_LexImportRole"
aws iam create-role --role-name $LEX_IMPORT_ROLE_NAME --assume-role-policy-document "$LEX_IMPORT_ROLE_POLICY_DOC"
aws iam attach-role-policy --role-name $LEX_IMPORT_ROLE_NAME --policy-arn "arn:aws:iam::aws:policy/AmazonLexFullAccess"

LEX_IMPORT_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:PublishVersion",
        "lambda:AddPermission",
        "lambda:GetFunction",
        "sts:GetCallerIdentity",
        "iam:GetRole",
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:lex:'$AWS_REGION':'$AWS_ACCOUNT_ID':*",
        "arn:aws:iam::'$AWS_ACCOUNT_ID':role/*",
        "arn:aws:lex:'$AWS_REGION':'$AWS_ACCOUNT_ID':bot/*",
        "arn:aws:lex:'$AWS_REGION':'$AWS_ACCOUNT_ID':bot-alias/*",
        "arn:aws:lambda:'$AWS_REGION':'$AWS_ACCOUNT_ID':function:*"
      ]
    }
  ]
}'

aws iam put-role-policy --role-name $LEX_IMPORT_ROLE_NAME --policy-name "${STACK_NAME}_LexImportPolicy" --policy-document "$LEX_IMPORT_POLICY_DOC"
LEX_IMPORT_ROLE_ARN=$(aws iam get-role --role-name $LEX_IMPORT_ROLE_NAME --query 'Role.Arn' --output text)

# Create ConnectRole
CONNECT_ROLE_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

CONNECT_ROLE_NAME="${STACK_NAME}_ConnectRole"
aws iam create-role --role-name $CONNECT_ROLE_NAME --assume-role-policy-document "$CONNECT_ROLE_POLICY_DOC"
aws iam attach-role-policy --role-name $CONNECT_ROLE_NAME --policy-arn "arn:aws:iam::aws:policy/AmazonLexFullAccess"

CONNECT_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "connect:CreateContactFlow",
        "connect:AssociateBot",
        "connect:DescribeContactFlow",
        "connect:ListContactFlows",
        "iam:AddRoleToInstanceProfile",
        "iam:AddUserToGroup",
        "iam:AttachGroupPolicy",
        "iam:AttachRolePolicy",
        "iam:AttachUserPolicy",
        "iam:CreateInstanceProfile",
        "iam:CreatePolicy",
        "iam:CreateRole",
        "iam:CreateServiceLinkedRole",
        "iam:CreateUser",
        "iam:DetachGroupPolicy",
        "iam:DetachRolePolicy",
        "iam:DetachUserPolicy",
        "iam:GetGroup",
        "iam:GetGroupPolicy",
        "iam:GetInstanceProfile",
        "iam:GetLoginProfile",
        "iam:PutGroupPolicy",
        "iam:PutRolePolicy",
        "iam:PutUserPolicy",
        "iam:UpdateGroup",
        "iam:UpdateRole",
        "iam:UpdateUser",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:GetUser",
        "iam:GetUserPolicy",
        "iam:CreatePolicyVersion",
        "iam:SetDefaultPolicyVersion",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}'

aws iam put-role-policy --role-name $CONNECT_ROLE_NAME --policy-name "${STACK_NAME}_ConnectRole" --policy-document "$CONNECT_POLICY_DOC"
CONNECT_ROLE_ARN=$(aws iam get-role --role-name $CONNECT_ROLE_NAME --query 'Role.Arn' --output text)

# Create DynamoDB table
echo "Creating DynamoDB table..."
aws dynamodb create-table \
  --table-name $DYNAMODB_TABLE_NAME \
  --attribute-definitions \
    AttributeName=record_type_id,AttributeType=S \
    AttributeName=customer_id,AttributeType=S \
  --key-schema \
    AttributeName=customer_id,KeyType=HASH \
    AttributeName=record_type_id,KeyType=RANGE \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

# Wait for table to be created
aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE_NAME

# Enable point-in-time recovery
aws dynamodb update-continuous-backups \
  --table-name $DYNAMODB_TABLE_NAME \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

# Get DynamoDB table ARN
DYNAMODB_ARN=$(aws dynamodb describe-table --table-name $DYNAMODB_TABLE_NAME --query 'Table.TableArn' --output text)

# Update Lambda role policy with DynamoDB ARN
LAMBDA_POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DescribeTable",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "'$DYNAMODB_ARN'",
        "arn:aws:logs:*:*:*"
      ]
    }
  ]
}'

aws iam put-role-policy --role-name $LAMBDA_ROLE_NAME --policy-name "${STACK_NAME}_LambdaRolePolicy" --policy-document "$LAMBDA_POLICY_DOC"

# Create Lambda functions
echo "Creating Lambda functions..."

# Create temporary directory for Lambda code
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Create LexImportFunction
LEX_IMPORT_FUNCTION_NAME="${STACK_NAME}_LexImportFunction"
cp airline_files/lex_import.zip $TEMP_DIR/
aws lambda create-function \
  --function-name $LEX_IMPORT_FUNCTION_NAME \
  --runtime python3.9 \
  --role $LEX_IMPORT_ROLE_ARN \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$TEMP_DIR/lex_import.zip \
  --timeout 300 \
  --memory-size 128 \
  --environment "Variables={TopicArn=$LEX_ROLE_ARN}"

# Create DynamoDBImportFunction
DYNAMODB_IMPORT_FUNCTION_NAME="${STACK_NAME}_DynamoDBImportFunction"
cp airline_files/db_import.zip $TEMP_DIR/
aws lambda create-function \
  --function-name $DYNAMODB_IMPORT_FUNCTION_NAME \
  --runtime python3.9 \
  --role $LAMBDA_ROLE_ARN \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$TEMP_DIR/db_import.zip \
  --timeout 300 \
  --memory-size 128

# Create BusinessLogicFunction
cp airline_files/lambda_import.zip $TEMP_DIR/
aws lambda create-function \
  --function-name $BUSINESS_LOGIC_FUNCTION_NAME \
  --runtime python3.9 \
  --role $LAMBDA_ROLE_ARN \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$TEMP_DIR/lambda_import.zip \
  --timeout 300 \
  --memory-size 128 \
  --environment "Variables={dynamodb_tablename=$DYNAMODB_TABLE_NAME,databaseUser=admin}"

# Create ConnectImportFunction
CONNECT_IMPORT_FUNCTION_NAME="${STACK_NAME}_ConnectImportFunction"
cp airline_files/connect_import.zip $TEMP_DIR/
aws lambda create-function \
  --function-name $CONNECT_IMPORT_FUNCTION_NAME \
  --runtime python3.9 \
  --role $CONNECT_ROLE_ARN \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$TEMP_DIR/connect_import.zip \
  --timeout 300 \
  --memory-size 128

# Wait for Lambda functions to be ready
echo "Waiting for Lambda functions to be ready..."
sleep 20

# Wait for DynamoDB table to be fully available
echo "Waiting for DynamoDB table to be fully available..."
sleep 30

# Invoke DynamoDBImportFunction to populate the table
echo "Populating DynamoDB table with sample data..."
aws lambda invoke \
  --function-name $DYNAMODB_IMPORT_FUNCTION_NAME \
  --payload '{"TableName":"'$DYNAMODB_TABLE_NAME'"}' \
  --cli-binary-format raw-in-base64-out \
  $TEMP_DIR/output.json

# Invoke LexImportFunction to create the Lex bot
echo "Creating Amazon Lex bot..."
aws lambda invoke \
  --function-name $LEX_IMPORT_FUNCTION_NAME \
  --payload '{"RoleARN":"'$LEX_ROLE_ARN'","LambdaFunctionName":"'$BUSINESS_LOGIC_FUNCTION_NAME'","BotName":"'$BOT_NAME'"}' \
  --cli-binary-format raw-in-base64-out \
  $TEMP_DIR/lex_output.json

# Extract Lex bot ARN from output
LEX_BOT_ARN=$(cat $TEMP_DIR/lex_output.json | grep -o '"lex_arn": "[^"]*"' | cut -d'"' -f4)

if [ -z "$LEX_BOT_ARN" ]; then
  echo "Failed to extract Lex bot ARN from output. Check $TEMP_DIR/lex_output.json for details."
  cat $TEMP_DIR/lex_output.json
  exit 1
fi

echo "Lex bot ARN: $LEX_BOT_ARN"

# Add Lambda permission for Lex
echo "Adding Lambda permission for Lex..."
BUSINESS_LOGIC_FUNCTION_ARN=$(aws lambda get-function --function-name $BUSINESS_LOGIC_FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)
aws lambda add-permission \
  --function-name $BUSINESS_LOGIC_FUNCTION_ARN \
  --statement-id LexPermission \
  --action lambda:InvokeFunction \
  --principal lexv2.amazonaws.com \
  --source-arn $LEX_BOT_ARN

# Create Connect contact flow if Connect instance ARN is provided
if [ ! -z "$CONNECT_INSTANCE_ARN" ]; then
  echo "Creating Amazon Connect contact flow..."
  aws lambda invoke \
    --function-name $CONNECT_IMPORT_FUNCTION_NAME \
    --payload '{"BotAliasArn":"'$LEX_BOT_ARN'","ContactName":"'$CONTACT_FLOW_NAME'","ConnectInstanceARN":"'$CONNECT_INSTANCE_ARN'","BotName":"'$BOT_NAME'"}' \
    --cli-binary-format raw-in-base64-out \
    $TEMP_DIR/connect_output.json
fi

echo "Deployment complete!"
echo "Amazon Lex bot '$BOT_NAME' has been created"
echo "Sample customer data: https://lex-usecases-templates.s3.amazonaws.com/AirlinesBot_customer_data.html"

if [ ! -z "$CONNECT_INSTANCE_ARN" ]; then
  echo "Amazon Connect contact flow '$CONTACT_FLOW_NAME' has been created"
fi