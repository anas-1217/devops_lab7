#!/usr/bin/env bash
set -u
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <bucket-name> <ec2-address> <lambda-url>"
  exit 1
fi
BUCKET="$1"; EC2_ADDR="${2%/}"; LAMBDA_URL="${3%/}"
OUT="evidence.txt"
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
if [ -z "$REGION" ]; then REGION="ap-southeast-2"; fi
EC2_ROLE="cv-ec2-role-23l-3005"
LAMBDA_ROLE="cv-lambda-role-23l-3005"
INSTANCE_ID="$(aws ec2 describe-instances --region "$REGION" --filters "Name=tag:Name,Values=cv-ec2-23l-3005" --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | awk '{print $1}')"
SG_ID="$(aws ec2 describe-instances --region "$REGION" --filters "Name=tag:Name,Values=cv-ec2-23l-3005" --query 'Reservations[].Instances[].SecurityGroups[].GroupId' --output text 2>/dev/null | awk '{print $1}')"
FN="cv-func-23l-3005"
LOG_GROUP="/aws/lambda/${FN}"

section() { printf '\n== %s ==\n' "$1" >>"$OUT"; }
run() {
  local name="$1"; shift
  section "$name"
  if "$@" >>"$OUT" 2>&1; then :; else echo "COMMAND FAILED (exit $?)" >>"$OUT"; fi
}
: >"$OUT"
run caller aws sts get-caller-identity
run public-access aws s3api get-public-access-block --region "$REGION" --bucket "$BUCKET"
run versioning aws s3api get-bucket-versioning --region "$REGION" --bucket "$BUCKET"
run objects aws s3 ls "s3://${BUCKET}/site/" --region "$REGION"
run ec2-policy aws iam get-role-policy --role-name "$EC2_ROLE" --policy-name "cv-ec2-s3-read"
section lambda-policy
if ! aws iam list-attached-role-policies --role-name "$LAMBDA_ROLE" >>"$OUT" 2>&1; then echo "COMMAND FAILED: attached policies" >>"$OUT"; fi
if ! aws iam get-role-policy --role-name "$LAMBDA_ROLE" --policy-name "cv-lambda-s3-read" >>"$OUT" 2>&1; then echo "COMMAND FAILED: inline policy" >>"$OUT"; fi
run security-group aws ec2 describe-security-groups --region "$REGION" --group-ids "$SG_ID"
run instance aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" --query 'Reservations[].Instances[].{InstanceId:InstanceId,InstanceType:InstanceType,MetadataOptions:MetadataOptions,IamInstanceProfile:IamInstanceProfile,PublicIpAddress:PublicIpAddress,Tags:Tags}'
section endpoints
for path in "/" "/style.css" "/cv.pdf"; do
  echo "-- EC2 ${path} --" >>"$OUT"
  curl -sS -o /dev/null -w 'status=%{http_code} content_type=%{content_type}\n' "${EC2_ADDR}${path}" >>"$OUT" 2>&1 || echo "curl failed" >>"$OUT"
  echo "-- Lambda ${path} --" >>"$OUT"
  curl -sS -o /dev/null -w 'status=%{http_code} content_type=%{content_type}\n' "${LAMBDA_URL}${path}" >>"$OUT" 2>&1 || echo "curl failed" >>"$OUT"
done
echo "-- Direct S3 object (expected 403) --" >>"$OUT"
curl -sS -o /dev/null -w 'status=%{http_code} content_type=%{content_type}\n' "https://${BUCKET}.s3.${REGION}.amazonaws.com/site/index.html" >>"$OUT" 2>&1 || echo "curl failed" >>"$OUT"
section lambda-logs
if ! aws logs tail "$LOG_GROUP" --region "$REGION" --since 1h --format short >>"$OUT" 2>&1; then echo "COMMAND FAILED" >>"$OUT"; fi
section log-retention
if ! aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "$LOG_GROUP" --query "logGroups[?logGroupName=='${LOG_GROUP}'].{logGroupName:logGroupName,retentionInDays:retentionInDays}" >>"$OUT" 2>&1; then echo "COMMAND FAILED" >>"$OUT"; fi
echo "DONE"
