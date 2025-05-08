import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/plugins/document/application/document_appearance_cubit.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/plugins/document/presentation/banner.dart';
import 'package:appflowy/plugins/document/presentation/editor_drop_handler.dart';
import 'package:appflowy/plugins/document/presentation/editor_page.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/ai/widgets/ai_writer_scroll_wrapper.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/cover/document_immersive_cover.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/shared_context/shared_context.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/transaction_handler/editor_transaction_service.dart';
import 'package:appflowy/plugins/document/presentation/editor_style.dart';
import 'package:appflowy/shared/flowy_error_page.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/action_navigation/action_navigation_bloc.dart';
import 'package:appflowy/workspace/application/action_navigation/navigation_action.dart';
import 'package:appflowy/workspace/application/view/prelude.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_lock_status_bloc.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class DocumentPage extends StatefulWidget {
  const DocumentPage({
    super.key,
    required this.view,
    required this.onDeleted,
    required this.tabs,
    this.initialSelection,
    this.initialBlockId,
    this.fixedTitle,
  });

  final ViewPB view;
  final VoidCallback onDeleted;
  final Selection? initialSelection;
  final String? initialBlockId;
  final String? fixedTitle;
  final List<PickerTabType> tabs;

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage>
    with WidgetsBindingObserver {
  EditorState? editorState;
  Selection? initialSelection;
  late final documentBloc = DocumentBloc(documentId: widget.view.id)
    ..add(const DocumentEvent.initial());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    documentBloc.close();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      documentBloc.add(const DocumentEvent.clearAwarenessStates());
    } else if (state == AppLifecycleState.resumed) {
      documentBloc.add(const DocumentEvent.syncAwarenessStates());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<ActionNavigationBloc>()),
        BlocProvider.value(value: documentBloc),
        BlocProvider.value(
          value: ViewLockStatusBloc(view: widget.view)
            ..add(ViewLockStatusEvent.initial()),
        ),
        BlocProvider(
          create: (context) =>
              ViewBloc(view: widget.view)..add(const ViewEvent.initial()),
          lazy: false,
        ),
      ],
      child: BlocConsumer<ViewLockStatusBloc, ViewLockStatusState>(
        listenWhen: (prev, curr) => curr.isLocked != prev.isLocked,
        listener: (context, lockStatusState) {
          if (lockStatusState.isLoadingLockStatus) {
            return;
          }
          editorState?.editable = !lockStatusState.isLocked;
        },
        builder: (context, lockStatusState) {
          return BlocBuilder<DocumentBloc, DocumentState>(
            buildWhen: shouldRebuildDocument,
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              final editorState = state.editorState;
              this.editorState = editorState;
              final error = state.error;
              if (error != null || editorState == null) {
                Log.error(error);
                return Center(child: AppFlowyErrorPage(error: error));
              }

              if (state.forceClose) {
                widget.onDeleted();
                return const SizedBox.shrink();
              }

              return MultiBlocListener(
                listeners: [
                  BlocListener<ViewLockStatusBloc, ViewLockStatusState>(
                    listener: (context, state) =>
                        editorState.editable = !state.isLocked,
                  ),
                  BlocListener<ActionNavigationBloc, ActionNavigationState>(
                    listenWhen: (_, curr) => curr.action != null,
                    listener: onNotificationAction,
                  ),
                ],
                child: AiWriterScrollWrapper(
                  viewId: widget.view.id,
                  editorState: editorState,
                  child: buildEditorPage(context, state),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget buildEditorPage(
    BuildContext context,
    DocumentState state,
  ) {
    final editorState = state.editorState;
    if (editorState == null) {
      return const SizedBox.shrink();
    }

    final width = context.read<DocumentAppearanceCubit>().state.width;

    // avoid the initial selection calculation change when the editorState is not changed
    initialSelection ??= _calculateInitialSelection(editorState);

    final Widget child;
    if (UniversalPlatform.isMobile) {
      child = BlocBuilder<DocumentPageStyleBloc, DocumentPageStyleState>(
        builder: (context, styleState) => AppFlowyEditorPage(
          editorState: editorState,
          // if the view's name is empty, focus on the title
          autoFocus: widget.view.name.isEmpty ? false : null,
          styleCustomizer: EditorStyleCustomizer(
            context: context,
            width: width,
            padding: EditorStyleCustomizer.documentPadding,
            editorState: editorState,
          ),
          header: buildCoverAndIcon(context, state),
          initialSelection: initialSelection,
        ),
      );
    } else {
      child = EditorDropHandler(
        viewId: widget.view.id,
        editorState: editorState,
        isLocalMode: context.read<DocumentBloc>().isLocalMode,
        child: AppFlowyEditorPage(
          editorState: editorState,
          // if the view's name is empty, focus on the title
          autoFocus: widget.view.name.isEmpty ? false : null,
          styleCustomizer: EditorStyleCustomizer(
            context: context,
            width: width,
            padding: EditorStyleCustomizer.documentPadding,
            editorState: editorState,
          ),
          header: buildCoverAndIcon(context, state),
          initialSelection: initialSelection,
          placeholderText: (node) =>
              node.type == ParagraphBlockKeys.type && !node.isInTable
                  ? LocaleKeys.editor_slashPlaceHolder.tr()
                  : '',
        ),
      );
    }

    return Provider(
      create: (_) {
        final context = SharedEditorContext();
        final children = editorState.document.root.children;
        final firstDelta = children.firstOrNull?.delta;
        final isEmptyDocument =
            children.length == 1 && (firstDelta == null || firstDelta.isEmpty);
        if (widget.view.name.isEmpty && isEmptyDocument) {
          context.requestCoverTitleFocus = true;
        }
        return context;
      },
      dispose: (buildContext, editorContext) => editorContext.dispose(),
      child: EditorTransactionService(
        viewId: widget.view.id,
        editorState: state.editorState!,
        child: Column(
          children: [
            // the banner only shows on desktop
            if (state.isDeleted && UniversalPlatform.isDesktop)
              buildBanner(context),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget buildBanner(BuildContext context) {
    return DocumentBanner(
      viewName: widget.view.nameOrDefault,
      onRestore: () =>
          context.read<DocumentBloc>().add(const DocumentEvent.restorePage()),
      onDelete: () => context
          .read<DocumentBloc>()
          .add(const DocumentEvent.deletePermanently()),
    );
  }

  Widget buildCoverAndIcon(BuildContext context, DocumentState state) {
    final editorState = state.editorState;
    final userProfilePB = state.userProfilePB;
    if (editorState == null || userProfilePB == null) {
      return const SizedBox.shrink();
    }

    if (UniversalPlatform.isMobile) {
      return DocumentImmersiveCover(
        fixedTitle: widget.fixedTitle,
        view: widget.view,
        tabs: widget.tabs,
        userProfilePB: userProfilePB,
      );
    }

    final page = editorState.document.root;
    return Column(
      children: [
        DocumentCoverWidget(
          node: page,
          tabs: widget.tabs,
          editorState: editorState,
          view: widget.view,
          onIconChanged: (icon) async => ViewBackendService.updateViewIcon(
            view: widget.view,
            viewIcon: icon,
          ),
        ),
        _buildReportChangesButton(context),
      ],
    );
  }

  Widget _buildReportChangesButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 20.0),
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: () => _showReportChangesDialog(context),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          minimumSize: const Size(100, 32),
        ),
        child: const Text('Report Changes'),
      ),
    );
  }

  void _showReportChangesDialog(BuildContext context) async {
    final TextEditingController changesController = TextEditingController();
    final TextEditingController notifyPeopleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Document Changes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: changesController,
                decoration: const InputDecoration(
                  labelText: 'Changes Made',
                  hintText: 'Describe the changes you made',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notifyPeopleController,
                decoration: const InputDecoration(
                  labelText: 'People to Notify (Optional)',
                  hintText: 'Enter names of people to notify',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Get the workspace ID from the current workspace
                final workspaceResult = await ViewBackendService.getCurrentWorkspace();
                final workspaceId = workspaceResult.fold(
                  (workspace) => workspace.id,
                  (_) => '',
                );
                
                _sendChangesToWeChat(
                  changes: changesController.text,
                  notifyPeople: notifyPeopleController.text,
                  documentName: widget.view.nameOrDefault,
                  workspaceId: workspaceId,
                  viewId: widget.view.id,
                );
                Navigator.of(context).pop();
                
                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Changes reported successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendChangesToWeChat({
    required String changes,
    required String notifyPeople,
    required String documentName,
    required String workspaceId,
    required String viewId,
  }) async {
    try {
      // WeChat webhook URL - replace with your actual webhook URL
      const String webhookUrl = 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=f40546b0-859c-42d5-948e-31c48d8ae2f9';
      
      // Format current time
      final now = DateTime.now();
      final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      
      // Get current user name from userProfilePB in DocumentState
      final userProfile = context.read<DocumentBloc>().state.userProfilePB;
      final editorName = userProfile != null ? userProfile.name : "Unknown User";
      
      // Generate app and web links
      final appDocsUrl = 'appflowy-flutter://page-view?workspace_id=$workspaceId&view_id=$viewId';
      final webDocsUrl = 'https://docs.uneedx.com/app/$workspaceId/$viewId';
      
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
        }
      };
      
      // Send POST request
      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(message),
      );
      
      if (response.statusCode != 200) {
        Log.error('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      Log.error('Error sending notification: $e');
    }
  }

  void onNotificationAction(
    BuildContext context,
    ActionNavigationState state,
  ) {
    final action = state.action;
    if (action == null ||
        action.type != ActionType.jumpToBlock ||
        action.objectId != widget.view.id) {
      return;
    }

    final editorState = context.read<DocumentBloc>().state.editorState;
    if (editorState == null) {
      return;
    }

    final Path? path = _getPathFromAction(action, editorState);
    if (path != null) {
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: path)),
      );
    }
  }

  Path? _getPathFromAction(NavigationAction action, EditorState editorState) {
    final path = action.arguments?[ActionArgumentKeys.nodePath];
    if (path is int) {
      return [path];
    } else if (path is List<int>?) {
      if (path == null || path.isEmpty) {
        final blockId = action.arguments?[ActionArgumentKeys.blockId];
        if (blockId != null) {
          return _findNodePathByBlockId(editorState, blockId);
        }
      }
    }
    return path;
  }

  Path? _findNodePathByBlockId(EditorState editorState, String blockId) {
    final document = editorState.document;
    final startNode = document.root.children.firstOrNull;
    if (startNode == null) {
      return null;
    }

    final nodeIterator = NodeIterator(document: document, startNode: startNode);
    while (nodeIterator.moveNext()) {
      final node = nodeIterator.current;
      if (node.id == blockId) {
        return node.path;
      }
    }

    return null;
  }

  bool shouldRebuildDocument(DocumentState previous, DocumentState current) {
    // only rebuild the document page when the below fields are changed
    // this is to prevent unnecessary rebuilds
    //
    // If you confirm the newly added fields should be rebuilt, please update
    // this function.
    if (previous.editorState != current.editorState) {
      return true;
    }

    if (previous.forceClose != current.forceClose ||
        previous.isDeleted != current.isDeleted) {
      return true;
    }

    if (previous.userProfilePB != current.userProfilePB) {
      return true;
    }

    if (previous.isLoading != current.isLoading ||
        previous.error != current.error) {
      return true;
    }

    return false;
  }

  Selection? _calculateInitialSelection(EditorState editorState) {
    if (widget.initialSelection != null) {
      return widget.initialSelection;
    }

    if (widget.initialBlockId != null) {
      final path = _findNodePathByBlockId(editorState, widget.initialBlockId!);
      if (path != null) {
        editorState.selectionType = SelectionType.block;
        editorState.selectionExtraInfo = {
          selectionExtraInfoDoNotAttachTextService: true,
        };
        return Selection.collapsed(
          Position(
            path: path,
          ),
        );
      }
    }

    return null;
  }
}
