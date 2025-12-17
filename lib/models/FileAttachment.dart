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
  final String id;
  final String? _filePath;
  final String? _fileName;
  final String? _label;
  final int? _fileSize;
  final String? _s3Key;
  final amplify_core.TemporalDateTime? _addedAt;
  final String? _syncState;
  final Document? _document;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  FileAttachmentModelIdentifier get modelIdentifier {
      return FileAttachmentModelIdentifier(
        id: id
      );
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
  
  const FileAttachment._internal({required this.id, required filePath, required fileName, label, required fileSize, required s3Key, required addedAt, required syncState, document, createdAt, updatedAt}): _filePath = filePath, _fileName = fileName, _label = label, _fileSize = fileSize, _s3Key = s3Key, _addedAt = addedAt, _syncState = syncState, _document = document, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory FileAttachment({String? id, required String filePath, required String fileName, String? label, required int fileSize, required String s3Key, required amplify_core.TemporalDateTime addedAt, required String syncState, Document? document}) {
    return FileAttachment._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      filePath: filePath,
      fileName: fileName,
      label: label,
      fileSize: fileSize,
      s3Key: s3Key,
      addedAt: addedAt,
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
      id == other.id &&
      _filePath == other._filePath &&
      _fileName == other._fileName &&
      _label == other._label &&
      _fileSize == other._fileSize &&
      _s3Key == other._s3Key &&
      _addedAt == other._addedAt &&
      _syncState == other._syncState &&
      _document == other._document;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("FileAttachment {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("filePath=" + "$_filePath" + ", ");
    buffer.write("fileName=" + "$_fileName" + ", ");
    buffer.write("label=" + "$_label" + ", ");
    buffer.write("fileSize=" + (_fileSize != null ? _fileSize!.toString() : "null") + ", ");
    buffer.write("s3Key=" + "$_s3Key" + ", ");
    buffer.write("addedAt=" + (_addedAt != null ? _addedAt!.format() : "null") + ", ");
    buffer.write("syncState=" + "$_syncState" + ", ");
    buffer.write("document=" + (_document != null ? _document!.toString() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  FileAttachment copyWith({String? filePath, String? fileName, String? label, int? fileSize, String? s3Key, amplify_core.TemporalDateTime? addedAt, String? syncState, Document? document}) {
    return FileAttachment._internal(
      id: id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      label: label ?? this.label,
      fileSize: fileSize ?? this.fileSize,
      s3Key: s3Key ?? this.s3Key,
      addedAt: addedAt ?? this.addedAt,
      syncState: syncState ?? this.syncState,
      document: document ?? this.document);
  }
  
  FileAttachment copyWithModelFieldValues({
    ModelFieldValue<String>? filePath,
    ModelFieldValue<String>? fileName,
    ModelFieldValue<String?>? label,
    ModelFieldValue<int>? fileSize,
    ModelFieldValue<String>? s3Key,
    ModelFieldValue<amplify_core.TemporalDateTime>? addedAt,
    ModelFieldValue<String>? syncState,
    ModelFieldValue<Document?>? document
  }) {
    return FileAttachment._internal(
      id: id,
      filePath: filePath == null ? this.filePath : filePath.value,
      fileName: fileName == null ? this.fileName : fileName.value,
      label: label == null ? this.label : label.value,
      fileSize: fileSize == null ? this.fileSize : fileSize.value,
      s3Key: s3Key == null ? this.s3Key : s3Key.value,
      addedAt: addedAt == null ? this.addedAt : addedAt.value,
      syncState: syncState == null ? this.syncState : syncState.value,
      document: document == null ? this.document : document.value
    );
  }
  
  FileAttachment.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _filePath = json['filePath'],
      _fileName = json['fileName'],
      _label = json['label'],
      _fileSize = (json['fileSize'] as num?)?.toInt(),
      _s3Key = json['s3Key'],
      _addedAt = json['addedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['addedAt']) : null,
      _syncState = json['syncState'],
      _document = json['document'] != null
        ? json['document']['serializedData'] != null
          ? Document.fromJson(new Map<String, dynamic>.from(json['document']['serializedData']))
          : Document.fromJson(new Map<String, dynamic>.from(json['document']))
        : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'filePath': _filePath, 'fileName': _fileName, 'label': _label, 'fileSize': _fileSize, 's3Key': _s3Key, 'addedAt': _addedAt?.format(), 'syncState': _syncState, 'document': _document?.toJson(), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'filePath': _filePath,
    'fileName': _fileName,
    'label': _label,
    'fileSize': _fileSize,
    's3Key': _s3Key,
    'addedAt': _addedAt,
    'syncState': _syncState,
    'document': _document,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<FileAttachmentModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<FileAttachmentModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final FILEPATH = amplify_core.QueryField(fieldName: "filePath");
  static final FILENAME = amplify_core.QueryField(fieldName: "fileName");
  static final LABEL = amplify_core.QueryField(fieldName: "label");
  static final FILESIZE = amplify_core.QueryField(fieldName: "fileSize");
  static final S3KEY = amplify_core.QueryField(fieldName: "s3Key");
  static final ADDEDAT = amplify_core.QueryField(fieldName: "addedAt");
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
    
    modelSchemaDefinition.indexes = [
      amplify_core.ModelIndex(fields: const ["documentId", "addedAt"], name: "byDocumentId")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.FILEPATH,
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
      key: FileAttachment.ADDEDAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: FileAttachment.SYNCSTATE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.belongsTo(
      key: FileAttachment.DOCUMENT,
      isRequired: false,
      targetNames: ['documentId'],
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
  final String id;

  /** Create an instance of FileAttachmentModelIdentifier using [id] the primary key. */
  const FileAttachmentModelIdentifier({
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
  String toString() => 'FileAttachmentModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is FileAttachmentModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}