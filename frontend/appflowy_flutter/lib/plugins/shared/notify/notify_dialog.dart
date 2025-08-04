import 'dart:convert';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class NotifyDialog extends StatefulWidget {
  const NotifyDialog({
    super.key,
    required this.view,
  });

  final ViewPB view;

  @override
  State<NotifyDialog> createState() => _NotifyDialogState();
}

class _NotifyDialogState extends State<NotifyDialog> {
  final TextEditingController _changesController = TextEditingController();
  final List<WorkspaceMemberPB> _members = [];
  final List<String> _selectedMemberEmails = [];
  bool _isLoading = true;
  String _workspaceId = '';

  @override
  void initState() {
    super.initState();
    _loadWorkspaceMembers();
  }

  @override
  void dispose() {
    _changesController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspaceMembers() async {
    try {
      // Get current workspace ID
      final workspaceResult = await UserBackendService.getCurrentWorkspace();
      _workspaceId = workspaceResult.fold(
        (workspace) => workspace.id,
        (error) {
          Log.error("[NotifyDialog] Failed to get workspace: $error");
          return '';
        },
      );

      // Fetch workspace members
      if (_workspaceId.isNotEmpty) {
        Log.info("[NotifyDialog] Fetching workspace members using UserEventGetWorkspaceMembers");
        final data = QueryWorkspacePB()..workspaceId = _workspaceId;
        final membersResult = await UserEventGetWorkspaceMembers(data).send();
        membersResult.fold(
          (membersList) {
            setState(() {
              _members.addAll(membersList.items);
              _isLoading = false;
            });
            Log.info("[NotifyDialog] Successfully fetched ${_members.length} workspace members");
          },
          (error) {
            Log.error("[NotifyDialog] Failed to get workspace members: $error");
            setState(() {
              _isLoading = false;
            });
          },
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.error("[NotifyDialog] Error getting workspace members: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendNotification() async {
    try {
      final changes = _changesController.text;
      final notifyPeople = _selectedMemberEmails.join(', ');
      Log.info("[NotifyDialog] Changes: $changes, Notify: $notifyPeople");

      Log.info("[NotifyDialog] About to send to WeChat webhook");
      await _sendChangesToWeChat(
        changes: changes,
        notifyPeople: notifyPeople,
        documentName: widget.view.nameOrDefault,
        workspaceId: _workspaceId,
        viewId: widget.view.id,
      );

      Log.info("[NotifyDialog] Webhook call completed");
      if (mounted) {
        Navigator.of(context).pop();

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sent successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      Log.info("[NotifyDialog] Dialog completed successfully");
    } catch (e) {
      Log.error("[NotifyDialog] Error in submit button handler: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendChangesToWeChat({
    required String changes,
    required String notifyPeople,
    required String documentName,
    required String workspaceId,
    required String viewId,
  }) async {
    try {
      Log.info("[NotifyDialog] Starting webhook send process");
      // WeChat webhook URL - hardcoded as requested
      const String webhookUrl =
          'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=3950f1b7-fff4-4a9d-b82a-24cc2a7e579b';

      // Format current time
      final now = DateTime.now();
      final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      Log.info("[NotifyDialog] Formatted time: $formattedTime");

      // Get current user name
      final userResult = await UserBackendService.getCurrentUserProfile();
      final editorName = userResult.fold(
        (userProfile) => userProfile.name,
        (error) {
          Log.error("[NotifyDialog] Failed to get user profile: $error");
          return "Unknown User";
        },
      );
      Log.info("[NotifyDialog] Editor name: $editorName");

      // Generate app and web links
      final appDocsUrl =
          'appflowy-flutter://page-view?workspace_id=$workspaceId&view_id=$viewId';
      final webDocsUrl = 'https://docs.uneedx.com/app/$workspaceId/$viewId';
      Log.info("[NotifyDialog] URLs: app=$appDocsUrl, web=$webDocsUrl");

      // Prepare message content in Markdown format
      final markdownContent = '''
#### 有人修改了文档
> **文档标题：** $documentName
> **修改时间：** $formattedTime
> **修改者：** $editorName
> **APP 链接：** [点击查看]($appDocsUrl)
> **WEB 链接：** [点击查看]($webDocsUrl)

**修改内容：** $changes
${notifyPeople.isNotEmpty ? '**需要通知：** $notifyPeople' : ''}
''';

      // Prepare message content
      final message = {
        'msgtype': 'markdown',
        'markdown': {
          'content': markdownContent,
        },
      };

      Log.info("[NotifyDialog] Sending HTTP POST request to webhook");
      // Send POST request
      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(message),
      );

      Log.info("[NotifyDialog] HTTP response status: ${response.statusCode}");
      Log.info("[NotifyDialog] HTTP response body: ${response.body}");

      if (response.statusCode != 200) {
        Log.error('Failed to send notification: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      } else {
        Log.info("[NotifyDialog] Successfully sent notification");
      }
    } catch (e) {
      Log.error("[NotifyDialog] Error sending notification: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notify Team Members'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _changesController,
              decoration: const InputDecoration(
                labelText: 'Changes Made',
                hintText: 'Describe the changes you made',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text('People to Notify:'),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator.adaptive())
            else if (_members.isEmpty)
              const Text(
                'No workspace members found.',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              Container(
                height: 200,
                width: double.maxFinite,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isSelected = _selectedMemberEmails.contains(member.email);

                    return CheckboxListTile(
                      title: Text(member.name),
                      subtitle: Text(member.email),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedMemberEmails.add(member.email);
                          } else {
                            _selectedMemberEmails.remove(member.email);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            if (_selectedMemberEmails.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedMemberEmails.map((email) {
                  final memberName = _members
                      .firstWhere(
                        (m) => m.email == email,
                        orElse: () => WorkspaceMemberPB(),
                      )
                      .name;
                  final displayText = memberName.isNotEmpty
                      ? '$memberName ($email)'
                      : email;

                  return Chip(
                    label: Text(displayText),
                    onDeleted: () {
                      setState(() {
                        _selectedMemberEmails.remove(email);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _sendNotification,
          child: const Text('Send'),
        ),
      ],
    );
  }
}