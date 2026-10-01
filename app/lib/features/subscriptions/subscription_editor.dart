import 'package:flutter/material.dart';
import '../../core/launch_models.dart';
import '../../core/models.dart';
import '../../state/app_controller.dart';

Future<void> showSubscriptionEditor(
  BuildContext context,
  AppController controller, {
  ActiveSubscription? subscription,
  MoneyEvent? legacy,
}) async {
  final createdAt = DateTime.now();
  var intentKey = 'subscription-${createdAt.microsecondsSinceEpoch}';
  String? lastFingerprint;
  final name = TextEditingController(
    text: subscription?.name ?? legacy?.merchant ?? '',
  );
  final amount = TextEditingController(
    text:
        (subscription?.amountMinor ?? legacy?.effectiveAmountMinor)
            ?.toString() ??
        '',
  );
  var cycle =
      subscription?.billingCycle ??
      legacy?.recurrence?.billingCycle ??
      BillingCycle.monthly;
  var anchor =
      subscription?.anchorDate ??
      legacy?.recurrence?.nextBillingAt ??
      DateTime.now();
  var initialPayment = false, busy = false;
  String? error;
  final form = GlobalKey<FormState>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, update) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subscription == null ? '建立追蹤中的訂閱' : '編輯訂閱',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('訂閱承諾與實際付款分開。停用追蹤不會刪除既有付款。'),
              if (legacy != null)
                const Text('這筆舊付款將保留；請明確確認方案與下一次續訂日期，不會再次記入付款。'),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: '訂閱名稱'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '請填入名稱。' : null,
              ),
              TextFormField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '每期自己的負擔（元）'),
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) > 0 ? null : '請填入正確金額。',
              ),
              DropdownButtonFormField<BillingCycle>(
                initialValue: cycle,
                decoration: const InputDecoration(labelText: '計費週期'),
                items: const [
                  DropdownMenuItem(
                    value: BillingCycle.monthly,
                    child: Text('月繳'),
                  ),
                  DropdownMenuItem(
                    value: BillingCycle.yearly,
                    child: Text('年繳'),
                  ),
                ],
                onChanged: busy ? null : (v) => update(() => cycle = v!),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('續訂日期／原始計費日'),
                subtitle: Text(dateOnly(anchor)),
                trailing: const Icon(Icons.calendar_month),
                onTap: busy
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: anchor,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null && sheet.mounted) {
                          update(() => anchor = date);
                        }
                      },
              ),
              if (subscription == null && legacy == null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: initialPayment,
                  onChanged: busy
                      ? null
                      : (v) => update(() => initialPayment = v!),
                  title: const Text('同時記入一筆今天已支付的款項'),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!(form.currentState?.validate() ?? false)) return;
                        update(() {
                          busy = true;
                          error = null;
                        });
                        final input = SubscriptionInput(
                          name: name.text.trim(),
                          amountMinor: int.parse(amount.text),
                          billingCycle: cycle,
                          anchorDate: anchor,
                        );
                        final fingerprint =
                            '${input.toJson()}|$initialPayment|${legacy?.id}';
                        if (lastFingerprint != null &&
                            lastFingerprint != fingerprint) {
                          intentKey =
                              'subscription-${DateTime.now().microsecondsSinceEpoch}';
                        }
                        lastFingerprint = fingerprint;
                        final saved = await controller.saveSubscription(
                          input,
                          id: subscription?.id,
                          idempotencyKey: intentKey,
                          legacyPaymentId: legacy?.id,
                          initialPayment: initialPayment
                              ? CaptureDraft(
                                  draftId: intentKey,
                                  type: MoneyEventType.subscription,
                                  amountMinor: input.amountMinor,
                                  currency: 'TWD',
                                  category: MoneyCategory.subscription,
                                  merchant: input.name,
                                  recurrence: RecurrenceDetails(
                                    billingCycle: input.billingCycle,
                                  ),
                                  occurredAt: createdAt,
                                  confidence: 1,
                                  missingFields: const [],
                                  needsConfirmation: true,
                                  source: CaptureSource.manual,
                                )
                              : null,
                        );
                        if (!sheet.mounted) return;
                        if (saved) {
                          Navigator.pop(sheet);
                        } else {
                          update(() {
                            busy = false;
                            error = controller.errorMessage;
                          });
                        }
                      },
                child: Text(busy ? '正在儲存…' : '確認儲存'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
  amount.dispose();
}
