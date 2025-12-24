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


/** This is an auto generated class representing the SyncState type in your schema. */
class SyncState extends amplify_core.Model {
  static const classType = const _SyncStateModelType();
  final String id;
  final String? _userId;
  final amplify_core.TemporalDateTime? _lastSyncTime;
  final int? _pendingOperations;
  final int? _conflictCount;
  final int? _errorCount;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  SyncStateModelIdentifier get modelIdentifier {
      return SyncStateModelIdentifier(
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
  
  amplify_core.TemporalDateTime get lastSyncTime {
    try {
      return _lastSyncTime!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get pendingOperations {
    try {
      return _pendingOperations!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get conflictCount {
    try {
      return _conflictCount!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get errorCount {
    try {
      return _errorCount!;
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
  
  const SyncState._internal({required this.id, required userId, required lastSyncTime, required pendingOperations, required conflictCount, required errorCount, createdAt, updatedAt}): _userId = userId, _lastSyncTime = lastSyncTime, _pendingOperations = pendingOperations, _conflictCount = conflictCount, _errorCount = errorCount, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory SyncState({String? id, required String userId, required amplify_core.TemporalDateTime lastSyncTime, required int pendingOperations, required int conflictCount, required int errorCount}) {
    return SyncState._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      userId: userId,
      lastSyncTime: lastSyncTime,
      pendingOperations: pendingOperations,
      conflictCount: conflictCount,
      errorCount: errorCount);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncState &&
      id == other.id &&
      _userId == other._userId &&
      _lastSyncTime == other._lastSyncTime &&
      _pendingOperations == other._pendingOperations &&
      _conflictCount == other._conflictCount &&
      _errorCount == other._errorCount;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("SyncState {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("userId=" + "$_userId" + ", ");
    buffer.write("lastSyncTime=" + (_lastSyncTime != null ? _lastSyncTime!.format() : "null") + ", ");
    buffer.write("pendingOperations=" + (_pendingOperations != null ? _pendingOperations!.toString() : "null") + ", ");
    buffer.write("conflictCount=" + (_conflictCount != null ? _conflictCount!.toString() : "null") + ", ");
    buffer.write("errorCount=" + (_errorCount != null ? _errorCount!.toString() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  SyncState copyWith({String? userId, amplify_core.TemporalDateTime? lastSyncTime, int? pendingOperations, int? conflictCount, int? errorCount}) {
    return SyncState._internal(
      id: id,
      userId: userId ?? this.userId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      conflictCount: conflictCount ?? this.conflictCount,
      errorCount: errorCount ?? this.errorCount);
  }
  
  SyncState copyWithModelFieldValues({
    ModelFieldValue<String>? userId,
    ModelFieldValue<amplify_core.TemporalDateTime>? lastSyncTime,
    ModelFieldValue<int>? pendingOperations,
    ModelFieldValue<int>? conflictCount,
    ModelFieldValue<int>? errorCount
  }) {
    return SyncState._internal(
      id: id,
      userId: userId == null ? this.userId : userId.value,
      lastSyncTime: lastSyncTime == null ? this.lastSyncTime : lastSyncTime.value,
      pendingOperations: pendingOperations == null ? this.pendingOperations : pendingOperations.value,
      conflictCount: conflictCount == null ? this.conflictCount : conflictCount.value,
      errorCount: errorCount == null ? this.errorCount : errorCount.value
    );
  }
  
  SyncState.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _userId = json['userId'],
      _lastSyncTime = json['lastSyncTime'] != null ? amplify_core.TemporalDateTime.fromString(json['lastSyncTime']) : null,
      _pendingOperations = (json['pendingOperations'] as num?)?.toInt(),
      _conflictCount = (json['conflictCount'] as num?)?.toInt(),
      _errorCount = (json['errorCount'] as num?)?.toInt(),
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'userId': _userId, 'lastSyncTime': _lastSyncTime?.format(), 'pendingOperations': _pendingOperations, 'conflictCount': _conflictCount, 'errorCount': _errorCount, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'userId': _userId,
    'lastSyncTime': _lastSyncTime,
    'pendingOperations': _pendingOperations,
    'conflictCount': _conflictCount,
    'errorCount': _errorCount,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<SyncStateModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<SyncStateModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final USERID = amplify_core.QueryField(fieldName: "userId");
  static final LASTSYNCTIME = amplify_core.QueryField(fieldName: "lastSyncTime");
  static final PENDINGOPERATIONS = amplify_core.QueryField(fieldName: "pendingOperations");
  static final CONFLICTCOUNT = amplify_core.QueryField(fieldName: "conflictCount");
  static final ERRORCOUNT = amplify_core.QueryField(fieldName: "errorCount");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "SyncState";
    modelSchemaDefinition.pluralName = "SyncStates";
    
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
      amplify_core.ModelIndex(fields: const ["userId"], name: "byUserId")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncState.USERID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncState.LASTSYNCTIME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncState.PENDINGOPERATIONS,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncState.CONFLICTCOUNT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncState.ERRORCOUNT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
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

class _SyncStateModelType extends amplify_core.ModelType<SyncState> {
  const _SyncStateModelType();
  
  @override
  SyncState fromJson(Map<String, dynamic> jsonData) {
    return SyncState.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'SyncState';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [SyncState] in your schema.
 */
class SyncStateModelIdentifier implements amplify_core.ModelIdentifier<SyncState> {
  final String id;

  /** Create an instance of SyncStateModelIdentifier using [id] the primary key. */
  const SyncStateModelIdentifier({
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
  String toString() => 'SyncStateModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is SyncStateModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}