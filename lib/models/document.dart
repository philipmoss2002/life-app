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
import 'package:collection/collection.dart';


/** This is an auto generated class representing the Document type in your schema. */
class Document extends amplify_core.Model {
  static const classType = const _DocumentModelType();
  final String? _syncId;
  final String? _userId;
  final String? _title;
  final String? _category;
  final List<String>? _filePaths;
  final amplify_core.TemporalDateTime? _renewalDate;
  final String? _notes;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _lastModified;
  final int? _version;
  final String? _syncState;
  final String? _conflictId;
  final bool? _deleted;
  final amplify_core.TemporalDateTime? _deletedAt;
  final String? _contentHash;
  final List<FileAttachment>? _fileAttachments;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => modelIdentifier.serializeAsString();
  
  DocumentModelIdentifier get modelIdentifier {
    try {
      return DocumentModelIdentifier(
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
  
  String get title {
    try {
      return _title!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get category {
    try {
      return _category!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  List<String> get filePaths {
    try {
      return _filePaths!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime? get renewalDate {
    return _renewalDate;
  }
  
  String? get notes {
    return _notes;
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
  
  amplify_core.TemporalDateTime get lastModified {
    try {
      return _lastModified!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get version {
    try {
      return _version!;
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
  
  String? get conflictId {
    return _conflictId;
  }
  
  bool? get deleted {
    return _deleted;
  }
  
  amplify_core.TemporalDateTime? get deletedAt {
    return _deletedAt;
  }
  
  String? get contentHash {
    return _contentHash;
  }
  
  List<FileAttachment>? get fileAttachments {
    return _fileAttachments;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const Document._internal({required syncId, required userId, required title, required category, required filePaths, renewalDate, notes, required createdAt, required lastModified, required version, required syncState, conflictId, deleted, deletedAt, contentHash, fileAttachments, updatedAt}): _syncId = syncId, _userId = userId, _title = title, _category = category, _filePaths = filePaths, _renewalDate = renewalDate, _notes = notes, _createdAt = createdAt, _lastModified = lastModified, _version = version, _syncState = syncState, _conflictId = conflictId, _deleted = deleted, _deletedAt = deletedAt, _contentHash = contentHash, _fileAttachments = fileAttachments, _updatedAt = updatedAt;
  
  factory Document({required String syncId, required String userId, required String title, required String category, required List<String> filePaths, amplify_core.TemporalDateTime? renewalDate, String? notes, required amplify_core.TemporalDateTime createdAt, required amplify_core.TemporalDateTime lastModified, required int version, required String syncState, String? conflictId, bool? deleted, amplify_core.TemporalDateTime? deletedAt, String? contentHash, List<FileAttachment>? fileAttachments}) {
    return Document._internal(
      syncId: syncId,
      userId: userId,
      title: title,
      category: category,
      filePaths: filePaths != null ? List<String>.unmodifiable(filePaths) : filePaths,
      renewalDate: renewalDate,
      notes: notes,
      createdAt: createdAt,
      lastModified: lastModified,
      version: version,
      syncState: syncState,
      conflictId: conflictId,
      deleted: deleted,
      deletedAt: deletedAt,
      contentHash: contentHash,
      fileAttachments: fileAttachments != null ? List<FileAttachment>.unmodifiable(fileAttachments) : fileAttachments);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Document &&
      _syncId == other._syncId &&
      _userId == other._userId &&
      _title == other._title &&
      _category == other._category &&
      DeepCollectionEquality().equals(_filePaths, other._filePaths) &&
      _renewalDate == other._renewalDate &&
      _notes == other._notes &&
      _createdAt == other._createdAt &&
      _lastModified == other._lastModified &&
      _version == other._version &&
      _syncState == other._syncState &&
      _conflictId == other._conflictId &&
      _deleted == other._deleted &&
      _deletedAt == other._deletedAt &&
      _contentHash == other._contentHash &&
      DeepCollectionEquality().equals(_fileAttachments, other._fileAttachments);
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Document {");
    buffer.write("syncId=" + "$_syncId" + ", ");
    buffer.write("userId=" + "$_userId" + ", ");
    buffer.write("title=" + "$_title" + ", ");
    buffer.write("category=" + "$_category" + ", ");
    buffer.write("filePaths=" + (_filePaths != null ? _filePaths!.toString() : "null") + ", ");
    buffer.write("renewalDate=" + (_renewalDate != null ? _renewalDate!.format() : "null") + ", ");
    buffer.write("notes=" + "$_notes" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("lastModified=" + (_lastModified != null ? _lastModified!.format() : "null") + ", ");
    buffer.write("version=" + (_version != null ? _version!.toString() : "null") + ", ");
    buffer.write("syncState=" + "$_syncState" + ", ");
    buffer.write("conflictId=" + "$_conflictId" + ", ");
    buffer.write("deleted=" + (_deleted != null ? _deleted!.toString() : "null") + ", ");
    buffer.write("deletedAt=" + (_deletedAt != null ? _deletedAt!.format() : "null") + ", ");
    buffer.write("contentHash=" + "$_contentHash" + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Document copyWith({String? userId, String? title, String? category, List<String>? filePaths, amplify_core.TemporalDateTime? renewalDate, String? notes, amplify_core.TemporalDateTime? createdAt, amplify_core.TemporalDateTime? lastModified, int? version, String? syncState, String? conflictId, bool? deleted, amplify_core.TemporalDateTime? deletedAt, String? contentHash, List<FileAttachment>? fileAttachments}) {
    return Document._internal(
      syncId: syncId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      filePaths: filePaths ?? this.filePaths,
      renewalDate: renewalDate ?? this.renewalDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      version: version ?? this.version,
      syncState: syncState ?? this.syncState,
      conflictId: conflictId ?? this.conflictId,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      contentHash: contentHash ?? this.contentHash,
      fileAttachments: fileAttachments ?? this.fileAttachments);
  }
  
  Document copyWithModelFieldValues({
    ModelFieldValue<String>? userId,
    ModelFieldValue<String>? title,
    ModelFieldValue<String>? category,
    ModelFieldValue<List<String>>? filePaths,
    ModelFieldValue<amplify_core.TemporalDateTime?>? renewalDate,
    ModelFieldValue<String?>? notes,
    ModelFieldValue<amplify_core.TemporalDateTime>? createdAt,
    ModelFieldValue<amplify_core.TemporalDateTime>? lastModified,
    ModelFieldValue<int>? version,
    ModelFieldValue<String>? syncState,
    ModelFieldValue<String?>? conflictId,
    ModelFieldValue<bool?>? deleted,
    ModelFieldValue<amplify_core.TemporalDateTime?>? deletedAt,
    ModelFieldValue<String?>? contentHash,
    ModelFieldValue<List<FileAttachment>?>? fileAttachments
  }) {
    return Document._internal(
      syncId: syncId,
      userId: userId == null ? this.userId : userId.value,
      title: title == null ? this.title : title.value,
      category: category == null ? this.category : category.value,
      filePaths: filePaths == null ? this.filePaths : filePaths.value,
      renewalDate: renewalDate == null ? this.renewalDate : renewalDate.value,
      notes: notes == null ? this.notes : notes.value,
      createdAt: createdAt == null ? this.createdAt : createdAt.value,
      lastModified: lastModified == null ? this.lastModified : lastModified.value,
      version: version == null ? this.version : version.value,
      syncState: syncState == null ? this.syncState : syncState.value,
      conflictId: conflictId == null ? this.conflictId : conflictId.value,
      deleted: deleted == null ? this.deleted : deleted.value,
      deletedAt: deletedAt == null ? this.deletedAt : deletedAt.value,
      contentHash: contentHash == null ? this.contentHash : contentHash.value,
      fileAttachments: fileAttachments == null ? this.fileAttachments : fileAttachments.value
    );
  }
  
  Document.fromJson(Map<String, dynamic> json)  
    : _syncId = json['syncId'],
      _userId = json['userId'],
      _title = json['title'],
      _category = json['category'],
      _filePaths = json['filePaths']?.cast<String>(),
      _renewalDate = json['renewalDate'] != null ? amplify_core.TemporalDateTime.fromString(json['renewalDate']) : null,
      _notes = json['notes'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _lastModified = json['lastModified'] != null ? amplify_core.TemporalDateTime.fromString(json['lastModified']) : null,
      _version = (json['version'] as num?)?.toInt(),
      _syncState = json['syncState'],
      _conflictId = json['conflictId'],
      _deleted = json['deleted'],
      _deletedAt = json['deletedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['deletedAt']) : null,
      _contentHash = json['contentHash'],
      _fileAttachments = json['fileAttachments']  is Map
        ? (json['fileAttachments']['items'] is List
          ? (json['fileAttachments']['items'] as List)
              .where((e) => e != null)
              .map((e) => FileAttachment.fromJson(new Map<String, dynamic>.from(e)))
              .toList()
          : null)
        : (json['fileAttachments'] is List
          ? (json['fileAttachments'] as List)
              .where((e) => e?['serializedData'] != null)
              .map((e) => FileAttachment.fromJson(new Map<String, dynamic>.from(e?['serializedData'])))
              .toList()
          : null),
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'syncId': _syncId, 'userId': _userId, 'title': _title, 'category': _category, 'filePaths': _filePaths, 'renewalDate': _renewalDate?.format(), 'notes': _notes, 'createdAt': _createdAt?.format(), 'lastModified': _lastModified?.format(), 'version': _version, 'syncState': _syncState, 'conflictId': _conflictId, 'deleted': _deleted, 'deletedAt': _deletedAt?.format(), 'contentHash': _contentHash, 'fileAttachments': _fileAttachments?.map((FileAttachment? e) => e?.toJson()).toList(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'syncId': _syncId,
    'userId': _userId,
    'title': _title,
    'category': _category,
    'filePaths': _filePaths,
    'renewalDate': _renewalDate,
    'notes': _notes,
    'createdAt': _createdAt,
    'lastModified': _lastModified,
    'version': _version,
    'syncState': _syncState,
    'conflictId': _conflictId,
    'deleted': _deleted,
    'deletedAt': _deletedAt,
    'contentHash': _contentHash,
    'fileAttachments': _fileAttachments,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<DocumentModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<DocumentModelIdentifier>();
  static final SYNCID = amplify_core.QueryField(fieldName: "syncId");
  static final USERID = amplify_core.QueryField(fieldName: "userId");
  static final TITLE = amplify_core.QueryField(fieldName: "title");
  static final CATEGORY = amplify_core.QueryField(fieldName: "category");
  static final FILEPATHS = amplify_core.QueryField(fieldName: "filePaths");
  static final RENEWALDATE = amplify_core.QueryField(fieldName: "renewalDate");
  static final NOTES = amplify_core.QueryField(fieldName: "notes");
  static final CREATEDAT = amplify_core.QueryField(fieldName: "createdAt");
  static final LASTMODIFIED = amplify_core.QueryField(fieldName: "lastModified");
  static final VERSION = amplify_core.QueryField(fieldName: "version");
  static final SYNCSTATE = amplify_core.QueryField(fieldName: "syncState");
  static final CONFLICTID = amplify_core.QueryField(fieldName: "conflictId");
  static final DELETED = amplify_core.QueryField(fieldName: "deleted");
  static final DELETEDAT = amplify_core.QueryField(fieldName: "deletedAt");
  static final CONTENTHASH = amplify_core.QueryField(fieldName: "contentHash");
  static final FILEATTACHMENTS = amplify_core.QueryField(
    fieldName: "fileAttachments",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'FileAttachment'));
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Document";
    modelSchemaDefinition.pluralName = "Documents";
    
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
      amplify_core.ModelIndex(fields: const ["userId", "createdAt"], name: "byUserId")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.SYNCID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.USERID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.TITLE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.CATEGORY,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.FILEPATHS,
      isRequired: true,
      isArray: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.collection, ofModelName: amplify_core.ModelFieldTypeEnum.string.name)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.RENEWALDATE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.NOTES,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.CREATEDAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.LASTMODIFIED,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.VERSION,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.SYNCSTATE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.CONFLICTID,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.DELETED,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.bool)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.DELETEDAT,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Document.CONTENTHASH,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Document.FILEATTACHMENTS,
      isRequired: false,
      ofModelName: 'FileAttachment',
      associatedKey: FileAttachment.DOCUMENT
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _DocumentModelType extends amplify_core.ModelType<Document> {
  const _DocumentModelType();
  
  @override
  Document fromJson(Map<String, dynamic> jsonData) {
    return Document.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Document';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Document] in your schema.
 */
class DocumentModelIdentifier implements amplify_core.ModelIdentifier<Document> {
  final String syncId;

  /** Create an instance of DocumentModelIdentifier using [syncId] the primary key. */
  const DocumentModelIdentifier({
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
  String toString() => 'DocumentModelIdentifier(syncId: $syncId)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is DocumentModelIdentifier &&
      syncId == other.syncId;
  }
  
  @override
  int get hashCode =>
    syncId.hashCode;
}