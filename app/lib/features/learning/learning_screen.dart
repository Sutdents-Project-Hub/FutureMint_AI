import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../state/app_controller.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final _questionController = TextEditingController();
  String _topic = 'general';
  String _style = 'example';

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask(AppController controller) async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;
    await controller.askLearningCoach(
      topic: _topic,
      question: question,
      style: _style,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<AppController>();
      await controller.loadLesson();
      if (mounted) await controller.loadLearningPlan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final lesson = controller.lesson;
    final plan = controller.learningPlan;
    final gutter = FutureMintTokens.pageGutter(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        FutureMintTokens.space5,
        gutter,
        FutureMintTokens.space7,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FutureMintTokens.contentReading,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeading(
                    kicker: '三分鐘微課',
                    title: '練一個真正用得到的金錢選擇',
                    description: '內容依合成紀錄挑選，重點是看懂選擇，不是考試。',
                    accent: FutureMintTokens.lavenderInk,
                  ),
                  const _LearningDecorationStrip(),
                  const SizedBox(height: FutureMintTokens.space5),
                  if (plan != null) ...[
                    _LearningPlanCard(plan: plan),
                    const SizedBox(height: FutureMintTokens.space5),
                  ],
                  _LearningCoachCard(
                    questionController: _questionController,
                    topic: _topic,
                    style: _style,
                    reply: controller.learningCoachReply,
                    busy: controller.busy,
                    onTopicChanged: (value) => setState(() => _topic = value),
                    onStyleChanged: (value) => setState(() => _style = value),
                    onAsk: () => _ask(controller),
                  ),
                  const SizedBox(height: FutureMintTokens.space5),
                  if (lesson == null)
                    SoftCard(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? FutureMintTokens.darkSurfaceRaised
                          : FutureMintTokens.lavenderSoft,
                      child: controller.busy
                          ? const Row(
                              children: [
                                SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: FutureMintTokens.space3),
                                Expanded(child: Text('正在準備個人化微課…')),
                              ],
                            )
                          : FilledButton.tonalIcon(
                              onPressed: controller.loadLesson,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('重新載入微課'),
                            ),
                    )
                  else
                    _LessonContent(lesson: lesson, controller: controller),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningCoachCard extends StatelessWidget {
  const _LearningCoachCard({
    required this.questionController,
    required this.topic,
    required this.style,
    required this.reply,
    required this.busy,
    required this.onTopicChanged,
    required this.onStyleChanged,
    required this.onAsk,
  });

  final TextEditingController questionController;
  final String topic;
  final String style;
  final CoachReply? reply;
  final bool busy;
  final ValueChanged<String> onTopicChanged;
  final ValueChanged<String> onStyleChanged;
  final VoidCallback onAsk;

  static const topics = <String, String>{
    'general': '我最近的金錢困擾',
    'spending': '需要與想要',
    'subscription': '訂閱檢查',
    'compound': '複利與存錢',
    'risk': '波動與風險',
  };

  static const styles = <String, String>{
    'brief': '一句話重點',
    'example': '生活例子',
    'steps': '一步一步',
  };

  @override
  Widget build(BuildContext context) => SoftCard(
    key: const Key('learning-coach-card'),
    color: Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.mintSoft,
    borderWidth: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.forum_outlined),
            const SizedBox(width: FutureMintTokens.space2),
            Expanded(
              child: Text(
                '問問你的理財教練',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space2),
        const Text('不一定要選固定題目，也可以直接描述你現在遇到的情況。'),
        const SizedBox(height: FutureMintTokens.space3),
        Text('你想聊什麼？', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: FutureMintTokens.space2),
        Wrap(
          spacing: FutureMintTokens.space2,
          runSpacing: FutureMintTokens.space2,
          children: [
            for (final entry in topics.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: topic == entry.key,
                onSelected: (_) => onTopicChanged(entry.key),
              ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space3),
        TextField(
          key: const Key('learning-coach-question'),
          controller: questionController,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: '自由輸入你的問題',
            hintText: '例如：我常常月底不夠用，該先調整哪一類？',
            helperText: '請不要輸入姓名、帳號、卡號或其他可識別資料。',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: FutureMintTokens.space2),
        Text('希望怎麼解釋？', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: FutureMintTokens.space2),
        Wrap(
          spacing: FutureMintTokens.space2,
          runSpacing: FutureMintTokens.space2,
          children: [
            for (final entry in styles.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: style == entry.key,
                onSelected: (_) => onStyleChanged(entry.key),
              ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space3),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: questionController,
          builder: (context, value, _) => FilledButton.icon(
            key: const Key('ask-learning-coach'),
            onPressed: busy || value.text.trim().isEmpty ? null : onAsk,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('請教 AI'),
          ),
        ),
        if (reply != null) ...[
          const SizedBox(height: FutureMintTokens.space4),
          SoftCard(
            key: const Key('learning-coach-reply'),
            padding: const EdgeInsets.all(FutureMintTokens.space4),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF393368)
                : FutureMintTokens.lavenderSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(reply!.answer),
                const SizedBox(height: FutureMintTokens.space3),
                Text(
                  '帶走一句話：${reply!.takeaway}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: FutureMintTokens.space3),
                Wrap(
                  spacing: FutureMintTokens.space2,
                  runSpacing: FutureMintTokens.space2,
                  children: [
                    for (final suggestion in reply!.suggestions)
                      ActionChip(
                        label: Text(suggestion),
                        onPressed: () {
                          questionController.text = suggestion;
                        },
                      ),
                  ],
                ),
                const SizedBox(height: FutureMintTokens.space3),
                Text(
                  reply!.disclaimer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _LearningPlanCard extends StatelessWidget {
  const _LearningPlanCard({required this.plan});

  final LearningPlan plan;

  @override
  Widget build(BuildContext context) => SoftCard(
    color: Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.skySoft,
    borderWidth: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: FutureMintTokens.space3,
          runSpacing: FutureMintTokens.space2,
          children: [
            Text(plan.title, style: Theme.of(context).textTheme.titleLarge),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/mascot_peek_purple.png',
                  width: 132,
                  height: 132,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: FutureMintTokens.space2),
                Chip(
                  avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: Text(
                    plan.source == CaptureSource.liangjieAi ? 'AI 規劃' : '離線規劃',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space2),
        Text(plan.summary),
        const SizedBox(height: FutureMintTokens.space4),
        for (var index = 0; index < plan.modules.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: FutureMintTokens.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  key: Key('learning-plan-module-$index'),
                  radius: 16,
                  backgroundColor: plan.modules[index].status == 'current'
                      ? FutureMintTokens.mint
                      : FutureMintTokens.paper,
                  foregroundColor: plan.modules[index].status == 'current'
                      ? FutureMintTokens.paper
                      : FutureMintTokens.ink,
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: FutureMintTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.modules[index].title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: FutureMintTokens.space1),
                      Text(plan.modules[index].reason),
                      Text(
                        '下一步：${plan.modules[index].nextAction}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(plan.disclaimer, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _LessonContent extends StatelessWidget {
  const _LessonContent({required this.lesson, required this.controller});

  final Lesson lesson;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      key: const Key('learning-color-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          key: const Key('learning-soft-stack'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftCard(
              color: dark
                  ? FutureMintTokens.darkSurfaceRaised
                  : FutureMintTokens.lavenderSoft,
              radius: FutureMintTokens.radiusLarge,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showArtwork =
                      constraints.maxWidth >= 600 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.3;
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      Chip(
                        avatar: const Icon(Icons.school_outlined, size: 16),
                        label: Text(
                          lesson.source == CaptureSource.liangjieAi
                              ? 'AI 個人化內容'
                              : '離線示範內容',
                        ),
                      ),
                    ],
                  );
                  final artwork = Image.asset(
                    'assets/images/mascot_orange.png',
                    width: showArtwork ? 132 : 112,
                    height: showArtwork ? 132 : 112,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  );
                  if (!showArtwork) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        copy,
                        const SizedBox(height: FutureMintTokens.space2),
                        Align(alignment: Alignment.centerRight, child: artwork),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: FutureMintTokens.space3),
                      artwork,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: FutureMintTokens.space3),
            _LessonSection(
              number: '01',
              title: '先看懂',
              body: lesson.concept,
              color: FutureMintTokens.lavenderSoft,
            ),
            const SizedBox(height: FutureMintTokens.space3),
            _LessonSection(
              number: '02',
              title: '放進生活',
              body: lesson.example,
              color: FutureMintTokens.mintSoft,
            ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space5),
        Text(lesson.question, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: FutureMintTokens.space3),
        for (final option in lesson.options)
          Padding(
            padding: const EdgeInsets.only(bottom: FutureMintTokens.space3),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: lesson.selectedOption == option
                    ? dark
                          ? const Color(0xFF393368)
                          : FutureMintTokens.mintSoft
                    : Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: FutureMintTokens.space4,
                  vertical: FutureMintTokens.space3,
                ),
              ),
              onPressed: controller.busy
                  ? null
                  : () => controller.completeLesson(option),
              child: Row(
                children: [
                  Icon(
                    lesson.selectedOption == option
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  const SizedBox(width: FutureMintTokens.space3),
                  Expanded(child: Text(option)),
                ],
              ),
            ),
          ),
        if (lesson.selectedOption != null) ...[
          const SizedBox(height: FutureMintTokens.space2),
          SoftCard(
            padding: const EdgeInsets.all(FutureMintTokens.space4),
            radius: 16,
            color: dark ? const Color(0xFF393368) : FutureMintTokens.mintSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag_outlined),
                const SizedBox(width: FutureMintTokens.space3),
                Expanded(child: Text('你的下一步：${lesson.action}')),
              ],
            ),
          ),
        ],
        const SizedBox(height: FutureMintTokens.space5),
        Text(
          lesson.disclaimer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LearningDecorationStrip extends StatelessWidget {
  const _LearningDecorationStrip();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.only(top: FutureMintTokens.space1),
      child: Wrap(
        spacing: FutureMintTokens.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: const [
          _LearningCircle(size: 14, color: FutureMintTokens.lavenderInk),
          _LearningDiamond(size: 13, color: FutureMintTokens.skyInk),
          Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white54),
          _LearningCircle(size: 10, color: FutureMintTokens.teal),
        ],
      ),
    ),
  );
}

class _LearningCircle extends StatelessWidget {
  const _LearningCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LearningDiamond extends StatelessWidget {
  const _LearningDiamond({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: Container(width: size, height: size, color: color),
  );
}

class _LessonSection extends StatelessWidget {
  const _LessonSection({
    required this.number,
    required this.title,
    required this.body,
    required this.color,
  });

  final String number;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) => SoftCard(
    radius: FutureMintTokens.radiusLarge,
    color: Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurface
        : color,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? FutureMintTokens.lavender
                : FutureMintTokens.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: FutureMintTokens.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: FutureMintTokens.space2),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
}
