enum FileSystemEntityType { file, directory, link, notFound }

enum FileMode { read, write, append, writeOnly, writeOnlyAppend }

class FileStat {
  const FileStat({this.type = FileSystemEntityType.notFound, this.size = 0});

  final FileSystemEntityType type;
  final int size;
}

class FileSystemException implements Exception {
  const FileSystemException([this.message = '', this.path]);

  final String message;
  final String? path;

  @override
  String toString() => 'FileSystemException: $message${path ?? ''}';
}

class HttpHeaders {
  static const contentLengthHeader = 'content-length';
  static const rangeHeader = 'range';
}

class HttpStatus {
  static const ok = 200;
  static const partialContent = 206;
}

class File {
  const File(this.path);

  final String path;

  Directory get parent {
    final separator = path.lastIndexOf(RegExp(r'[/\\]'));
    return Directory(separator < 0 ? '' : path.substring(0, separator));
  }

  Future<bool> exists() async => false;

  Future<int> length() => _unsupported();

  Future<File> delete() => _unsupported();

  Future<File> rename(String newPath) => _unsupported();

  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) =>
      _unsupported();

  Future<FileStat> stat() async => const FileStat();

  Future<List<int>> readAsBytes() => _unsupported();

  Stream<List<int>> openRead([int? start, int? end]) => Stream.error(
    UnsupportedError('Local files are not available in Flutter Web preview.'),
  );

  static Future<T> _unsupported<T>() => Future<T>.error(
    UnsupportedError('Local files are not available in Flutter Web preview.'),
  );
}

class Directory {
  const Directory(this.path);

  final String path;

  Future<Directory> create({bool recursive = false}) => File._unsupported();
}
