#!/bin/bash
# delete_airline_resources.sh - Delete all resources created for the airline solution

# Set your stack name
STACK_NAME="Airlines"
REGION=$(aws configure get region || echo "eu-west-1")

# If you deployed using CloudFormation, you can delete everything with:
if aws cloudformation describe-stacks --stack-name $STACK_NAME &>/dev/null; then
  echo "Deleting CloudFormation stack: $STACK_NAME"
  aws cloudformation delete-stack --stack-name $STACK_NAME
  echo "Stack deletion initiated. Check AWS Console for progress."
  exit 0
fi

# If you deployed manually, delete resources individually:
echo "Deleting resources manually..."

# Get resource names
BOT_NAME="AirlinesBot"
BUSINESS_LOGIC_FUNCTION_NAME="AirlinesBusinessLogic"
DYNAMODB_TABLE_NAME="Airlines_db"
LEX_IMPORT_FUNCTION_NAME="${STACK_NAME}_LexImportFunction"
DYNAMODB_IMPORT_FUNCTION_NAME="${STACK_NAME}_DynamoDBImportFunction"
CONNECT_IMPORT_FUNCTION_NAME="${STACK_NAME}_ConnectImportFunction"

# Delete Lex bot
BOT_ID=$(aws lexv2-models list-bots --query "botSummaries[?name=='$BOT_NAME'].botId" --output text)
if [ -n "$BOT_ID" ]; then
  echo "Deleting Lex bot: $BOT_NAME ($BOT_ID)"
  BOT_ALIASES=$(aws lexv2-models list-bot-aliases --bot-id $BOT_ID --query "botAliasSummaries[].botAliasId" --output text)
  for ALIAS_ID in $BOT_ALIASES; do
    aws lexv2-models delete-bot-alias --bot-id $BOT_ID --bot-alias-id $ALIAS_ID
  done
  sleep 5
  aws lexv2-models delete-bot --bot-id $BOT_ID --skip-resource-in-use-check
fi

# Delete Lambda functions
for FUNCTION in "$BUSINESS_LOGIC_FUNCTION_NAME" "$LEX_IMPORT_FUNCTION_NAME" "$DYNAMODB_IMPORT_FUNCTION_NAME" "$CONNECT_IMPORT_FUNCTION_NAME"; do
  echo "Deleting Lambda function: $FUNCTION"
  aws lambda delete-function --function-name $FUNCTION --region $REGION 2>/dev/null || true
done

# Delete DynamoDB table
echo "Deleting DynamoDB table: $DYNAMODB_TABLE_NAME"
aws dynamodb delete-table --table-name $DYNAMODB_TABLE_NAME --region $REGION 2>/dev/null || true

# Delete IAM roles and policies
for ROLE in "${STACK_NAME}_LexRole" "${STACK_NAME}_LambdaRole" "${STACK_NAME}_LexImportRole" "${STACK_NAME}_ConnectRole"; do
  echo "Deleting IAM role: $ROLE"
  
  # Get and detach managed policies
  POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || echo "")
  for POLICY in $POLICIES; do
    aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY 2>/dev/null || true
  done
  
  # Delete inline policies
  INLINE_POLICIES=$(aws iam list-role-policies --role-name $ROLE --query "PolicyNames" --output text 2>/dev/null || echo "")
  for POLICY in $INLINE_POLICIES; do
    aws iam delete-role-policy --role-name $ROLE --policy-name $POLICY 2>/dev/null || true
  done
  
  # Delete role
  aws iam delete-role --role-name $ROLE 2>/dev/null || true
done

echo "Resource deletion complete!"

