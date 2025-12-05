import 'package:flutter_test/flutter_test.dart';
import 'package:todo_planner/firebase_options.dart';

void main() {
  test('Firebase options are properly configured', () {
    expect(DefaultFirebaseOptions.android.projectId, 'todo-taskmanager-25ab4');
    expect(DefaultFirebaseOptions.ios.projectId, 'todo-taskmanager-25ab4');
    expect(DefaultFirebaseOptions.android.apiKey, isNotEmpty);
    expect(DefaultFirebaseOptions.ios.apiKey, isNotEmpty);
  });

  test('Firebase options have correct app IDs', () {
    expect(
      DefaultFirebaseOptions.android.appId,
      '1:1062148887754:android:b2eb23edbcbed5fa3c9033',
    );
    expect(
      DefaultFirebaseOptions.ios.appId,
      '1:1062148887754:ios:6158cf1851b546bd3c9033',
    );
  });

  test('Firebase options have correct storage bucket', () {
    expect(
      DefaultFirebaseOptions.android.storageBucket,
      'todo-taskmanager-25ab4.firebasestorage.app',
    );
    expect(
      DefaultFirebaseOptions.ios.storageBucket,
      'todo-taskmanager-25ab4.firebasestorage.app',
    );
  });
}
