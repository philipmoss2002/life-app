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


/** This is an auto generated class representing the DocumentTombstone type in your schema. */
class DocumentTombstone extends amplify_core.Model {
  static const classType = const _DocumentTombstoneModelType();
  final String? _syncId;
  final String? _userId;
  final amplify_core.TemporalDateTime? _deletedAt;
  final String? _deletedBy;
  final String? _reason;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => modelIdentifier.serializeAsString();
  
  DocumentTombstoneModelIdentifier get modelIdentifier {
    try {
      return DocumentTombstoneModelIdentifier(
        syncId: _syncId!
      );
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get syncId {
    try {
      return _syncId!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
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
  
  amplify_core.TemporalDateTime get deletedAt {
    try {
      return _deletedAt!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get deletedBy {
    try {
      return _deletedBy!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get reason {
    try {
      return _reason!;
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
  
  const DocumentTombstone._internal({required syncId, required userId, required deletedAt, required deletedBy, required reason, createdAt, updatedAt}): _syncId = syncId, _userId = userId, _deletedAt = deletedAt, _deletedBy = deletedBy, _reason = reason, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory DocumentTombstone({required String syncId, required String userId, required amplify_core.TemporalDateTime deletedAt, required String deletedBy, required String reason}) {
    return DocumentTombstone._internal(
      syncId: syncId,
      userId: userId,
      deletedAt: deletedAt,
      deletedBy: deletedBy,
      reason: reason);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DocumentTombstone &&
      _syncId == other._syncId &&
      _userId == other._userId &&
      _deletedAt == other._deletedAt &&
      _deletedBy == other._deletedBy &&
      _reason == other._reason;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("DocumentTombstone {");
    buffer.write("syncId=" + "$_syncId" + ", ");
    buffer.write("userId=" + "$_userId" + ", ");
    buffer.write("deletedAt=" + (_deletedAt != null ? _deletedAt!.format() : "null") + ", ");
    buffer.write("deletedBy=" + "$_deletedBy" + ", ");
    buffer.write("reason=" + "$_reason" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  DocumentTombstone copyWith({String? userId, amplify_core.TemporalDateTime? deletedAt, String? deletedBy, String? reason}) {
    return DocumentTombstone._internal(
      syncId: syncId,
      userId: userId ?? this.userId,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      reason: reason ?? this.reason);
  }
  
  DocumentTombstone copyWithModelFieldValues({
    ModelFieldValue<String>? userId,
    ModelFieldValue<amplify_core.TemporalDateTime>? deletedAt,
    ModelFieldValue<String>? deletedBy,
    ModelFieldValue<String>? reason
  }) {
    return DocumentTombstone._internal(
      syncId: syncId,
      userId: userId == null ? this.userId : userId.value,
      deletedAt: deletedAt == null ? this.deletedAt : deletedAt.value,
      deletedBy: deletedBy == null ? this.deletedBy : deletedBy.value,
      reason: reason == null ? this.reason : reason.value
    );
  }
  
  DocumentTombstone.fromJson(Map<String, dynamic> json)  
    : _syncId = json['syncId'],
      _userId = json['userId'],
      _deletedAt = json['deletedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['deletedAt']) : null,
      _deletedBy = json['deletedBy'],
      _reason = json['reason'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'syncId': _syncId, 'userId': _userId, 'deletedAt': _deletedAt?.format(), 'deletedBy': _deletedBy, 'reason': _reason, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'syncId': _syncId,
    'userId': _userId,
    'deletedAt': _deletedAt,
    'deletedBy': _deletedBy,
    'reason': _reason,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<DocumentTombstoneModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<DocumentTombstoneModelIdentifier>();
  static final SYNCID = amplify_core.QueryField(fieldName: "syncId");
  static final USERID = amplify_core.QueryField(fieldName: "userId");
  static final DELETEDAT = amplify_core.QueryField(fieldName: "deletedAt");
  static final DELETEDBY = amplify_core.QueryField(fieldName: "deletedBy");
  static final REASON = amplify_core.QueryField(fieldName: "reason");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "DocumentTombstone";
    modelSchemaDefinition.pluralName = "DocumentTombstones";
    
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
    
    modelSchemaDefinition.indexes = [
      amplify_core.ModelIndex(fields: const ["syncId"], name: null),
      amplify_core.ModelIndex(fields: const ["userId"], name: "byUserId")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: DocumentTombstone.SYNCID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: DocumentTombstone.USERID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: DocumentTombstone.DELETEDAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: DocumentTombstone.DELETEDBY,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: DocumentTombstone.REASON,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
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

class _DocumentTombstoneModelType extends amplify_core.ModelType<DocumentTombstone> {
  const _DocumentTombstoneModelType();
  
  @override
  DocumentTombstone fromJson(Map<String, dynamic> jsonData) {
    return DocumentTombstone.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'DocumentTombstone';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [DocumentTombstone] in your schema.
 */
class DocumentTombstoneModelIdentifier implements amplify_core.ModelIdentifier<DocumentTombstone> {
  final String syncId;

  /** Create an instance of DocumentTombstoneModelIdentifier using [syncId] the primary key. */
  const DocumentTombstoneModelIdentifier({
    required this.syncId});
  
  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{
    'syncId': syncId
  });
  
  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
    .entries
    .map((entry) => (<String, dynamic>{ entry.key: entry.value }))
    .toList();
  
  @override
  String serializeAsString() => serializeAsMap().values.join('#');
  
  @override
  String toString() => 'DocumentTombstoneModelIdentifier(syncId: $syncId)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is DocumentTombstoneModelIdentifier &&
      syncId == other.syncId;
  }
  
  @override
  int get hashCode =>
    syncId.hashCode;
}