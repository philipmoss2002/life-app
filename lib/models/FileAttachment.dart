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


/** This is an auto generated class representing the FileAttachment type in your schema. */
class FileAttachment extends amplify_core.Model {
  static const classType = const _FileAttachmentModelType();
  final String? _syncId;
  final String? _userId;
  final String? _fileName;
  final String? _label;
  final int? _fileSize;
  final String? _s3Key;
  final String? _filePath;
  final amplify_core.TemporalDateTime? _addedAt;
  final String? _contentType;
  final String? _checksum;
  final String? _syncState;
  final Document? _document;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => modelIdentifier.serializeAsString();
  
  FileAttachmentModelIdentifier get modelIdentifier {
    try {
      return FileAttachmentModelIdentifier(
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
  
  String get fileName {
    try {
      return _fileName!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String? get label {
    return _label;
  }
  
  int get fileSize {
    try {
      return _fileSize!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get s3Key {
    try {
      return _s3Key!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get filePath {
    try {
      return _filePath!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime get addedAt {
    try {
      return _addedAt!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String? get contentType {
    return _contentType;
  }
  
  String? get checksum {
    return _checksum;
  }
  
  String get syncState {
    try {
      return _syncState!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  Document? get document {
    return _document;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const FileAttachment._internal({required syncId, required userId, required fileName, label, required fileSize, required s3Key, required filePath, required addedAt, contentType, checksum, required syncState, document, createdAt, updatedAt}): _syncId = syncId, _userId = userId, _fileName = fileName, _label = label, _fileSize = fileSize, _s3Key = s3Key, _filePath = filePath, _addedAt = addedAt, _contentType = contentType, _checksum = checksum, _syncState = syncState, _document = document, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory FileAttachment({required String syncId, required String userId, required String fileName, String? label, required int fileSize, required String s3Key, required String filePath, required amplify_core.TemporalDateTime addedAt, String? contentType, String? checksum, required String syncState, Document? document}) {
    return FileAttachment._internal(
      syncId: syncId,
      userId: userId,
      fileName: fileName,
      label: label,
      fileSize: fileSize,
      s3Key: s3Key,
      filePath: filePath,
      addedAt: addedAt,
      contentType: contentType,
      checksum: checksum,
      syncState: syncState,
      document: document);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FileAttachment &&
      _syncId == other._syncId &&
      _userId == other._userId &&
      _fileName == other._fileName &&
      _label == other._label &&
      _fileSize == other._fileSize &&
      _s3Key == other._s3Key &&
      _filePath == other._filePath &&
      _addedAt == other._addedAt &&
      _contentType == other._contentType &&
      _checksum == other._checksum &&
      _syncState == other._syncState &&
      _document == other._document;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("FileAttachment {");
    buffer.write("syncId=" + "$_syncId" + ", ");
    buffer.write("userId=" + "$_userId" + ", ");
    buffer.write("fileName=" + "$_fileName" + ", ");
    buffer.write("label=" + "$_label" + ", ");
    buffer.write("fileSize=" + (_fileSize != null ? _fileSize!.toString() : "null") + ", ");
    buffer.write("s3Key=" + "$_s3Key" + ", ");
    buffer.write("filePath=" + "$_filePath" + ", ");
    buffer.write("addedAt=" + (_addedAt != null ? _addedAt!.format() : "null") + ", ");
    buffer.write("contentType=" + "$_contentType" + ", ");
    buffer.write("checksum=" + "$_checksum" + ", ");
    buffer.write("syncState=" + "$_syncState" + ", ");
    buffer.write("document=" + (_document != null ? _document!.toString() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  FileAttachment copyWith({String? userId, String? fileName, String? label, int? fileSize, String? s3Key, String? filePath, amplify_core.TemporalDateTime? addedAt, String? contentType, String? checksum, String? syncState, Document? document}) {
    return FileAttachment._internal(
      syncId: syncId,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      label: label ?? this.label,
      fileSize: fileSize ?? this.fileSize,
      s3Key: s3Key ?? this.s3Key,
      filePath: filePath ?? this.filePath,
      addedAt: addedAt ?? this.addedAt,
      contentType: contentType ?? this.contentType,
      checksum: checksum ?? this.checksum,
      syncState: syncState ?? this.syncState,
      document: document ?? this.document);
  }
  
  FileAttachment copyWithModelFieldValues({
    ModelFieldValue<String>? userId,
    ModelFieldValue<String>? fileName,
    ModelFieldValue<String?>? label,
    ModelFieldValue<int>? fileSize,
    ModelFieldValue<String>? s3Key,
    ModelFieldValue<String>? filePath,
    ModelFieldValue<amplify_core.TemporalDateTime>? addedAt,
    ModelFieldValue<String?>? contentType,
    ModelFieldValue<String?>? checksum,
    ModelFieldValue<String>? syncState,
    ModelFieldValue<Document?>? document
  }) {
    return FileAttachment._internal(
      syncId: syncId,
      userId: userId == null ? this.userId : userId.value,
      fileName: fileName == null ? this.fileName : fileName.value,
      label: label == null ? this.label : label.value,
      fileSize: fileSize == null ? this.fileSize : fileSize.value,
      s3Key: s3Key == null ? this.s3Key : s3Key.value,
      filePath: filePath == null ? this.filePath : filePath.value,
      addedAt: addedAt == null ? this.addedAt : addedAt.value,
      contentType: contentType == null ? this.contentType : contentType.value,
      checksum: checksum == null ? this.checksum : checksum.value,
      syncState: syncState == null ? this.syncState : syncState.value,
      document: document == null ? this.document : document.value
    );
  }
  
  FileAttachment.fromJson(Map<String, dynamic> json)  
    : _syncId = json['syncId'],
      _userId = json['userId'],
      _fileName = json['fileName'],
      _label = json['label'],
      _fileSize = (json['fileSize'] as num?)?.toInt(),
      _s3Key = json['s3Key'],
      _filePath = json['filePath'],
      _addedAt = json['addedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['addedAt']) : null,
      _contentType = json['contentType'],
      _checksum = json['checksum'],
      _syncState = json['syncState'],
      _document = json['document'] != null
        ? json['document']['serializedData'] != null
          ? Document.fromJson(new Map<String, dynamic>.from(json['document']['serializedData']))
          : Document.fromJson(new Map<String, dynamic>.from(json['document']))
        : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'syncId': _syncId, 'userId': _userId, 'fileName': _fileName, 'label': _label, 'fileSize': _fileSize, 's3Key': _s3Key, 'filePath': _filePath, 'addedAt': _addedAt?.format(), 'contentType': _contentType, 'checksum': _checksum, 'syncState': _syncState, 'document': _document?.toJson(), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'syncId': _syncId,
    'userId': _userId,
    'fileName': _fileName,
    'label': _label,
    'fileSize': _fileSize,
    's3Key': _s3Key,
    'filePath': _filePath,
    'addedAt': _addedAt,
    'contentType': _contentType,
    'checksum': _checksum,
    'syncState': _syncState,
    'document': _document,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<FileAttachmentModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<FileAttachmentModelIdentifier>();
  static final SYNCID = amplify_core.QueryField(fieldName: "syncId");
  static final USERID = amplify_core.QueryField(fieldName: "userId");
  static final FILENAME = amplify_core.QueryField(fieldName: "fileName");
  static final LABEL = amplify_core.QueryField(fieldName: "label");
  static final FILESIZE = amplify_core.QueryField(fieldName: "fileSize");
  static final S3KEY = amplify_core.QueryField(fieldName: "s3Key");
  static final FILEPATH = amplify_core.QueryField(fieldName: "filePath");
  static final ADDEDAT = amplify_core.QueryField(fieldName: "addedAt");
  static final CONTENTTYPE = amplify_core.QueryField(fieldName: "contentType");
  static final CHECKSUM = amplify_core.QueryField(fieldName: "checksum");
  static final SYNCSTATE = amplify_core.QueryField(fieldName: "syncState");
  static final DOCUMENT = amplify_core.QueryField(
    fieldName: "document",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Document'));
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "FileAttachment";
    modelSchemaDefinition.pluralName = "FileAttachments";
    
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
      amplify_core.ModelIndex(fields: const ["documentSyncId", "addedAt"], name: "byDocumentSyncId"),
      amplify_core.ModelIndex(fields: const ["userId", "addedAt"], name: "byUserId")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.SYNCID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.USERID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.FILENAME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.LABEL,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.FILESIZE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.S3KEY,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.FILEPATH,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.ADDEDAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.CONTENTTYPE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.CHECKSUM,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.SYNCSTATE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.belongsTo(
      key: FileAttachment.DOCUMENT,
      isRequired: false,
      targetNames: ['documentSyncId'],
      ofModelName: 'Document'
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

class _FileAttachmentModelType extends amplify_core.ModelType<FileAttachment> {
  const _FileAttachmentModelType();
  
  @override
  FileAttachment fromJson(Map<String, dynamic> jsonData) {
    return FileAttachment.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'FileAttachment';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [FileAttachment] in your schema.
 */
class FileAttachmentModelIdentifier implements amplify_core.ModelIdentifier<FileAttachment> {
  final String syncId;

  /** Create an instance of FileAttachmentModelIdentifier using [syncId] the primary key. */
  const FileAttachmentModelIdentifier({
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
  String toString() => 'FileAttachmentModelIdentifier(syncId: $syncId)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is FileAttachmentModelIdentifier &&
      syncId == other.syncId;
  }
  
  @override
  int get hashCode =>
    syncId.hashCode;
}