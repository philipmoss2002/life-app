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


/** This is an auto generated class representing the SyncEvent type in your schema. */
class SyncEvent extends amplify_core.Model {
  static const classType = const _SyncEventModelType();
  final String id;
  final String? _eventType;
  final String? _entityType;
  final String? _entityId;
  final String? _message;
  final amplify_core.TemporalDateTime? _timestamp;
  final String? _deviceId;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  SyncEventModelIdentifier get modelIdentifier {
      return SyncEventModelIdentifier(
        id: id
      );
  }
  
  String get eventType {
    try {
      return _eventType!;
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
  
  String? get message {
    return _message;
  }
  
  amplify_core.TemporalDateTime get timestamp {
    try {
      return _timestamp!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String? get deviceId {
    return _deviceId;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const SyncEvent._internal({required this.id, required eventType, required entityType, required entityId, message, required timestamp, deviceId, createdAt, updatedAt}): _eventType = eventType, _entityType = entityType, _entityId = entityId, _message = message, _timestamp = timestamp, _deviceId = deviceId, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory SyncEvent({String? id, required String eventType, required String entityType, required String entityId, String? message, required amplify_core.TemporalDateTime timestamp, String? deviceId}) {
    return SyncEvent._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      eventType: eventType,
      entityType: entityType,
      entityId: entityId,
      message: message,
      timestamp: timestamp,
      deviceId: deviceId);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncEvent &&
      id == other.id &&
      _eventType == other._eventType &&
      _entityType == other._entityType &&
      _entityId == other._entityId &&
      _message == other._message &&
      _timestamp == other._timestamp &&
      _deviceId == other._deviceId;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("SyncEvent {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("eventType=" + "$_eventType" + ", ");
    buffer.write("entityType=" + "$_entityType" + ", ");
    buffer.write("entityId=" + "$_entityId" + ", ");
    buffer.write("message=" + "$_message" + ", ");
    buffer.write("timestamp=" + (_timestamp != null ? _timestamp!.format() : "null") + ", ");
    buffer.write("deviceId=" + "$_deviceId" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  SyncEvent copyWith({String? eventType, String? entityType, String? entityId, String? message, amplify_core.TemporalDateTime? timestamp, String? deviceId}) {
    return SyncEvent._internal(
      id: id,
      eventType: eventType ?? this.eventType,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      deviceId: deviceId ?? this.deviceId);
  }
  
  SyncEvent copyWithModelFieldValues({
    ModelFieldValue<String>? eventType,
    ModelFieldValue<String>? entityType,
    ModelFieldValue<String>? entityId,
    ModelFieldValue<String?>? message,
    ModelFieldValue<amplify_core.TemporalDateTime>? timestamp,
    ModelFieldValue<String?>? deviceId
  }) {
    return SyncEvent._internal(
      id: id,
      eventType: eventType == null ? this.eventType : eventType.value,
      entityType: entityType == null ? this.entityType : entityType.value,
      entityId: entityId == null ? this.entityId : entityId.value,
      message: message == null ? this.message : message.value,
      timestamp: timestamp == null ? this.timestamp : timestamp.value,
      deviceId: deviceId == null ? this.deviceId : deviceId.value
    );
  }
  
  SyncEvent.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _eventType = json['eventType'],
      _entityType = json['entityType'],
      _entityId = json['entityId'],
      _message = json['message'],
      _timestamp = json['timestamp'] != null ? amplify_core.TemporalDateTime.fromString(json['timestamp']) : null,
      _deviceId = json['deviceId'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'eventType': _eventType, 'entityType': _entityType, 'entityId': _entityId, 'message': _message, 'timestamp': _timestamp?.format(), 'deviceId': _deviceId, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'eventType': _eventType,
    'entityType': _entityType,
    'entityId': _entityId,
    'message': _message,
    'timestamp': _timestamp,
    'deviceId': _deviceId,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<SyncEventModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<SyncEventModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final EVENTTYPE = amplify_core.QueryField(fieldName: "eventType");
  static final ENTITYTYPE = amplify_core.QueryField(fieldName: "entityType");
  static final ENTITYID = amplify_core.QueryField(fieldName: "entityId");
  static final MESSAGE = amplify_core.QueryField(fieldName: "message");
  static final TIMESTAMP = amplify_core.QueryField(fieldName: "timestamp");
  static final DEVICEID = amplify_core.QueryField(fieldName: "deviceId");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "SyncEvent";
    modelSchemaDefinition.pluralName = "SyncEvents";
    
    modelSchemaDefinition.authRules = [
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.OWNER,
        ownerField: "owner",
        identityClaim: "cognito:username",
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
      key: SyncEvent.EVENTTYPE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncEvent.ENTITYTYPE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncEvent.ENTITYID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncEvent.MESSAGE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncEvent.TIMESTAMP,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: SyncEvent.DEVICEID,
      isRequired: false,
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

class _SyncEventModelType extends amplify_core.ModelType<SyncEvent> {
  const _SyncEventModelType();
  
  @override
  SyncEvent fromJson(Map<String, dynamic> jsonData) {
    return SyncEvent.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'SyncEvent';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [SyncEvent] in your schema.
 */
class SyncEventModelIdentifier implements amplify_core.ModelIdentifier<SyncEvent> {
  final String id;

  /** Create an instance of SyncEventModelIdentifier using [id] the primary key. */
  const SyncEventModelIdentifier({
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
  String toString() => 'SyncEventModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is SyncEventModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}