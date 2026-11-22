bool get serialSupported => false;
Future<Stream<String>> openSerial(int baud) =>
    throw UnsupportedError('Serial input requires a Web Serial browser.');
