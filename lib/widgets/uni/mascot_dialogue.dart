import 'dart:async';

import 'package:flutter/material.dart';

import 'archlord_mascot.dart';
import 'uni_mascot.dart';

/// Qui parle dans un [MascotDialogue].
enum DialogueSpeaker { archlord, uni }

/// Une réplique du dialogue.
class DialogueLine {
  final DialogueSpeaker who;
  final String text;

  const DialogueLine(this.who, this.text);
  const DialogueLine.archlord(this.text) : who = DialogueSpeaker.archlord;
  const DialogueLine.uni(this.text) : who = DialogueSpeaker.uni;
}

/// Cadence par défaut de l'avancement automatique : assez pour lire une
/// réplique courte, pas assez pour que l'écran paraisse figé.
const Duration kDialogueInterval = Duration(milliseconds: 3500);

/// Archlord et Uni côte à côte, qui échangent une liste de répliques.
///
/// Une bulle à la fois, au-dessus de celui qui parle ; on avance toutes les
/// [interval] et au toucher, en boucle. Celui qui parle bouge normalement
/// (et Archlord hoche la tête), celui qui écoute bouge à peine. Quand le
/// système demande moins de mouvement, toutes les répliques sont posées
/// statiquement, dans l'ordre, au-dessus des deux personnages.
///
/// Conçu pour tenir dans 360 px de large sans déborder : chaque personnage
/// occupe une moitié souple, la bulle se replie dans la sienne.
class MascotDialogue extends StatefulWidget {
  final List<DialogueLine> lines;
  final Duration interval;

  /// Hauteur des deux personnages.
  final double figureHeight;

  final ArchlordPose archlordPose;
  final UniPose uniPose;

  /// Revenir à la première réplique après la dernière.
  final bool loop;

  /// Avancer tout seul ; à `false`, seul le toucher fait avancer.
  final bool autoAdvance;

  const MascotDialogue({
    super.key,
    required this.lines,
    this.interval = kDialogueInterval,
    this.figureHeight = 120,
    this.archlordPose = ArchlordPose.explain,
    this.uniPose = UniPose.wave,
    this.loop = true,
    this.autoAdvance = true,
  });

  @override
  State<MascotDialogue> createState() => _MascotDialogueState();
}

class _MascotDialogueState extends State<MascotDialogue> {
  int _index = 0;
  Timer? _timer;

  DialogueLine get _current => widget.lines[_index];

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant MascotDialogue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines != widget.lines) _index = _index.clamp(0, widget.lines.length - 1);
    if (oldWidget.interval != widget.interval || oldWidget.autoAdvance != widget.autoAdvance) _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (!widget.autoAdvance || widget.lines.length < 2) return;
    if (!widget.loop && _index >= widget.lines.length - 1) return;
    _timer = Timer(widget.interval, _advance);
  }

  void _advance() {
    if (!mounted || widget.lines.isEmpty) return;
    final last = widget.lines.length - 1;
    if (_index >= last && !widget.loop) return;
    setState(() => _index = _index >= last ? 0 : _index + 1);
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Sans réplique, les deux personnages posent simplement côte à côte.
    if (widget.lines.isEmpty) return _figures(speaking: null);
    if (reduce) return _StaticDialogue(lines: widget.lines, figures: _figures(speaking: null));

    final speaker = _current.who;
    final bubble = UniBubble(
      key: ValueKey(_index),
      side: UniBubbleSide.top,
      child: Text(_current.text, textAlign: TextAlign.center),
    );

    return Semantics(
      button: true,
      label: 'Dialogue entre Archlord et Uni. Toucher pour la réplique suivante.',
      child: GestureDetector(
        onTap: _advance,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // `AnimatedSize` : la hauteur de la bulle suit le texte sans à-coup,
            // et les deux personnages descendent doucement au lieu de sauter.
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: speaker == DialogueSpeaker.archlord
                        ? Align(alignment: Alignment.bottomCenter, child: bubble)
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: speaker == DialogueSpeaker.uni
                        ? Align(alignment: Alignment.bottomCenter, child: bubble)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            _figures(speaking: speaker),
          ],
        ),
      ),
    );
  }

  /// Les deux personnages, chacun dans sa moitié. `speaking == null` : les
  /// deux au repos (mode statique).
  Widget _figures({required DialogueSpeaker? speaking}) {
    final archlordSpeaks = speaking == DialogueSpeaker.archlord;
    final uniSpeaks = speaking == DialogueSpeaker.uni;
    // Celui qui écoute respire à peine : le regard va vers celui qui parle.
    const listening = 0.35;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Center(
            child: ArchlordMascot(
              pose: widget.archlordPose,
              size: widget.figureHeight,
              talking: archlordSpeaks,
              intensity: speaking == null || archlordSpeaks ? 1 : listening,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Center(
            child: UniMascot(
              pose: widget.uniPose,
              size: widget.figureHeight * 0.92,
              effects: uniSpeaks,
              intensity: speaking == null || uniSpeaks ? 1 : listening,
            ),
          ),
        ),
      ],
    );
  }
}

/// Version sans mouvement : toutes les répliques, dans l'ordre, alignées du
/// côté de celui qui les dit, puis les deux personnages.
class _StaticDialogue extends StatelessWidget {
  final List<DialogueLine> lines;
  final Widget figures;

  const _StaticDialogue({required this.lines, required this.figures});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                if (line.who == DialogueSpeaker.uni) const Spacer(),
                Flexible(
                  flex: 4,
                  child: Align(
                    alignment: line.who == DialogueSpeaker.archlord ? Alignment.centerLeft : Alignment.centerRight,
                    // La pointe regarde celui qui parle : Archlord est à gauche,
                    // sa bulle s'accroche donc à sa droite ; l'inverse pour Uni.
                    child: UniBubble(
                      side: line.who == DialogueSpeaker.archlord ? UniBubbleSide.right : UniBubbleSide.left,
                      child: Text(line.text),
                    ),
                  ),
                ),
                if (line.who == DialogueSpeaker.archlord) const Spacer(),
              ],
            ),
          ),
        const SizedBox(height: 4),
        figures,
      ],
    );
  }
}
