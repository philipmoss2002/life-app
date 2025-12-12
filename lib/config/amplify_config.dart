/// AWS Amplify configuration for different environments
/// This file contains the configuration for dev, staging, and production environments

class AmplifyEnvironmentConfig {
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'dev',
  );

  /// Get the appropriate configuration based on the environment
  static Map<String, dynamic> getConfig() {
    switch (environment) {
      case 'production':
        return _productionConfig;
      case 'staging':
        return _stagingConfig;
      case 'dev':
      default:
        return _devConfig;
    }
  }

  /// Development environment configuration
  static const Map<String, dynamic> _devConfig = {
    'UserAgent': 'aws-amplify-cli/2.0',
    'Version': '1.0',
    'auth': {
      'plugins': {
        'awsCognitoAuthPlugin': {
          'UserAgent': 'aws-amplify-cli/0.1.0',
          'Version': '0.1.0',
          'IdentityManager': {'Default': {}},
          'CredentialsProvider': {
            'CognitoIdentity': {
              'Default': {
                'PoolId': 'REPLACE_WITH_DEV_IDENTITY_POOL_ID',
                'Region': 'REPLACE_WITH_REGION'
              }
            }
          },
          'CognitoUserPool': {
            'Default': {
              'PoolId': 'REPLACE_WITH_DEV_USER_POOL_ID',
              'AppClientId': 'REPLACE_WITH_DEV_APP_CLIENT_ID',
              'Region': 'REPLACE_WITH_REGION'
            }
          },
          'Auth': {
            'Default': {
              'authenticationFlowType': 'USER_SRP_AUTH',
              'socialProviders': [],
              'usernameAttributes': ['EMAIL'],
              'signupAttributes': ['EMAIL'],
              'passwordProtectionSettings': {
                'passwordPolicyMinLength': 8,
                'passwordPolicyCharacters': []
              },
              'mfaConfiguration': 'OFF',
              'mfaTypes': ['SMS'],
              'verificationMechanisms': ['EMAIL']
            }
          }
        }
      }
    },
    'storage': {
      'plugins': {
        'awsS3StoragePlugin': {
          'bucket': 'REPLACE_WITH_DEV_BUCKET_NAME',
          'region': 'REPLACE_WITH_REGION',
          'defaultAccessLevel': 'private',
          // S3 bucket should have default encryption enabled (AES-256)
          // Configure via: amplify update storage or AWS Console
          // See ENCRYPTION_SETUP_GUIDE.md for details
        }
      }
    },
    'api': {
      'plugins': {
        'awsAPIPlugin': {
          'householdDocsAPI': {
            'endpointType': 'REST',
            'endpoint': 'REPLACE_WITH_DEV_API_ENDPOINT',
            'region': 'REPLACE_WITH_REGION',
            'authorizationType': 'AMAZON_COGNITO_USER_POOLS'
          }
        }
      }
    }
  };

  /// Staging environment configuration
  static const Map<String, dynamic> _stagingConfig = {
    'UserAgent': 'aws-amplify-cli/2.0',
    'Version': '1.0',
    'auth': {
      'plugins': {
        'awsCognitoAuthPlugin': {
          'UserAgent': 'aws-amplify-cli/0.1.0',
          'Version': '0.1.0',
          'IdentityManager': {'Default': {}},
          'CredentialsProvider': {
            'CognitoIdentity': {
              'Default': {
                'PoolId': 'REPLACE_WITH_STAGING_IDENTITY_POOL_ID',
                'Region': 'REPLACE_WITH_REGION'
              }
            }
          },
          'CognitoUserPool': {
            'Default': {
              'PoolId': 'REPLACE_WITH_STAGING_USER_POOL_ID',
              'AppClientId': 'REPLACE_WITH_STAGING_APP_CLIENT_ID',
              'Region': 'REPLACE_WITH_REGION'
            }
          },
          'Auth': {
            'Default': {
              'authenticationFlowType': 'USER_SRP_AUTH',
              'socialProviders': [],
              'usernameAttributes': ['EMAIL'],
              'signupAttributes': ['EMAIL'],
              'passwordProtectionSettings': {
                'passwordPolicyMinLength': 8,
                'passwordPolicyCharacters': []
              },
              'mfaConfiguration': 'OFF',
              'mfaTypes': ['SMS'],
              'verificationMechanisms': ['EMAIL']
            }
          }
        }
      }
    },
    'storage': {
      'plugins': {
        'awsS3StoragePlugin': {
          'bucket': 'REPLACE_WITH_STAGING_BUCKET_NAME',
          'region': 'REPLACE_WITH_REGION',
          'defaultAccessLevel': 'private',
          // S3 bucket should have default encryption enabled (AES-256)
          // Configure via: amplify update storage or AWS Console
          // See ENCRYPTION_SETUP_GUIDE.md for details
        }
      }
    },
    'api': {
      'plugins': {
        'awsAPIPlugin': {
          'householdDocsAPI': {
            'endpointType': 'REST',
            'endpoint': 'REPLACE_WITH_STAGING_API_ENDPOINT',
            'region': 'REPLACE_WITH_REGION',
            'authorizationType': 'AMAZON_COGNITO_USER_POOLS'
          }
        }
      }
    }
  };

  /// Production environment configuration
  static const Map<String, dynamic> _productionConfig = {
    'UserAgent': 'aws-amplify-cli/2.0',
    'Version': '1.0',
    'auth': {
      'plugins': {
        'awsCognitoAuthPlugin': {
          'UserAgent': 'aws-amplify-cli/0.1.0',
          'Version': '0.1.0',
          'IdentityManager': {'Default': {}},
          'CredentialsProvider': {
            'CognitoIdentity': {
              'Default': {
                'PoolId': 'REPLACE_WITH_PROD_IDENTITY_POOL_ID',
                'Region': 'REPLACE_WITH_REGION'
              }
            }
          },
          'CognitoUserPool': {
            'Default': {
              'PoolId': 'REPLACE_WITH_PROD_USER_POOL_ID',
              'AppClientId': 'REPLACE_WITH_PROD_APP_CLIENT_ID',
              'Region': 'REPLACE_WITH_REGION'
            }
          },
          'Auth': {
            'Default': {
              'authenticationFlowType': 'USER_SRP_AUTH',
              'socialProviders': [],
              'usernameAttributes': ['EMAIL'],
              'signupAttributes': ['EMAIL'],
              'passwordProtectionSettings': {
                'passwordPolicyMinLength': 8,
                'passwordPolicyCharacters': []
              },
              'mfaConfiguration': 'OFF',
              'mfaTypes': ['SMS'],
              'verificationMechanisms': ['EMAIL']
            }
          }
        }
      }
    },
    'storage': {
      'plugins': {
        'awsS3StoragePlugin': {
          'bucket': 'REPLACE_WITH_PROD_BUCKET_NAME',
          'region': 'REPLACE_WITH_REGION',
          'defaultAccessLevel': 'private',
          // S3 bucket should have default encryption enabled (AES-256)
          // Configure via: amplify update storage or AWS Console
          // See ENCRYPTION_SETUP_GUIDE.md for details
        }
      }
    },
    'api': {
      'plugins': {
        'awsAPIPlugin': {
          'householdDocsAPI': {
            'endpointType': 'REST',
            'endpoint': 'REPLACE_WITH_PROD_API_ENDPOINT',
            'region': 'REPLACE_WITH_REGION',
            'authorizationType': 'AMAZON_COGNITO_USER_POOLS'
          }
        }
      }
    }
  };
}
