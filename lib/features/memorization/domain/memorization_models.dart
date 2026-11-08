enum MemorizationScope {
  surah('surah', 'Surah'),
  juz('juz', 'Juz'),
  range('range', 'Rentang ayat');

  const MemorizationScope(this.value, this.label);

  final String value;
  final String label;
}

enum MemorizationStatus {
  notStarted('not_started', 'Belum dimulai'),
  learning('learning', 'Sedang dipelajari'),
  inProgress('in_progress', 'Dalam proses'),
  needsReview('needs_review', 'Perlu diulang'),
  mastered('mastered', 'Dikuasai');

  const MemorizationStatus(this.value, this.label);

  final String value;
  final String label;

  static MemorizationStatus fromValue(String? value) => values.firstWhere(
    (status) => status.value == value,
    orElse: () => MemorizationStatus.notStarted,
  );
}

enum MemorizationSessionMode {
  learn('learn', 'Belajar'),
  hideReveal('hide_reveal', 'Sembunyikan & buka'),
  recall('recall', 'Latihan mengingat'),
  audio('audio_repetition', 'Pengulangan audio');

  const MemorizationSessionMode(this.value, this.label);

  final String value;
  final String label;
}

class MemorizationProgram {
  const MemorizationProgram({
    required this.id,
    required this.name,
    required this.scope,
    required this.startGlobalAyah,
    required this.endGlobalAyah,
    required this.dailyTarget,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final MemorizationScope scope;
  final int startGlobalAyah;
  final int endGlobalAyah;
  final int dailyTarget;
  final String createdAt;
  final String updatedAt;

  int get totalAyahs => endGlobalAyah - startGlobalAyah + 1;

  factory MemorizationProgram.fromMap(Map<String, Object?> map) =>
      MemorizationProgram(
        id: map['id']! as String,
        name: map['nama']! as String,
        scope: MemorizationScope.values.firstWhere(
          (scope) => scope.value == map['scope'],
        ),
        startGlobalAyah: map['start_global']! as int,
        endGlobalAyah: map['end_global']! as int,
        dailyTarget: map['daily_target']! as int,
        createdAt: map['dibuat_pada']! as String,
        updatedAt: map['diperbarui_pada']! as String,
      );
}

class MemorizationAyahProgress {
  const MemorizationAyahProgress({
    required this.globalAyahNumber,
    required this.status,
    required this.firstLearnedOn,
    required this.lastPracticedAt,
  });

  final int globalAyahNumber;
  final MemorizationStatus status;
  final String? firstLearnedOn;
  final String lastPracticedAt;

  factory MemorizationAyahProgress.fromMap(Map<String, Object?> map) =>
      MemorizationAyahProgress(
        globalAyahNumber: map['nomor_global']! as int,
        status: MemorizationStatus.fromValue(map['status'] as String?),
        firstLearnedOn: map['first_learned_on'] as String?,
        lastPracticedAt: map['last_practiced_at']! as String,
      );
}

class MemorizationSession {
  const MemorizationSession({
    required this.id,
    required this.programId,
    required this.mode,
    required this.dayKey,
    required this.startedAt,
    required this.completedAt,
    required this.newAyahCount,
    required this.repeatedAyahCount,
  });

  final String id;
  final String programId;
  final MemorizationSessionMode mode;
  final String dayKey;
  final String startedAt;
  final String? completedAt;
  final int newAyahCount;
  final int repeatedAyahCount;

  factory MemorizationSession.fromMap(Map<String, Object?> map) =>
      MemorizationSession(
        id: map['id']! as String,
        programId: map['program_id']! as String,
        mode: MemorizationSessionMode.values.firstWhere(
          (mode) => mode.value == map['mode'],
        ),
        dayKey: map['day_key']! as String,
        startedAt: map['started_at']! as String,
        completedAt: map['completed_at'] as String?,
        newAyahCount: map['new_ayah_count']! as int,
        repeatedAyahCount: map['repeated_ayah_count']! as int,
      );
}

class MemorizationSessionAyah {
  const MemorizationSessionAyah({
    required this.globalAyahNumber,
    required this.attempts,
    required this.newlyLearned,
    required this.result,
  });

  final int globalAyahNumber;
  final int attempts;
  final bool newlyLearned;
  final String? result;

  factory MemorizationSessionAyah.fromMap(Map<String, Object?> map) =>
      MemorizationSessionAyah(
        globalAyahNumber: map['nomor_global']! as int,
        attempts: map['attempts']! as int,
        newlyLearned: map['newly_learned']! as int == 1,
        result: map['result'] as String?,
      );
}

class MemorizationStatusChange {
  const MemorizationStatusChange({
    required this.globalAyahNumber,
    required this.oldStatus,
    required this.newStatus,
    required this.changedAt,
  });

  final int globalAyahNumber;
  final MemorizationStatus? oldStatus;
  final MemorizationStatus newStatus;
  final String changedAt;

  factory MemorizationStatusChange.fromMap(Map<String, Object?> map) =>
      MemorizationStatusChange(
        globalAyahNumber: map['nomor_global']! as int,
        oldStatus: map['old_status'] == null
            ? null
            : MemorizationStatus.fromValue(map['old_status'] as String),
        newStatus: MemorizationStatus.fromValue(map['new_status']! as String),
        changedAt: map['changed_at']! as String,
      );
}

class DailyMemorizationProgress {
  const DailyMemorizationProgress({
    required this.completedNewAyahs,
    required this.dailyTarget,
  });

  final int completedNewAyahs;
  final int dailyTarget;

  double get fraction =>
      dailyTarget == 0 ? 0 : (completedNewAyahs / dailyTarget).clamp(0, 1);
}
