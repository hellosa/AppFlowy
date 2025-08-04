import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/shared/notify/notify_dialog.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class NotifyButton extends StatelessWidget {
  const NotifyButton({
    super.key,
    required this.view,
  });

  final ViewPB view;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: 'Notify team members',
      child: FlowyIconButton(
        width: 26,
        icon: const FlowySvg(
          FlowySvgs.notification_s,
          size: Size(16, 16),
        ),
        iconColorOnHover: Theme.of(context).colorScheme.onSecondary,
        onPressed: () => _showNotifyDialog(context),
      ),
    );
  }

  void _showNotifyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => NotifyDialog(view: view),
    );
  }
}