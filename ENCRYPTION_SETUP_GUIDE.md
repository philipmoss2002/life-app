# Encryption Setup Guide

This guide provides step-by-step instructions for configuring AES-256 encryption at rest for all AWS services used by the Household Docs App.

## Overview

The app requires encryption at rest for:
- **S3 Buckets**: File attachments storage
- **DynamoDB Tables**: Document metadata storage

All encryption uses AES-256, meeting industry standards for data security.

## Prerequisites

- AWS Amplify CLI installed and configured
- AWS account with appropriate permissions
- Amplify project initialized

## S3 Bucket Encryption Configuration

### Method 1: Using Amplify CLI

1. Update your storage configuration:
```bash
amplify update storage
```

2. When prompted, select your storage resource (e.g., `fileAttachments`)

3. Choose encryption options:
   - Enable encryption: **Yes**
   - Encryption type: **AES256** (SSE-S3) or **AWS KMS** (SSE-KMS)

4. Push changes to AWS:
```bash
amplify push
```

### Method 2: Using AWS Console

1. Navigate to the [S3 Console](https://console.aws.amazon.com/s3/)

2. Select your bucket (e.g., `household-docs-file-attachments-xxxxx`)

3. Go to the **Properties** tab

4. Scroll to **Default encryption**

5. Click **Edit**

6. Select encryption settings:
   - **Server-side encryption**: Enabled
   - **Encryption key type**: Amazon S3 managed keys (SSE-S3)
   - **Bucket Key**: Enabled (optional, reduces costs)

7. Click **Save changes**

### Method 3: Using AWS CLI

```bash
aws s3api put-bucket-encryption \
  --bucket your-bucket-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
```

### Verification

Verify S3 encryption is enabled:

```bash
aws s3api get-bucket-encryption --bucket your-bucket-name
```

Expected output:
```json
{
    "ServerSideEncryptionConfiguration": {
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }
}
```

## DynamoDB Table Encryption Configuration

### Important Note

**DynamoDB encryption at rest is enabled by default** for all new tables created after November 2018. Tables use AWS owned keys which provide AES-256 encryption at no additional cost.

### Method 1: Using Amplify CLI

1. Update your API configuration:
```bash
amplify update api
```

2. Select your GraphQL API

3. Choose **Advanced settings**

4. Enable **Encryption at rest**

5. Select encryption key type:
   - **AWS owned key** (default, no additional cost)
   - **AWS managed key** (additional cost)
   - **Customer managed key** (additional cost, more control)

6. Push changes:
```bash
amplify push
```

### Method 2: Using AWS Console

1. Navigate to the [DynamoDB Console](https://console.aws.amazon.com/dynamodb/)

2. Select your table (e.g., `Document-xxxxx-dev`)

3. Go to the **Additional settings** tab

4. Scroll to **Encryption at rest**

5. Click **Manage encryption**

6. Select encryption type:
   - **AWS owned key** (recommended, AES-256, no cost)
   - **AWS managed key** (AES-256, additional cost)
   - **Customer managed key** (AES-256, additional cost)

7. Click **Save**

### Method 3: Using AWS CLI

For new tables, specify encryption during creation:

```bash
aws dynamodb create-table \
  --table-name YourTableName \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS
```

For existing tables, update encryption:

```bash
aws dynamodb update-table \
  --table-name YourTableName \
  --sse-specification Enabled=true,SSEType=KMS
```

### Verification

Verify DynamoDB encryption:

```bash
aws dynamodb describe-table --table-name YourTableName --query 'Table.SSEDescription'
```

Expected output:
```json
{
    "Status": "ENABLED",
    "SSEType": "KMS",
    "KMSMasterKeyArn": "arn:aws:kms:region:account:key/key-id"
}
```

Or for AWS owned keys:
```json
{
    "Status": "ENABLED",
    "SSEType": "AES256"
}
```

## Encryption Key Management

### AWS Owned Keys (Recommended)
- **Cost**: Free
- **Management**: Fully managed by AWS
- **Encryption**: AES-256
- **Use Case**: Default option, suitable for most applications
- **Key Rotation**: Automatic

### AWS Managed Keys
- **Cost**: $1/month per key + API call charges
- **Management**: Managed by AWS, visible in your account
- **Encryption**: AES-256
- **Use Case**: When you need audit trails via CloudTrail
- **Key Rotation**: Automatic annual rotation

### Customer Managed Keys
- **Cost**: $1/month per key + API call charges
- **Management**: You control key policies and rotation
- **Encryption**: AES-256
- **Use Case**: When you need full control over encryption keys
- **Key Rotation**: Manual or automatic (configurable)

## Security Best Practices

1. **Enable Encryption by Default**
   - Configure default encryption on all S3 buckets
   - Enable encryption at rest for all DynamoDB tables

2. **Use AWS Owned Keys for Cost Efficiency**
   - Provides AES-256 encryption at no additional cost
   - Suitable for most use cases

3. **Enable Bucket Keys for S3**
   - Reduces encryption costs by up to 99%
   - No impact on security

4. **Monitor Encryption Status**
   - Use AWS Config to monitor encryption compliance
   - Set up alerts for unencrypted resources

5. **Regular Audits**
   - Periodically verify encryption is enabled
   - Review CloudTrail logs for encryption key usage

## Compliance

The encryption configuration meets the following compliance standards:

- **HIPAA**: AES-256 encryption at rest
- **PCI-DSS**: Strong cryptography for data protection
- **SOC 2**: Encryption of sensitive data
- **GDPR**: Appropriate technical measures for data protection
- **FIPS 140-2**: AES-256 is FIPS compliant

## Troubleshooting

### S3 Encryption Issues

**Problem**: Objects not encrypted after enabling default encryption

**Solution**: Default encryption only applies to new objects. Re-upload existing objects or use:

```bash
aws s3 cp s3://bucket-name s3://bucket-name --recursive \
  --sse AES256 --metadata-directive REPLACE
```

### DynamoDB Encryption Issues

**Problem**: Cannot enable encryption on existing table

**Solution**: 
1. Create a new table with encryption enabled
2. Use AWS Data Pipeline or custom script to migrate data
3. Update application to use new table
4. Delete old table

### Performance Concerns

**Question**: Does encryption impact performance?

**Answer**: 
- S3: Minimal impact, encryption/decryption is transparent
- DynamoDB: No measurable performance impact
- Both services handle encryption at the infrastructure level

## Verification in Application

Use the `EncryptionConfigService` to verify encryption status:

```dart
import 'package:household_docs_app/services/encryption_config_service.dart';

// Verify all encryption
final encryptionService = EncryptionConfigService();
final status = await encryptionService.verifyAllEncryption();

print('S3 Encryption: ${status['s3']}');
print('DynamoDB Encryption: ${status['dynamodb']}');

// Get documentation
print(encryptionService.getEncryptionDocumentation());
```

## Additional Resources

- [AWS S3 Encryption Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html)
- [AWS DynamoDB Encryption Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)
- [Amplify Storage Documentation](https://docs.amplify.aws/lib/storage/getting-started/q/platform/flutter/)

## Support

For issues or questions:
1. Check AWS Service Health Dashboard
2. Review CloudTrail logs for encryption-related events
3. Contact AWS Support
4. Consult Amplify documentation
