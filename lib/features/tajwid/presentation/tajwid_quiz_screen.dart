import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/tajwid_repository.dart';
import '../domain/tajwid_models.dart';

class TajwidQuizScreen extends StatefulWidget {
  const TajwidQuizScreen({
    super.key,
    required this.repository,
    this.questionCount = 10,
  });

  final TajwidRepository repository;
  final int questionCount;

  @override
  State<TajwidQuizScreen> createState() => _TajwidQuizScreenState();
}

class _TajwidQuizScreenState extends State<TajwidQuizScreen> {
  late List<TajwidQuestion> _questions;
  int _questionIndex = 0;
  int _correctAnswers = 0;
  int? _selectedIndex;
  bool _saving = false;
  TajwidQuizAttempt? _attempt;
  String? _saveError;

  TajwidQuestion get _question => _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _questions = widget.repository.createQuiz(
      questionCount: widget.questionCount,
    );
  }

  void _selectAnswer(int index) {
    if (_selectedIndex != null) return;
    setState(() {
      _selectedIndex = index;
      if (index == _question.correctIndex) _correctAnswers++;
    });
  }

  Future<void> _continue() async {
    if (_selectedIndex == null || _saving) return;
    if (_questionIndex + 1 < _questions.length) {
      setState(() {
        _questionIndex++;
        _selectedIndex = null;
      });
      return;
    }
    await _saveResult();
  }

  Future<void> _saveResult() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final attempt = await widget.repository.recordCompletedQuiz(
        totalQuestions: _questions.length,
        correctAnswers: _correctAnswers,
      );
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Hasil latihan gagal disimpan: $error';
      });
    }
  }

  void _restart() {
    setState(() {
      _questions = widget.repository.createQuiz(
        questionCount: widget.questionCount,
      );
      _questionIndex = 0;
      _correctAnswers = 0;
      _selectedIndex = null;
      _attempt = null;
      _saveError = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Latihan Tajwid')),
    body: _attempt == null ? _buildQuestion() : _buildResult(_attempt!),
  );

  Widget _buildQuestion() {
    final question = _question;
    final selected = _selectedIndex;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Soal ${_questionIndex + 1} dari ${_questions.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value:
              (_questionIndex + (selected == null ? 0 : 1)) / _questions.length,
          color: AppColors.gold,
        ),
        const SizedBox(height: 12),
        Chip(label: Text(question.type.label)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < question.options.length; index++)
          _AnswerOption(
            text: question.options[index],
            selected: selected == index,
            enabled: selected == null,
            correct: selected != null && index == question.correctIndex,
            incorrect: selected == index && index != question.correctIndex,
            onTap: () => _selectAnswer(index),
          ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${selected == question.correctIndex ? 'Benar.' : 'Belum tepat. '
                          'Jawaban yang benar: ${question.options[question.correctIndex]}.'}\n'
                '${question.explanation}',
              ),
            ),
          ),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 8),
          Text(
            _saveError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: selected == null || _saving ? null : _continue,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _saveError != null
                      ? 'Coba simpan lagi'
                      : _questionIndex + 1 == _questions.length
                      ? 'Simpan hasil'
                      : 'Lanjut',
                ),
        ),
        if (_saveError != null)
          TextButton(
            onPressed: _saving ? null : _saveResult,
            child: const Text('Ulangi penyimpanan hasil'),
          ),
        const SizedBox(height: 12),
        const Text(
          'Latihan ini menguji pemahaman materi melalui teks, bukan '
          'kemampuan pelafalan.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResult(TajwidQuizAttempt attempt) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 24),
      const Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.gold),
      const SizedBox(height: 12),
      Text(
        'Latihan selesai',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        '${attempt.correctAnswers} dari ${attempt.totalQuestions} jawaban benar',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      FutureBuilder<TajwidQuizProgress>(
        future: widget.repository.getProgress(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: const Text('Progres latihan tidak dapat dimuat.'),
                subtitle: Text('${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final progress = snapshot.data!;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(
                'Total latihan: ${progress.completedAttempts} · '
                'Skor terbaik: ${(progress.bestScoreFraction * 100).round()}%',
              ),
              subtitle: Text(
                '${progress.totalCorrectAnswers} dari '
                '${progress.totalAnsweredQuestions} jawaban benar '
                'tercatat di perangkat.',
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _restart,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Latihan lagi'),
      ),
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Kembali ke materi'),
      ),
    ],
  );
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.text,
    required this.selected,
    required this.enabled,
    required this.correct,
    required this.incorrect,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool enabled;
  final bool correct;
  final bool incorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = correct
        ? colors.secondaryContainer
        : incorrect
        ? colors.errorContainer
        : null;
    final icon = correct
        ? Icons.check_circle_outline_rounded
        : incorrect
        ? Icons.cancel_outlined
        : selected
        ? Icons.radio_button_checked_rounded
        : Icons.radio_button_unchecked_rounded;
    return Card(
      color: background,
      child: ListTile(
        enabled: enabled || selected || correct,
        leading: Icon(
          icon,
          color: correct
              ? colors.onSecondaryContainer
              : incorrect
              ? colors.onErrorContainer
              : null,
        ),
        title: Text(text),
        selected: selected,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
