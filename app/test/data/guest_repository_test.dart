import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/guest_repository.dart';

void main() {
  test('guest data is discarded when a new guest session starts', () async {
    final first = await GuestRepository.create();
    final initial = await first.getProfile();
    await first.updateProfile(
      UserProfile(
        userId: initial.userId,
        monthlyBudgetMinor: initial.monthlyBudgetMinor,
        weeklyBudgetMinor: initial.weeklyBudgetMinor,
        goalName: '不應保存的訪客目標',
        goalTargetMinor: initial.goalTargetMinor,
        goalSavedMinor: initial.goalSavedMinor,
        goalDate: initial.goalDate,
        preferredTone: initial.preferredTone,
      ),
    );

    final second = await GuestRepository.create();

    expect((await second.getProfile()).goalName, isNot('不應保存的訪客目標'));
  });
}
