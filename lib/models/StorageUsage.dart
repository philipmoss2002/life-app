/*
* Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

// NOTE: This file is generated and may not follow lint rules defined in your app
// Generated files can be excluded from analysis in analysis_options.yaml
// For more info, see: https://dart.dev/guides/language/analysis-options#excluding-code-from-analysis

// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, dead_codepublic_member_api_docs, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;


/** This is an auto generated class representing the StorageUsage type in your schema. */
class StorageUsage extends amplify_core.Model {
  static const classType = const _StorageUsageModelType();
  final String id;
  final String? _userId;
  final int? _usedBytes;
  final int? _quotaBytes;
  final int? _documentCount;
  final int? _fileCount;
  final amplify_core.TemporalDateTime? _lastCalculated;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  StorageUsageModelIdentifier get modelIdentifier {
      return StorageUsageModelIdentifier(
        id: id
      );
  }
  
  String get userId {
    try {
      return _userId!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get usedBytes {
    try {
      return _usedBytes!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get quotaBytes {
    try {
      return _quotaBytes!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get documentCount {
    try {
      return _documentCount!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get fileCount {
    try {
      return _fileCount!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime get lastCalculated {
    try {
      return _lastCalculated!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const StorageUsage._internal({required this.id, required userId, required usedBytes, required quotaBytes, required documentCount, required fileCount, required lastCalculated, createdAt, updatedAt}): _userId = userId, _usedBytes = usedBytes, _quotaBytes = quotaBytes, _documentCount = documentCount, _fileCount = fileCount, _lastCalculated = lastCalculated, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory StorageUsage({String? id, required String userId, required int usedBytes, required int quotaBytes, required int documentCount, required int fileCount, required amplify_core.TemporalDateTime lastCalculated}) {
    return StorageUsage._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      userId: userId,
      usedBytes: usedBytes,
      quotaBytes: quotaBytes,
      documentCount: documentCount,
      fileCount: fileCount,
      lastCalculated: lastCalculated);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StorageUsage &&
      id == other.id &&
      _userId == other._userId &&
      _usedBytes == other._usedBytes &&
      _quotaBytes == other._quotaBytes &&
      _documentCount == other._documentCount &&
      _fileCount == other._fileCount &&
      _lastCalculated == other._lastCalculated;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("StorageUsage {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("userId=" + "$_userId" + ", ");
    buffer.write("usedBytes=" + (_usedBytes != null ? _usedBytes!.toString() : "null") + ", ");
    buffer.write("quotaBytes=" + (_quotaBytes != null ? _quotaBytes!.toString() : "null") + ", ");
    buffer.write("documentCount=" + (_documentCount != null ? _documentCount!.toString() : "null") + ", ");
    buffer.write("fileCount=" + (_fileCount != null ? _fileCount!.toString() : "null") + ", ");
    buffer.write("lastCalculated=" + (_lastCalculated != null ? _lastCalculated!.format() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  StorageUsage copyWith({String? userId, int? usedBytes, int? quotaBytes, int? documentCount, int? fileCount, amplify_core.TemporalDateTime? lastCalculated}) {
    return StorageUsage._internal(
      id: id,
      userId: userId ?? this.userId,
      usedBytes: usedBytes ?? this.usedBytes,
      quotaBytes: quotaBytes ?? this.quotaBytes,
      documentCount: documentCount ?? this.documentCount,
      fileCount: fileCount ?? this.fileCount,
      lastCalculated: lastCalculated ?? this.lastCalculated);
  }
  
  StorageUsage copyWithModelFieldValues({
    ModelFieldValue<String>? userId,
    ModelFieldValue<int>? usedBytes,
    ModelFieldValue<int>? quotaBytes,
    ModelFieldValue<int>? documentCount,
    ModelFieldValue<int>? fileCount,
    ModelFieldValue<amplify_core.TemporalDateTime>? lastCalculated
  }) {
    return StorageUsage._internal(
      id: id,
      userId: userId == null ? this.userId : userId.value,
      usedBytes: usedBytes == null ? this.usedBytes : usedBytes.value,
      quotaBytes: quotaBytes == null ? this.quotaBytes : quotaBytes.value,
      documentCount: documentCount == null ? this.documentCount : documentCount.value,
      fileCount: fileCount == null ? this.fileCount : fileCount.value,
      lastCalculated: lastCalculated == null ? this.lastCalculated : lastCalculated.value
    );
  }
  
  StorageUsage.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _userId = json['userId'],
      _usedBytes = (json['usedBytes'] as num?)?.toInt(),
      _quotaBytes = (json['quotaBytes'] as num?)?.toInt(),
      _documentCount = (json['documentCount'] as num?)?.toInt(),
      _fileCount = (json['fileCount'] as num?)?.toInt(),
      _lastCalculated = json['lastCalculated'] != null ? amplify_core.TemporalDateTime.fromString(json['lastCalculated']) : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'userId': _userId, 'usedBytes': _usedBytes, 'quotaBytes': _quotaBytes, 'documentCount': _documentCount, 'fileCount': _fileCount, 'lastCalculated': _lastCalculated?.format(), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'userId': _userId,
    'usedBytes': _usedBytes,
    'quotaBytes': _quotaBytes,
    'documentCount': _documentCount,
    'fileCount': _fileCount,
    'lastCalculated': _lastCalculated,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<StorageUsageModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<StorageUsageModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final USERID = amplify_core.QueryField(fieldName: "userId");
  static final USEDBYTES = amplify_core.QueryField(fieldName: "usedBytes");
  static final QUOTABYTES = amplify_core.QueryField(fieldName: "quotaBytes");
  static final DOCUMENTCOUNT = amplify_core.QueryField(fieldName: "documentCount");
  static final FILECOUNT = amplify_core.QueryField(fieldName: "fileCount");
  static final LASTCALCULATED = amplify_core.QueryField(fieldName: "lastCalculated");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "StorageUsage";
    modelSchemaDefinition.pluralName = "StorageUsages";
    
    modelSchemaDefinition.authRules = [
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.OWNER,
        ownerField: "userId",
        identityClaim: "sub",
        provider: amplify_core.AuthRuleProvider.USERPOOLS,
        operations: const [
          amplify_core.ModelOperation.CREATE,
          amplify_core.ModelOperation.UPDATE,
          amplify_core.ModelOperation.DELETE,
          amplify_core.ModelOperation.READ
        ])
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: StorageUsage.USERID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: StorageUsage.USEDBYTES,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: StorageUsage.QUOTABYTES,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: StorageUsage.DOCUMENTCOUNT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: StorageUsage.FILECOUNT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: StorageUsage.LASTCALCULATED,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'createdAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _StorageUsageModelType extends amplify_core.ModelType<StorageUsage> {
  const _StorageUsageModelType();
  
  @override
  StorageUsage fromJson(Map<String, dynamic> jsonData) {
    return StorageUsage.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'StorageUsage';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [StorageUsage] in your schema.
 */
class StorageUsageModelIdentifier implements amplify_core.ModelIdentifier<StorageUsage> {
  final String id;

  /** Create an instance of StorageUsageModelIdentifier using [id] the primary key. */
  const StorageUsageModelIdentifier({
    required this.id});
  
  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{
    'id': id
  });
  
  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
    .entries
    .map((entry) => (<String, dynamic>{ entry.key: entry.value }))
    .toList();
  
  @override
  String serializeAsString() => serializeAsMap().values.join('#');
  
  @override
  String toString() => 'StorageUsageModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is StorageUsageModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}