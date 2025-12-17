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


/** This is an auto generated class representing the Device type in your schema. */
class Device extends amplify_core.Model {
  static const classType = const _DeviceModelType();
  final String id;
  final String? _deviceName;
  final String? _deviceType;
  final amplify_core.TemporalDateTime? _lastSyncTime;
  final bool? _isActive;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  DeviceModelIdentifier get modelIdentifier {
      return DeviceModelIdentifier(
        id: id
      );
  }
  
  String get deviceName {
    try {
      return _deviceName!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get deviceType {
    try {
      return _deviceType!;
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
  
  bool get isActive {
    try {
      return _isActive!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime get createdAt {
    try {
      return _createdAt!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const Device._internal({required this.id, required deviceName, required deviceType, required lastSyncTime, required isActive, required createdAt, updatedAt}): _deviceName = deviceName, _deviceType = deviceType, _lastSyncTime = lastSyncTime, _isActive = isActive, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory Device({String? id, required String deviceName, required String deviceType, required amplify_core.TemporalDateTime lastSyncTime, required bool isActive, required amplify_core.TemporalDateTime createdAt}) {
    return Device._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      deviceName: deviceName,
      deviceType: deviceType,
      lastSyncTime: lastSyncTime,
      isActive: isActive,
      createdAt: createdAt);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Device &&
      id == other.id &&
      _deviceName == other._deviceName &&
      _deviceType == other._deviceType &&
      _lastSyncTime == other._lastSyncTime &&
      _isActive == other._isActive &&
      _createdAt == other._createdAt;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Device {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("deviceName=" + "$_deviceName" + ", ");
    buffer.write("deviceType=" + "$_deviceType" + ", ");
    buffer.write("lastSyncTime=" + (_lastSyncTime != null ? _lastSyncTime!.format() : "null") + ", ");
    buffer.write("isActive=" + (_isActive != null ? _isActive!.toString() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Device copyWith({String? deviceName, String? deviceType, amplify_core.TemporalDateTime? lastSyncTime, bool? isActive, amplify_core.TemporalDateTime? createdAt}) {
    return Device._internal(
      id: id,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt);
  }
  
  Device copyWithModelFieldValues({
    ModelFieldValue<String>? deviceName,
    ModelFieldValue<String>? deviceType,
    ModelFieldValue<amplify_core.TemporalDateTime>? lastSyncTime,
    ModelFieldValue<bool>? isActive,
    ModelFieldValue<amplify_core.TemporalDateTime>? createdAt
  }) {
    return Device._internal(
      id: id,
      deviceName: deviceName == null ? this.deviceName : deviceName.value,
      deviceType: deviceType == null ? this.deviceType : deviceType.value,
      lastSyncTime: lastSyncTime == null ? this.lastSyncTime : lastSyncTime.value,
      isActive: isActive == null ? this.isActive : isActive.value,
      createdAt: createdAt == null ? this.createdAt : createdAt.value
    );
  }
  
  Device.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _deviceName = json['deviceName'],
      _deviceType = json['deviceType'],
      _lastSyncTime = json['lastSyncTime'] != null ? amplify_core.TemporalDateTime.fromString(json['lastSyncTime']) : null,
      _isActive = json['isActive'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'deviceName': _deviceName, 'deviceType': _deviceType, 'lastSyncTime': _lastSyncTime?.format(), 'isActive': _isActive, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'deviceName': _deviceName,
    'deviceType': _deviceType,
    'lastSyncTime': _lastSyncTime,
    'isActive': _isActive,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<DeviceModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<DeviceModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final DEVICENAME = amplify_core.QueryField(fieldName: "deviceName");
  static final DEVICETYPE = amplify_core.QueryField(fieldName: "deviceType");
  static final LASTSYNCTIME = amplify_core.QueryField(fieldName: "lastSyncTime");
  static final ISACTIVE = amplify_core.QueryField(fieldName: "isActive");
  static final CREATEDAT = amplify_core.QueryField(fieldName: "createdAt");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Device";
    modelSchemaDefinition.pluralName = "Devices";
    
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
      key: Device.DEVICENAME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Device.DEVICETYPE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Device.LASTSYNCTIME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Device.ISACTIVE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.bool)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Device.CREATEDAT,
      isRequired: true,
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

class _DeviceModelType extends amplify_core.ModelType<Device> {
  const _DeviceModelType();
  
  @override
  Device fromJson(Map<String, dynamic> jsonData) {
    return Device.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Device';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Device] in your schema.
 */
class DeviceModelIdentifier implements amplify_core.ModelIdentifier<Device> {
  final String id;

  /** Create an instance of DeviceModelIdentifier using [id] the primary key. */
  const DeviceModelIdentifier({
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
  String toString() => 'DeviceModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is DeviceModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}