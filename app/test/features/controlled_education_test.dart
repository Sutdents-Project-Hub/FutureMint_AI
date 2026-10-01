import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/api_repository.dart';
import 'package:futuremint_app/data/demo_repository.dart';
import 'package:futuremint_app/features/learning/learning_screen.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class ControlledRepo extends GuestRepository {
  ControlledRepo() : super.transient();
  @override
  Future<Lesson> generateLesson() async =>
      throw StateError('AI must not be called');
  @override
  Future<LearningPlan> getLearningPlan() async =>
      throw StateError('AI must not be called');
  @override
  Future<Lesson> completeLesson(Lesson lesson, String selectedOption) async =>
      throw StateError('Controlled completion must stay local');
}

void main() {
  for (final writable in [true, false]) {
    test(
      'refused AI reads and locally completes controlled material writable=$writable',
      () async {
        final controller = AppController(
          repository: ControlledRepo(),
          mode: AppMode.authenticated,
          canWrite: writable,
        );
        await controller.loadLesson();
        await controller.loadLearningPlan();
        expect(controller.lesson?.source, CaptureSource.manual);
        expect(controller.lesson?.id, startsWith('catalog-'));
        expect(controller.learningPlan, isNull);
        expect(controller.errorMessage, isNull);
        final option = controller.lesson!.options.first;
        await controller.completeLesson(option);
        expect(controller.lesson?.selectedOption, option);
        expect(controller.errorMessage, isNull);
        await controller.completeLesson('not an offered option');
        expect(controller.errorMessage, contains('請從課程提供的選項'));
        expect(controller.lesson?.selectedOption, option);
      },
    );
  }

  test(
    'API reads catalog only and never PATCHes its local completion',
    () async {
      final lesson = await ControlledRepo().getControlledLesson();
      final requests = <http.Request>[];
      final controller = AppController(
        mode: AppMode.authenticated,
        canWrite: false,
        repository: ApiRepository(
          baseUri: Uri.parse('https://example.test/api/'),
          client: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode({
                'data': {
                  'items': [lesson.toJson()],
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await controller.loadLesson();
      expect(controller.errorMessage, isNull);
      expect(controller.lesson, isNotNull);
      await controller.loadLearningPlan();
      await controller.completeLesson(lesson.options.first);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/education/catalog');
      expect(controller.lesson?.selectedOption, lesson.options.first);
      expect(controller.errorMessage, isNull);
    },
  );

  testWidgets(
    'readonly learning screen shows controlled material and local answer',
    (tester) async {
      final controller = AppController(
        repository: ControlledRepo(),
        mode: AppMode.authenticated,
        canWrite: false,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: Scaffold(body: LearningScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('受控教材'), findsOneWidget);
      final answer = find.text(controller.lesson!.options.first);
      await tester.ensureVisible(answer);
      await tester.tap(answer);
      await tester.pumpAndSettle();
      expect(
        controller.lesson?.selectedOption,
        controller.lesson!.options.first,
      );
      expect(find.text('你的下一步：${controller.lesson!.action}'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(controller.errorMessage, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
