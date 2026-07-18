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
              const PageHeading(
                kicker: '三分鐘微',
                title: '練一個真正用得到的金錢選擇',
                description: '內容依合成紀錄挑選，重點是看懂選擇，不是考試。',
                accent: FutureMintTokens.lavenderInk,
              ),
              const SizedBox(height: FutureMintTokens.space5),
              if (plan != null) ...[
                _LearningPlanCard(plan: plan),
                const SizedBox(height: FutureMintTokens.space5),
              ],
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
        ),
      ),
    );
  }
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
            Chip(
              avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: Text(
                plan.source == CaptureSource.liangjieAi ? 'AI 規劃' : '離線規劃',
              ),
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final overlap = textScale < 1.5;
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
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
                    ),
                  ),
                  const SizedBox(width: FutureMintTokens.space3),
                  const MoneyBuddy(
                    size: 68,
                    color: FutureMintTokens.pink,
                    shape: MoneyBuddyShape.flower,
                    excludeSemantics: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: overlap ? 0 : FutureMintTokens.space3),
            Transform.translate(
              offset: Offset(0, overlap ? -8 : 0),
              child: _LessonSection(
                number: '01',
                title: '先看懂',
                body: lesson.concept,
                color: FutureMintTokens.lavenderSoft,
              ),
            ),
            SizedBox(height: overlap ? 0 : FutureMintTokens.space3),
            Transform.translate(
              offset: Offset(0, overlap ? -16 : 0),
              child: _LessonSection(
                number: '02',
                title: '放進生活',
                body: lesson.example,
                color: FutureMintTokens.mintSoft,
              ),
            ),
          ],
        ),
        SizedBox(
          height: overlap ? FutureMintTokens.space3 : FutureMintTokens.space5,
        ),
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
