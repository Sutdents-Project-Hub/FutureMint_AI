import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppController>().loadLesson();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final lesson = controller.lesson;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '三分鐘，練一個金錢選擇',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('內容依合成紀錄挑選，重點是看懂選擇，不是考試。'),
              const SizedBox(height: 24),
              if (lesson == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: controller.busy
                        ? const Row(
                            children: [
                              SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(child: Text('正在準備個人化微課…')),
                            ],
                          )
                        : FilledButton.tonalIcon(
                            onPressed: controller.loadLesson,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重新載入微課'),
                          ),
                  ),
                )
              else
                _LessonCard(lesson: lesson, controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.controller});
  final Lesson lesson;
  final AppController controller;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                lesson.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(
                avatar: const Icon(Icons.school_outlined, size: 16),
                label: Text(
                  lesson.source == CaptureSource.azureAi
                      ? 'AI 個人化內容'
                      : '離線示範內容',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _LessonSection(number: '01', title: '先看懂', body: lesson.concept),
          const SizedBox(height: 20),
          _LessonSection(number: '02', title: '放進生活', body: lesson.example),
          const SizedBox(height: 24),
          Text(lesson.question, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final option in lesson.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor: lesson.selectedOption == option
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
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
                    const SizedBox(width: 10),
                    Expanded(child: Text(option)),
                  ],
                ),
              ),
            ),
          if (lesson.selectedOption != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text('你的下一步：${lesson.action}')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            lesson.disclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LessonSection extends StatelessWidget {
  const _LessonSection({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        number,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body),
          ],
        ),
      ),
    ],
  );
}
