import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/assignment_models.dart';
import '../providers/providers.dart';
import '../repositories/assignment_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/phosphor.dart';

/// Détail d'un devoir, côté élève : passer un quiz ou rendre un PDF/TD.
///
/// L'écran tient lieu à la fois de consultation et de rendu — un élève qui
/// ouvre un devoir veut le faire, pas le lire puis rouvrir un formulaire.
class AssignmentDetailScreen extends ConsumerStatefulWidget {
  final Assignment assignment;
  final Submission? submission;

  const AssignmentDetailScreen({
    super.key,
    required this.assignment,
    this.submission,
  });

  @override
  ConsumerState<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends ConsumerState<AssignmentDetailScreen> {
  /// Réponses en cours : identifiant de question → index, liste d'index, ou
  /// texte libre selon le type. La forme brute est conservée telle que
  /// `QuizGrader` l'attend.
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};

  final TextEditingController _commentController = TextEditingController();

  /// Photo du travail rendu, prise à l'appareil. C'est le mode de rendu réel
  /// pour un TD papier : l'élève photographie sa copie.
  XFile? _attached;
  bool _submitting = false;
  String? _error;

  /// Correction affichée après un rendu de quiz. `null` tant que l'élève n'a
  /// pas rendu.
  QuizResult? _result;

  @override
  void initState() {
    super.initState();

    final quiz = widget.assignment.quiz;
    if (quiz != null) {
      for (final question in quiz.questions) {
        if (question.type == QuestionType.text) {
          final controller = TextEditingController();
          _textControllers[question.id] = controller;
          _answers[question.id] = '';
        }
      }
    }

    // Un devoir déjà rendu se consulte en mode correction : les réponses
    // enregistrées sont rechargées dans le formulaire.
    final existing = widget.submission;
    if (existing != null && quiz != null) {
      final saved = existing.answers;
      for (final question in quiz.questions) {
        final value = saved[question.id];
        if (value == null) continue;
        _answers[question.id] = value;
        if (question.type == QuestionType.text) {
          _textControllers[question.id]?.text = value.toString();
        }
      }
      if (existing.score != null) {
        _result = QuizGrader.grade(quiz, saved);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _commentController.dispose();
    super.dispose();
  }

  bool get _alreadySubmitted => widget.submission != null;

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    // Un devoir noté ou expiré ne se reprend pas : le formulaire devient une
    // vue de consultation.
    final locked = _alreadySubmitted || !assignment.acceptsSubmission;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: assignment.title,
            subtitle: assignment.courseCode.isEmpty
                ? assignment.type.label
                : '${assignment.courseCode} · ${assignment.type.label}',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildMetaCard(),
                if (assignment.description != null && assignment.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildDescriptionCard(),
                ],
                if (assignment.hasFile) ...[
                  const SizedBox(height: 14),
                  _buildFileCard(),
                ],
                const SizedBox(height: 14),
                if (assignment.quiz != null) _buildQuizSection(locked) else _buildWorkSection(locked),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                if (!locked) _buildSubmitButton(),
                if (_alreadySubmitted) _buildGradedBanner(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── En-tête ────────────────────────────────────────────────────────────────

  Widget _buildMetaCard() {
    final assignment = widget.assignment;
    final now = DateTime.now();
    final remaining = assignment.dueDate.difference(now);
    final late = remaining.isNegative;

    final deadlineColor = _alreadySubmitted
        ? AppColors.success
        : late
            ? (assignment.allowLate ? AppColors.warning : AppColors.danger)
            : AppColors.primaryBlue;

    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetaTile(
                  icon: PhosphorIconsDuotone.calendarBlank,
                  label: 'Échéance',
                  value: DateFormat('dd/MM/yyyy à HH:mm').format(assignment.dueDate),
                  color: deadlineColor,
                ),
              ),
              Expanded(
                child: _MetaTile(
                  icon: PhosphorIconsDuotone.star,
                  label: 'Barème',
                  value: '${_number(assignment.maxScore)} points',
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetaTile(
                  icon: PhosphorIconsDuotone.clockCountdown,
                  label: 'Temps restant',
                  value:
                      late ? (assignment.allowLate ? 'Retard accepté' : 'Délai dépassé') : _remainingLabel(remaining),
                  color: deadlineColor,
                ),
              ),
              Expanded(
                child: _MetaTile(
                  icon: assignment.allowLate ? PhosphorIconsDuotone.lockOpen : PhosphorIconsDuotone.lock,
                  label: 'Retard',
                  value: assignment.allowLate ? 'Accepté' : 'Refusé',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (assignment.teacherName != null && assignment.teacherName!.trim().isNotEmpty) ...[
            const Divider(height: 28),
            Row(
              children: [
                const PhosphorIcon(PhosphorIconsBold.chalkboardTeacher, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Proposé par ${assignment.teacherName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Consignes'),
          const SizedBox(height: 10),
          Text(
            widget.assignment.description!.trim(),
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  /// Énoncé PDF/TD : le fichier est ouvert dans la visionneuse du système.
  ///
  /// On ne l'affiche pas dans l'application : un lecteur PDF embarqué pèserait
  /// plusieurs mégaoctets pour un rendu moins bon que celui du système, qui
  /// sait déjà zoomer, annoter et imprimer.
  Widget _buildFileCard() {
    final assignment = widget.assignment;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Énoncé'),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const PhosphorIcon(PhosphorIconsDuotone.filePdf, color: AppColors.danger, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  assignment.fileName ?? 'Énoncé du devoir',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openSubject,
              icon: const PhosphorIcon(PhosphorIconsBold.arrowSquareOut, size: 17),
              label: const Text('Ouvrir l\'énoncé'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primary100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quiz ───────────────────────────────────────────────────────────────────

  Widget _buildQuizSection(bool locked) {
    final quiz = widget.assignment.quiz!;

    if (quiz.questions.isEmpty) {
      return const SectionCard(
        child: Text(
          'Ce quiz ne contient aucune question. Signalez-le à votre enseignant.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Row(
            children: [
              const PhosphorIcon(PhosphorIconsDuotone.exam, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${quiz.questions.length} question${quiz.questions.length > 1 ? 's' : ''} · '
                  '${_number(quiz.totalPoints)} points au total'
                  '${quiz.durationMinutes != null ? ' · ${quiz.durationMinutes} min conseillées' : ''}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < quiz.questions.length; i++) ...[
          _buildQuestion(quiz.questions[i], i + 1, locked),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildQuestion(QuizQuestion question, int number, bool locked) {
    QuestionOutcome? outcome;
    for (final candidate in _result?.outcomes ?? const <QuestionOutcome>[]) {
      if (candidate.question.id == question.id) {
        outcome = candidate;
        break;
      }
    }

    // Une fois corrigé, la question porte la couleur du résultat : l'élève
    // balaie la page et voit ce qui est juste sans lire les points.
    final accent = outcome == null
        ? AppColors.primaryBlue
        : outcome.isCorrect
            ? AppColors.success
            : AppColors.danger;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.prompt,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_number(question.points)} pt${question.points > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          switch (question.type) {
            QuestionType.single => _buildSingleChoice(question, locked),
            QuestionType.multiple => _buildMultipleChoice(question, locked),
            QuestionType.text => _buildFreeText(question, locked),
          },
          if (outcome != null && question.explanation != null && question.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhosphorIcon(PhosphorIconsDuotone.lightbulb, size: 15, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.explanation!,
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleChoice(QuizQuestion question, bool locked) {
    final selected = _answers[question.id];

    return Column(
      children: [
        for (var i = 0; i < question.choices.length; i++)
          _ChoiceRow(
            label: question.choices[i],
            selected: selected == i,
            // Après correction, la bonne réponse est montrée même si l'élève
            // ne l'a pas cochée.
            isAnswer: _result != null && question.correct.contains(i),
            onTap: locked ? null : () => setState(() => _answers[question.id] = i),
          ),
      ],
    );
  }

  Widget _buildMultipleChoice(QuizQuestion question, bool locked) {
    final selected = (_answers[question.id] as List?)?.cast<int>() ?? <int>[];

    return Column(
      children: [
        for (var i = 0; i < question.choices.length; i++)
          _ChoiceRow(
            label: question.choices[i],
            selected: selected.contains(i),
            isAnswer: _result != null && question.correct.contains(i),
            onTap: locked
                ? null
                : () => setState(() {
                      final next = [...selected];
                      next.contains(i) ? next.remove(i) : next.add(i);
                      _answers[question.id] = next;
                    }),
          ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Plusieurs réponses possibles — toutes les bonnes réponses sont exigées.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildFreeText(QuizQuestion question, bool locked) {
    final controller = _textControllers[question.id]!;
    // La réponse libre se compare à l'identique après normalisation : la
    // consigne doit le dire, sinon l'élève écrit une phrase et perd le point.
    final hint = question.expected != null && question.expected!.trim().isNotEmpty
        ? 'Réponse attendue : un mot ou une expression courte'
        : 'Votre réponse';

    return TextField(
      controller: controller,
      enabled: !locked,
      maxLines: 3,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (value) => _answers[question.id] = value,
      decoration: InputDecoration(hintText: hint, filled: true, fillColor: AppColors.inputFill),
    );
  }

  // ── PDF / TD ───────────────────────────────────────────────────────────────

  Widget _buildWorkSection(bool locked) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Mon rendu'),
          const SizedBox(height: 12),
          if (_alreadySubmitted) _buildSubmittedFile() else _buildAttachmentPicker(locked),
          const SizedBox(height: 16),
          const Text(
            'Commentaire pour l\'enseignant',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            enabled: !locked,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Précisez ce que vous avez fait, ou signalez une difficulté…',
              filled: true,
              fillColor: AppColors.inputFill,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPicker(bool locked) {
    if (_attached != null) {
      return Row(
        children: [
          const PhosphorIcon(PhosphorIconsDuotone.image, size: 18, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _attached!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: locked ? null : () => setState(() => _attached = null),
            icon: const PhosphorIcon(PhosphorIconsBold.x, size: 18),
            color: AppColors.danger,
            tooltip: 'Retirer',
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: locked ? null : _pickPhoto,
        icon: const PhosphorIcon(PhosphorIconsBold.camera, size: 18),
        label: const Text('Photographier mon travail'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primary100),
        ),
      ),
    );
  }

  Widget _buildSubmittedFile() {
    final submission = widget.submission!;
    return Row(
      children: [
        PhosphorIcon(
          submission.hasFile ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.notepad,
          size: 18,
          color: AppColors.success,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            submission.hasFile ? (submission.fileName ?? 'Pièce jointe rendue') : 'Rendu sans pièce jointe',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return PrimaryButton(
      label: widget.assignment.quiz != null ? 'Rendre mon devoir' : 'Marquer comme rendu',
      icon: PhosphorIconsFill.paperPlaneTilt,
      isLoading: _submitting,
      onPressed: _submitting ? null : _submit,
    );
  }

  Widget _buildGradedBanner() {
    final submission = widget.submission!;
    final graded = submission.score != null;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                graded ? PhosphorIconsFill.trophy : PhosphorIconsFill.hourglassMedium,
                size: 18,
                color: graded ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                graded ? 'Devoir noté' : 'En attente de correction',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (graded)
                Text(
                  '${_number(submission.score!)} / ${_number(widget.assignment.maxScore)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
          if (submission.feedback != null && submission.feedback!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                submission.feedback!.trim(),
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      // Une copie manuscrite doit rester lisible : on plafonne à 1600 px, ce
      // qui suffit largement pour du texte et divise le poids par dix.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _attached = picked;
      _error = null;
    });
  }

  Future<void> _openSubject() async {
    final repository = ref.read(assignmentRepositoryProvider);
    final url = repository.fileUrl(widget.assignment.fileId);
    if (url == null) return;

    final uri = Uri.parse(url);
    // `LaunchMode.externalApplication` : dans un navigateur intégré, un PDF
    // s'ouvre dans un cadre sans barre d'outils, sans moyen de le télécharger.
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Aucune application ne peut ouvrir ce fichier.');
    }
  }

  Future<void> _submit() async {
    final assignment = widget.assignment;
    final quiz = assignment.quiz;

    // Un quiz vide se rend, mais un quiz sans aucune réponse est presque
    // toujours un envoi par erreur : on le signale sans le bloquer, l'élève
    // reste maître de son choix.
    if (quiz != null && quiz.questions.isNotEmpty && _answers.values.every(_isBlank)) {
      final confirmed = await _confirm(
        title: 'Aucune réponse',
        message: 'Vous n\'avez répondu à aucune question. Rendre quand même ?',
      );
      if (!confirmed) return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw const AssignmentException('Session expirée.');

      final repository = ref.read(assignmentRepositoryProvider);

      String? fileId;
      String? fileName;
      final attached = _attached;
      if (attached != null) {
        final bytes = await attached.readAsBytes();
        final file = await repository.uploadFile(name: attached.name, bytes: bytes);
        fileId = file.$id;
        fileName = attached.name;
      }

      // Le quiz est corrigé ici et sa note enregistrée avec le rendu : sans
      // cela, un quiz à 40 questions resterait « en attente » alors que la
      // correction est déterministe et déjà connue du client.
      final result = quiz != null && quiz.questions.isNotEmpty ? QuizGrader.grade(quiz, _answers) : null;

      final submission = Submission(
        id: '',
        assignmentId: assignment.id,
        studentId: user.id,
        studentName: user.name,
        submittedAt: DateTime.now(),
        answersJson: quiz != null ? _encodeAnswers(_answers) : null,
        fileId: fileId,
        fileName: fileName,
        score: result?.scaledTo(assignment.maxScore),
        feedback: null,
        status: result != null ? SubmissionStatus.graded : SubmissionStatus.submitted,
        gradedAt: result != null ? DateTime.now() : null,
      );

      final saved = await repository.submit(submission);

      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.score != null
                ? 'Devoir rendu — note : ${_number(saved.score!)}/${_number(assignment.maxScore)}'
                : 'Devoir rendu. Votre enseignant le corrigera prochainement.',
          ),
        ),
      );
    } on AssignmentException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Le rendu a échoué : $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rendre'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  /// Les réponses voyagent en JSON dans une colonne texte : `int`, `List<int>`
  /// et `String` s'y sérialisent tels quels, et `QuizGrader` les relit sans
  /// conversion.
  String _encodeAnswers(Map<String, dynamic> answers) {
    final json = <String, dynamic>{};
    for (final entry in answers.entries) {
      final value = entry.value;
      if (value is List) {
        json[entry.key] = value.cast<int>();
      } else {
        json[entry.key] = value;
      }
    }
    return jsonEncode(json);
  }

  static bool _isBlank(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    return false;
  }

  static String _remainingLabel(Duration remaining) {
    if (remaining.inDays >= 1) {
      return '${remaining.inDays} j ${remaining.inHours % 24} h';
    }
    if (remaining.inHours >= 1) return '${remaining.inHours} h';
    return '${remaining.inMinutes} min';
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1).replaceAll('.', ',');
}

/// Choix de QCM, en radio (choix unique) ou en case (choix multiple).
///
/// Un seul widget pour les deux : la différence tient à `multiple`, ce qui
/// évite deux rendus divergents pour une même question.
class _ChoiceRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isAnswer;
  final VoidCallback? onTap;

  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.isAnswer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Après correction, la bonne réponse est encadrée de vert ; le choix de
    // l'élève, lui, garde la couleur de son résultat.
    final border = isAnswer
        ? AppColors.success
        : selected
            ? AppColors.primaryBlue
            : AppColors.inputBorder;
    final background = isAnswer
        ? AppColors.success.withValues(alpha: 0.07)
        : selected
            ? AppColors.primaryBlue.withValues(alpha: 0.05)
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: border, width: selected || isAnswer ? 1.5 : 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                PhosphorIcon(
                  selected ? PhosphorIconsFill.radioButton : PhosphorIconsBold.circle,
                  size: 19,
                  color: selected ? AppColors.primaryBlue : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: selected || isAnswer ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isAnswer) ...[
                  const SizedBox(width: 8),
                  const PhosphorIcon(PhosphorIconsFill.checkCircle, size: 16, color: AppColors.success),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Petit bloc « icône + libellé + valeur » de la carte d'en-tête.
class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PhosphorIcon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
