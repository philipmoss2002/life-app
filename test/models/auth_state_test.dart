import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/auth_state.dart';

void main() {
  group('AuthState', () {
    test('creates unauthenticated state', () {
      final state = AuthState.unauthenticated();

      expect(state.isAuthenticated, isFalse);
      expect(state.userEmail, isNull);
      expect(state.identityPoolId, isNull);
      expect(state.lastAuthTime, isNull);
    });

    test('creates authenticated state', () {
      final state = AuthState.authenticated(
        userEmail: 'test@example.com',
        identityPoolId: 'us-east-1:12345',
      );

      expect(state.isAuthenticated, isTrue);
      expect(state.userEmail, equals('test@example.com'));
      expect(state.identityPoolId, equals('us-east-1:12345'));
      expect(state.lastAuthTime, isNotNull);
    });

    test('creates state with all fields', () {
      final now = DateTime.now();
      final state = AuthState(
        isAuthenticated: true,
        userEmail: 'user@example.com',
        identityPoolId: 'pool-id',
        lastAuthTime: now,
      );

      expect(state.isAuthenticated, isTrue);
      expect(state.userEmail, equals('user@example.com'));
      expect(state.identityPoolId, equals('pool-id'));
      expect(state.lastAuthTime, equals(now));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = AuthState.unauthenticated();
      final updated = original.copyWith(
        isAuthenticated: true,
        userEmail: 'new@example.com',
      );

      expect(updated.isAuthenticated, isTrue);
      expect(updated.userEmail, equals('new@example.com'));
      expect(original.isAuthenticated, isFalse);
    });

    test('toJson and fromJson round trip', () {
      final original = AuthState.authenticated(
        userEmail: 'test@example.com',
        identityPoolId: 'pool-id',
      );

      final json = original.toJson();
      final restored = AuthState.fromJson(json);

      expect(restored.isAuthenticated, equals(original.isAuthenticated));
      expect(restored.userEmail, equals(original.userEmail));
      expect(restored.identityPoolId, equals(original.identityPoolId));
      expect(
        restored.lastAuthTime?.millisecondsSinceEpoch,
        equals(original.lastAuthTime?.millisecondsSinceEpoch),
      );
    });

    test('toJson handles null fields', () {
      final state = AuthState.unauthenticated();
      final json = state.toJson();

      expect(json['isAuthenticated'], isFalse);
      expect(json['userEmail'], isNull);
      expect(json['identityPoolId'], isNull);
      expect(json['lastAuthTime'], isNull);
    });

    test('fromJson handles null fields', () {
      final json = {
        'isAuthenticated': false,
        'userEmail': null,
        'identityPoolId': null,
        'lastAuthTime': null,
      };

      final state = AuthState.fromJson(json);

      expect(state.isAuthenticated, isFalse);
      expect(state.userEmail, isNull);
      expect(state.identityPoolId, isNull);
      expect(state.lastAuthTime, isNull);
    });

    test('equality operator works correctly', () {
      final now = DateTime.now();
      final state1 = AuthState(
        isAuthenticated: true,
        userEmail: 'test@example.com',
        identityPoolId: 'pool-id',
        lastAuthTime: now,
      );
      final state2 = AuthState(
        isAuthenticated: true,
        userEmail: 'test@example.com',
        identityPoolId: 'pool-id',
        lastAuthTime: now,
      );
      final state3 = AuthState.unauthenticated();

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('hashCode is consistent', () {
      final now = DateTime.now();
      final state1 = AuthState(
        isAuthenticated: true,
        userEmail: 'test@example.com',
        lastAuthTime: now,
      );
      final state2 = AuthState(
        isAuthenticated: true,
        userEmail: 'test@example.com',
        lastAuthTime: now,
      );

      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('toString provides useful information', () {
      final state = AuthState.authenticated(
        userEmail: 'test@example.com',
        identityPoolId: 'pool-id',
      );

      final str = state.toString();

      expect(str, contains('AuthState'));
      expect(str, contains('true'));
      expect(str, contains('test@example.com'));
      expect(str, contains('pool-id'));
    });
  });
}
