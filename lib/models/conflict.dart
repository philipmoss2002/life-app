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


/** This is an auto generated class representing the Conflict type in your schema. */
class Conflict extends amplify_core.Model {
  static const classType = const _ConflictModelType();
  final String id;
  final String? _userId;
  final String? _entityType;
  final String? _entityId;
  final String? _localVersion;
  final String? _remoteVersion;
  final amplify_core.TemporalDateTime? _detectedAt;
  final amplify_core.TemporalDateTime? _resolvedAt;
  final ConflictResolution? _resolution;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  ConflictModelIdentifier get modelIdentifier {
      return ConflictModelIdentifier(
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
  
  String get entityType {
    try {
      return _entityType!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get entityId {
    try {
      return _entityId!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get localVersion {
    try {
      return _localVersion!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get remoteVersion {
    try {
      return _remoteVersion!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime get detectedAt {
    try {
      return _detectedAt!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime? get resolvedAt {
    return _resolvedAt;
  }
  
  ConflictResolution? get resolution {
    return _resolution;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const Conflict._internal({required this.id, required userId, required entityType, required entityId, required localVersion, required remoteVersion, required detectedAt, resolvedAt, resolution, createdAt, updatedAt}): _userId = userId, _entityType = entityType, _entityId = entityId, _localVersion = localVersion, _remoteVersion = remoteVersion, _detectedAt = detectedAt, _resolvedAt = resolvedAt, _resolution = resolution, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory Conflict({String? id, required String userId, required String entityType, required String entityId, required String localVersion, required String remoteVersion, required amplify_core.TemporalDateTime detectedAt, amplify_core.TemporalDateTime? resolvedAt, ConflictResolution? resolution}) {
    return Conflict._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt,
      resolution: resolution);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Conflict &&
      id == other.id &&
      _userId == other._userId &&
      _entityType == other._entityType &&
      _entityId == other._entityId &&
      _localVersion == other._localVersion &&
      _remoteVersion == other._remoteVersion &&
      _detectedAt == other._detectedAt &&
      _resolvedAt == other._resolvedAt &&
      _resolution == other._resolution;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Conflict {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("userId=" + "$_userId" + ", ");
    buffer.write("entityType=" + "$_entityType" + ", ");
    buffer.write("entityId=" + "$_entityId" + ", ");
    buffer.write("localVersion=" + "$_localVersion" + ", ");
    buffer.write("remoteVersion=" + "$_remoteVersion" + ", ");
    buffer.write("detectedAt=" + (_detectedAt != null ? _detectedAt!.format() : "null") + ", ");
    buffer.write("resolvedAt=" + (_resolvedAt != null ? _resolvedAt!.format() : "null") + ", ");
    buffer.write("resolution=" + (_resolution != null ? amplify_core.enumToString(_resolution)! : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Conflict copyWith({String? userId, String? entityType, String? entityId, String? localVersion, String? remoteVersion, amplify_core.TemporalDateTime? detectedAt, amplify_core.TemporalDateTime? resolvedAt, ConflictResolution? resolution}) {
    return Conflict._internal(
      id: id,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      localVersion: localVersion ?? this.localVersion,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      detectedAt: detectedAt ?? this.detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolution: resolution ?? this.resolution);
  }
  
  Conflict copyWithModelFieldValues({
    ModelFieldValue<String>? userId,
    ModelFieldValue<String>? entityType,
    ModelFieldValue<String>? entityId,
    ModelFieldValue<String>? localVersion,
    ModelFieldValue<String>? remoteVersion,
    ModelFieldValue<amplify_core.TemporalDateTime>? detectedAt,
    ModelFieldValue<amplify_core.TemporalDateTime?>? resolvedAt,
    ModelFieldValue<ConflictResolution?>? resolution
  }) {
    return Conflict._internal(
      id: id,
      userId: userId == null ? this.userId : userId.value,
      entityType: entityType == null ? this.entityType : entityType.value,
      entityId: entityId == null ? this.entityId : entityId.value,
      localVersion: localVersion == null ? this.localVersion : localVersion.value,
      remoteVersion: remoteVersion == null ? this.remoteVersion : remoteVersion.value,
      detectedAt: detectedAt == null ? this.detectedAt : detectedAt.value,
      resolvedAt: resolvedAt == null ? this.resolvedAt : resolvedAt.value,
      resolution: resolution == null ? this.resolution : resolution.value
    );
  }
  
  Conflict.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _userId = json['userId'],
      _entityType = json['entityType'],
      _entityId = json['entityId'],
      _localVersion = json['localVersion'],
      _remoteVersion = json['remoteVersion'],
      _detectedAt = json['detectedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['detectedAt']) : null,
      _resolvedAt = json['resolvedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['resolvedAt']) : null,
      _resolution = amplify_core.enumFromString<ConflictResolution>(json['resolution'], ConflictResolution.values),
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'userId': _userId, 'entityType': _entityType, 'entityId': _entityId, 'localVersion': _localVersion, 'remoteVersion': _remoteVersion, 'detectedAt': _detectedAt?.format(), 'resolvedAt': _resolvedAt?.format(), 'resolution': amplify_core.enumToString(_resolution), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'userId': _userId,
    'entityType': _entityType,
    'entityId': _entityId,
    'localVersion': _localVersion,
    'remoteVersion': _remoteVersion,
    'detectedAt': _detectedAt,
    'resolvedAt': _resolvedAt,
    'resolution': _resolution,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<ConflictModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<ConflictModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final USERID = amplify_core.QueryField(fieldName: "userId");
  static final ENTITYTYPE = amplify_core.QueryField(fieldName: "entityType");
  static final ENTITYID = amplify_core.QueryField(fieldName: "entityId");
  static final LOCALVERSION = amplify_core.QueryField(fieldName: "localVersion");
  static final REMOTEVERSION = amplify_core.QueryField(fieldName: "remoteVersion");
  static final DETECTEDAT = amplify_core.QueryField(fieldName: "detectedAt");
  static final RESOLVEDAT = amplify_core.QueryField(fieldName: "resolvedAt");
  static final RESOLUTION = amplify_core.QueryField(fieldName: "resolution");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Conflict";
    modelSchemaDefinition.pluralName = "Conflicts";
    
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
      key: Conflict.USERID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Conflict.ENTITYTYPE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Conflict.ENTITYID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Conflict.LOCALVERSION,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Conflict.REMOTEVERSION,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Conflict.DETECTEDAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Conflict.RESOLVEDAT,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Conflict.RESOLUTION,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.enumeration)
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

class _ConflictModelType extends amplify_core.ModelType<Conflict> {
  const _ConflictModelType();
  
  @override
  Conflict fromJson(Map<String, dynamic> jsonData) {
    return Conflict.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Conflict';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Conflict] in your schema.
 */
class ConflictModelIdentifier implements amplify_core.ModelIdentifier<Conflict> {
  final String id;

  /** Create an instance of ConflictModelIdentifier using [id] the primary key. */
  const ConflictModelIdentifier({
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
  String toString() => 'ConflictModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is ConflictModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}