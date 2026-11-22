import 'package:flutter/material.dart';
import '../intermediate_evaluation.dart';

/// Přístupný dialog s přehledem mezivýpočtů pro TalkBack i NVDA.
class IntermediateStepsDialog extends StatelessWidget {
  final IntermediateEvaluationResult result;
  final String title;
  final String closeButtonLabel;
  final String noStepsMessage;

  const IntermediateStepsDialog({
    super.key,
    required this.result,
    required this.title,
    required this.closeButtonLabel,
    required this.noStepsMessage,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      semanticLabel: title,
      title: Semantics(header: true, child: Text(title)),
      content: SizedBox(
        width: double.maxFinite,
        child: result.steps.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  noStepsMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: result.steps.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final step = result.steps[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(
                        '${step.stepIndex}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(
                      step.stepDescription,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontFamily: 'MathText'),
                    ),
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(closeButtonLabel),
        ),
      ],
    );
  }
}
