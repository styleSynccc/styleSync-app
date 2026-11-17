// Test-only SDK fakes. No credentials, external network or Firebase service.
// Public platform interfaces are already installed transitively by FlutterFire.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as dbp;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as authp;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    as corep;
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart'
    as storagep;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

late Uint8List pixel;
const testUid = 'qa-only-user';
const garmentAsset = 'assets/images/tops/tshirt_black.png';

class QaCore extends corep.FirebasePlatform {
  QaCore(this.name);
  final String name;
  @override
  corep.FirebaseAppPlatform app([String name = '[DEFAULT]']) =>
      corep.FirebaseAppPlatform(
        this.name,
        const FirebaseOptions(
          apiKey: 'fake-key-no-network',
          appId: 'qa-only',
          messagingSenderId: '0',
          projectId: 'qa-only',
          storageBucket: 'qa-only.invalid',
        ),
      );
  @override
  List<corep.FirebaseAppPlatform> get apps => [app()];
}

class QaUser extends Fake
    with MockPlatformInterfaceMixin
    implements authp.UserPlatform {
  @override
  String get uid => testUid;
  @override
  String get email => 'qa@example.invalid';
  @override
  String get displayName => 'QA Student';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'fake-test-token';
}

class QaCredential extends authp.UserCredentialPlatform {
  QaCredential(QaAuth auth) : super(auth: auth, user: auth.currentUser);
}

class QaAuth extends authp.FirebaseAuthPlatform {
  authp.UserPlatform? user = QaUser();
  int registrations = 0, logins = 0, tokenCalls = 0;
  String? rejection;
  @override
  QaAuth delegateFor({required FirebaseApp app}) => this;
  @override
  QaAuth setInitialValues({
    authp.PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  authp.UserPlatform? get currentUser => user;
  @override
  Future<authp.UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    registrations++;
    if (rejection != null) {
      throw FirebaseException(plugin: 'firebase_auth', code: rejection!);
    }
    user = QaUser();
    return QaCredential(this);
  }

  @override
  Future<authp.UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    logins++;
    user = QaUser();
    return QaCredential(this);
  }
}

enum QaSentinel { delete, timestamp }

class QaFields extends dbp.FieldValueFactoryPlatform {
  @override
  dynamic delete() => QaSentinel.delete;
  @override
  dynamic serverTimestamp() => QaSentinel.timestamp;
}

class QaFirestore extends dbp.FirebaseFirestorePlatform {
  final documents = <String, Map<String, dynamic>>{};
  final writes = <String>[];
  final reads = <String>[];
  final changes = StreamController<void>.broadcast(sync: true);
  int sequence = 0;
  @override
  QaFirestore delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) => this;
  @override
  dbp.CollectionReferencePlatform collection(String collectionPath) =>
      QaCollection(this, collectionPath);
  @override
  dbp.DocumentReferencePlatform doc(String documentPath) =>
      QaDocument(this, documentPath);
  dbp.DocumentSnapshotPlatform snapshot(String path) =>
      dbp.DocumentSnapshotPlatform(
        this,
        path,
        documents[path],
        dbp.PigeonSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
      );
  List<String> pathsIn(String collection) => documents.keys
      .where(
        (p) =>
            p.startsWith('$collection/') &&
            p.split('/').length == collection.split('/').length + 1,
      )
      .toList();
  void set(String path, Map<String, dynamic> data, bool merge) {
    final result = merge
        ? Map<String, dynamic>.from(documents[path] ?? {})
        : <String, dynamic>{};
    data.forEach((key, value) {
      final v = value is dbp.FieldValuePlatform
          ? dbp.FieldValuePlatform.getDelegate(value)
          : value;
      if (v == QaSentinel.delete) {
        result.remove(key);
      } else {
        result[key] = v == QaSentinel.timestamp ? Timestamp.now() : v;
      }
    });
    documents[path] = result;
    writes.add(path);
    changes.add(null);
  }
}

class QaDocument extends dbp.DocumentReferencePlatform {
  QaDocument(this.memory, String path) : super(memory, path);
  final QaFirestore memory;
  @override
  Future<dbp.DocumentSnapshotPlatform> get([
    dbp.GetOptions options = const dbp.GetOptions(),
  ]) async {
    memory.reads.add(path);
    return memory.snapshot(path);
  }

  @override
  Future<void> set(
    Map<String, dynamic> data, [
    dbp.SetOptions? options,
  ]) async => memory.set(path, data, options?.merge == true);
  @override
  Future<void> delete() async {
    memory.documents.remove(path);
    memory.writes.add(path);
    memory.changes.add(null);
  }
}

class QaCollection extends dbp.CollectionReferencePlatform {
  QaCollection(this.memory, String path, {this.conditions = const [], this.cap})
    : super(memory, path);
  final QaFirestore memory;
  final List<List<dynamic>> conditions;
  final int? cap;
  @override
  dbp.DocumentReferencePlatform doc([String? path]) =>
      memory.doc('${this.path}/${path ?? 'auto-${++memory.sequence}'}');
  dbp.QuerySnapshotPlatform snapshot() {
    var paths = memory
        .pathsIn(path)
        .where(
          (p) => conditions.every((c) {
            final key = c[0] is dbp.FieldPath
                ? (c[0] as dbp.FieldPath).components.join('.')
                : c[0].toString();
            if (c[1] != '==') throw StateError('Unsupported fake query: $c');
            return memory.documents[p]![key] == c[2];
          }),
        );
    if (cap != null) paths = paths.take(cap!);
    return dbp.QuerySnapshotPlatform(
      paths.map(memory.snapshot).toList(),
      [],
      dbp.SnapshotMetadataPlatform(false, false),
    );
  }

  @override
  Future<dbp.QuerySnapshotPlatform> get([
    dbp.GetOptions options = const dbp.GetOptions(),
  ]) async {
    memory.reads.add(path);
    return snapshot();
  }

  @override
  Stream<dbp.QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    dbp.ListenSource source = dbp.ListenSource.defaultSource,
  }) async* {
    yield snapshot();
    yield* memory.changes.stream.map((_) => snapshot());
  }

  @override
  dbp.QueryPlatform where(List<List<dynamic>> conditions) => QaCollection(
    memory,
    path,
    conditions: [...this.conditions, ...conditions],
    cap: cap,
  );
  @override
  dbp.QueryPlatform limit(int limit) =>
      QaCollection(memory, path, conditions: conditions, cap: limit);
}

class QaStorage extends storagep.FirebaseStoragePlatform {
  QaStorage() : super(bucket: 'qa-only.invalid');
  final uploads = <String, Uint8List>{};
  final contentTypes = <String, String?>{};
  @override
  QaStorage delegateFor({required FirebaseApp app, required String bucket}) =>
      this;
  @override
  storagep.ReferencePlatform ref(String path) => QaReference(this, path);
}

class QaReference extends storagep.ReferencePlatform {
  QaReference(this.memory, String path) : super(memory, path);
  final QaStorage memory;
  @override
  storagep.TaskPlatform putData(
    Uint8List data, [
    storagep.SettableMetadata? metadata,
  ]) {
    memory.uploads[fullPath] = data;
    memory.contentTypes[fullPath] = metadata?.contentType;
    return QaTask();
  }

  @override
  Future<String> getDownloadURL() async => 'https://qa-only.invalid/$fullPath';
}

class QaTask extends storagep.TaskPlatform {
  @override
  storagep.TaskSnapshotPlatform get snapshot => QaTaskSnapshot();
  @override
  Future<storagep.TaskSnapshotPlatform> get onComplete async => snapshot;
}

class QaTaskSnapshot extends storagep.TaskSnapshotPlatform {
  QaTaskSnapshot()
    : super(storagep.TaskState.success, {
        'bytesTransferred': 1,
        'totalBytes': 1,
      });
}

class QaRequest {
  QaRequest(this.method, this.uri, this.bytes);
  final String method;
  final Uri uri;
  final List<int> bytes;
  String get body => utf8.decode(bytes, allowMalformed: true);
}

class QaHttpClient extends Fake implements HttpClient {
  final requests = <QaRequest>[];
  final Map<String, Object> responses = {};
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      QaHttpRequest(this, method, url);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  void close({bool force = false}) {}
  @override
  set autoUncompress(bool value) {}
}

class QaHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String, List<String>) action) {}
}

class QaHttpRequest extends Fake implements HttpClientRequest {
  QaHttpRequest(this.client, this.method, this.uri);
  final QaHttpClient client;
  @override
  final String method;
  @override
  final Uri uri;
  final data = <int>[];
  @override
  final HttpHeaders headers = QaHeaders();
  @override
  set followRedirects(bool value) {}
  @override
  set maxRedirects(int value) {}
  @override
  set contentLength(int value) {}
  @override
  set persistentConnection(bool value) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      data.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    client.requests.add(QaRequest(method, uri, data));
    final body = client.responses[uri.path];
    if (body == null) {
      throw StateError('Unexpected test HTTP: $method ${uri.path}');
    }
    if (body is Exception) throw body;
    if (body is Uint8List) return QaHttpResponse(body, 200);
    return QaHttpResponse(utf8.encode(jsonEncode(body)), 200);
  }
}

class QaHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  QaHttpResponse(this.bytes, this.statusCode);
  final List<int> bytes;
  @override
  final int statusCode;
  @override
  int get contentLength => bytes.length;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'test';
  @override
  HttpHeaders get headers => QaHeaders();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

int _appSequence = 0;

class FunctionalHarness {
  final auth = QaAuth();
  final db = QaFirestore();
  final storage = QaStorage();
  final http = QaHttpClient();
  final pickerCalls = <MethodCall>[];
  final notificationCalls = <MethodCall>[];
  String? pickedPath;
  corep.FirebasePlatform? _oldCore;
  corep.FirebasePlatform? _oldPackedCore;
  authp.FirebaseAuthPlatform? _oldAuth;
  storagep.FirebaseStoragePlatform? _oldStorage;
  dbp.FirebaseFirestorePlatform? _oldDb;
  dbp.FieldValueFactoryPlatform? _oldFields;
  Future<void> install() async {
    pixel = (await rootBundle.load(garmentAsset)).buffer.asUint8List();
    Get.testMode = true;
    _oldCore = corep.FirebasePlatform.instance;
    _oldPackedCore = Firebase.delegatePackingProperty;
    _oldAuth = authp.FirebaseAuthPlatform.instance;
    _oldStorage = storagep.FirebaseStoragePlatform.instance;
    _oldFields = dbp.FieldValueFactoryPlatform.instance;
    corep.FirebasePlatform.instance = QaCore('qa-isolated-${++_appSequence}');
    // firebase_core caches its delegate separately from the platform singleton.
    // Reset the documented testing hook so each test gets a distinct app name
    // and cannot reuse another test's cached Auth/Firestore/Storage facade.
    Firebase.delegatePackingProperty = corep.FirebasePlatform.instance;
    _oldDb = dbp.FirebaseFirestorePlatform.instance;
    authp.FirebaseAuthPlatform.instance = auth;
    dbp.FirebaseFirestorePlatform.instance = db;
    storagep.FirebaseStoragePlatform.instance = storage;
    dbp.FieldValueFactoryPlatform.instance = QaFields();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (call) async {
        pickerCalls.add(call);
        return pickedPath;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => {'identifier': 'Asia/Kuala_Lumpur'},
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        notificationCalls.add(call);
        return switch (call.method) {
          'initialize' ||
          'requestNotificationsPermission' ||
          'canScheduleExactNotifications' ||
          'requestExactAlarmsPermission' => true,
          _ => null,
        };
      },
    );
  }

  Future<void> dispose() async {
    Get.reset();
    for (final name in [
      'plugins.flutter.io/image_picker',
      'flutter_timezone',
      'dexterous.com/flutter/local_notifications',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
    corep.FirebasePlatform.instance = _oldCore!;
    Firebase.delegatePackingProperty = _oldPackedCore;
    authp.FirebaseAuthPlatform.instance = _oldAuth!;
    storagep.FirebaseStoragePlatform.instance = _oldStorage!;
    dbp.FirebaseFirestorePlatform.instance = _oldDb!;
    dbp.FieldValueFactoryPlatform.instance = _oldFields!;
    await db.changes.close();
  }

  Future<T> network<T>(Future<T> Function() body) async {
    final previous = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => http;
    try {
      return await HttpOverrides.runZoned(body, createHttpClient: (_) => http);
    } finally {
      debugNetworkImageHttpClientProvider = previous;
    }
  }

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        home: child,
        getPages: [
          for (final route in ['/home', '/user-setup', '/login'])
            GetPage(
              name: route,
              page: () => Scaffold(body: Text('Destination $route')),
            ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    // Native image decoding needs the real async event loop; fake time alone
    // can otherwise keep a network-image loading indicator alive indefinitely.
    await tester.runAsync(() async {
      for (final widget in tester.widgetList<Image>(find.byType(Image))) {
        final done = Completer<void>();
        final stream = widget.image.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (_, _) {
            if (!done.isCompleted) done.complete();
          },
          onError: (_, _) {
            if (!done.isCompleted) done.complete();
          },
        );
        stream.addListener(listener);
        try {
          await done.future.timeout(const Duration(seconds: 5));
        } finally {
          stream.removeListener(listener);
        }
      }
    });
    await tester.pumpAndSettle();
  }

  Future<File> imageFile(WidgetTester tester) async {
    return (await tester.runAsync(() async {
      final folder = await Directory.systemTemp.createTemp('stylesync-qa-');
      final file = File('${folder.path}${Platform.pathSeparator}synthetic.png');
      await file.writeAsBytes(pixel);
      addTearDown(() => folder.delete(recursive: true));
      return file;
    }))!;
  }
}
