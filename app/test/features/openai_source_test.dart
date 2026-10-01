import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/features/capture/draft_editor.dart';
import 'package:futuremint_app/features/learning/learning_screen.dart';
import 'package:provider/provider.dart';

import '../widget_test.dart';

CaptureDraft openaiDraft() => CaptureDraft.fromJson({
  'draftId': 'openai-draft',
  'type': 'expense',
  'amountMinor': 75,
  'currency': 'TWD',
  'category': 'food',
  'occurredAt': '2026-07-13T12:00:00+08:00',
  'confidence': 0.94,
  'missingFields': <String>[],
  'needsConfirmation': true,
  'source': 'openai-ai',
});

Lesson openaiLesson() => Lesson.fromJson({
  'id': 'openai-lesson',
  'title': '合成課程',
  'concept': '合成概念',
  'example': '合成範例',
  'question': '合成問題',
  'options': ['合成選項'],
  'action': '合成行動',
  'disclaimer': '教育內容',
  'source': 'openai-ai',
});

LearningPlan openaiPlan() => LearningPlan.fromJson({
  'title': '合成規劃',
  'summary': '合成摘要',
  'modules': <Map<String, dynamic>>[],
  'disclaimer': '教育內容',
  'source': 'openai-ai',
});

void main() {
  test('OpenAI provenance survives capture lesson plan and coach parsing', () {
    final draft = openaiDraft();
    final lesson = openaiLesson();
    final plan = openaiPlan();
    final coach = CoachReply.fromJson({
      'answer': '合成回答',
      'takeaway': '合成重點',
      'suggestions': ['合成建議'],
      'disclaimer': '教育內容',
      'source': 'openai-ai',
    });
    for (final source in [
      draft.source,
      lesson.source,
      plan.source,
      coach.source,
    ]) {
      expect(source, CaptureSource.openaiAi);
      expect(source.isAi, isTrue);
    }
    expect(draft.toJson()['source'], 'openai-ai');
    expect(lesson.toJson()['source'], 'openai-ai');
    expect(
      CaptureDraft.fromJson(draft.toJson()).source,
      CaptureSource.openaiAi,
    );
    expect(CaptureSource.liangjieAi.isAi, isTrue);
    expect(CaptureSource.deterministicDemo.isAi, isFalse);
    expect(CaptureSource.manual.isAi, isFalse);
  });

  testWidgets('OpenAI draft keeps the existing AI parsing label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DraftEditor(
              draft: openaiDraft(),
              busy: false,
              onConfirm: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('AI 解析'), findsOneWidget);
    expect(find.text('離線規則解析'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OpenAI lesson and plan keep the existing AI selection labels', (
    tester,
  ) async {
    final controller = await createController();
    controller.lesson = openaiLesson();
    controller.learningPlan = openaiPlan();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: Scaffold(body: LearningScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 選題'), findsOneWidget);
    expect(find.text('AI 選題・教學資料庫'), findsOneWidget);
    expect(find.text('離線規劃'), findsNothing);
    expect(find.text('離線示範內容'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
