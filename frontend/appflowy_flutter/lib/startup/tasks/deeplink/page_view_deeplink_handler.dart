import 'dart:async';

import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/startup/tasks/app_widget.dart'; // For AppGlobals
import 'package:appflowy/startup/tasks/deeplink/deeplink_handler.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

/// A DeepLink handler for opening specific page views based on workspace_id and view_id
/// 
/// Handles URLs in the format: appflowy-flutter://page-view?workspace_id={workspace_id}&view_id={view_id}
class PageViewDeepLinkHandler extends DeepLinkHandler<void> {
  @override
  bool canHandle(Uri uri) {
    // Check if this is a page-view deeplink
    return uri.host == 'page-view';
  }

  @override
  Future<FlowyResult<void, FlowyError>> handle({
    required Uri uri,
    required DeepLinkStateHandler onStateChange,
  }) async {
    Log.info('PageViewDeepLinkHandler: Processing URI: ${uri.toString()}');
    
    // Extract parameters
    final workspaceId = uri.queryParameters['workspace_id'];
    final viewId = uri.queryParameters['view_id'];

    // Validate parameters
    if (workspaceId == null || workspaceId.isEmpty) {
      final error = FlowyError(msg: 'Missing or empty workspace_id parameter in deeplink');
      Log.error('PageViewDeepLinkHandler: ${error.msg}');
      return FlowyResult.failure(error);
    }

    if (viewId == null || viewId.isEmpty) {
      final error = FlowyError(msg: 'Missing or empty view_id parameter in deeplink');
      Log.error('PageViewDeepLinkHandler: ${error.msg}');
      return FlowyResult.failure(error);
    }

    Log.info('PageViewDeepLinkHandler: Handling viewId: $viewId in workspace: $workspaceId');
    onStateChange(this, DeepLinkState.loading);

    // Fetch the view details
    final viewResult = await ViewBackendService.getView(viewId);

    return viewResult.fold(
      (ViewPB view) async {
        Log.info('PageViewDeepLinkHandler: Found view: ${view.name}');
        
        // Navigate to the view
        final context = AppGlobals.rootNavKey.currentContext;
        if (context == null) {
          final error = FlowyError(msg: 'Root context not available for navigation');
          Log.error('PageViewDeepLinkHandler: ${error.msg}');
          onStateChange(this, DeepLinkState.finish);
          return FlowyResult.failure(error);
        }

        try {
          if (UniversalPlatform.isMobile) {
            // Use mobile navigation
            await context.pushView(view);
            Log.info('PageViewDeepLinkHandler: Navigated on mobile to view: ${view.name}');
          } else {
            // Use desktop/web navigation via TabsBloc
            final tabsBloc = context.read<TabsBloc>();
            tabsBloc.add(TabsEvent.openPlugin(plugin: view.plugin(), view: view));
            Log.info('PageViewDeepLinkHandler: Navigated on desktop to view: ${view.name}');
          }
          
          onStateChange(this, DeepLinkState.finish);
          return FlowyResult.success(null);
        } catch (e, s) {
          final error = FlowyError(msg: 'Navigation failed: $e');
          Log.error('PageViewDeepLinkHandler: ${error.msg}', s);
          onStateChange(this, DeepLinkState.finish);
          return FlowyResult.failure(error);
        }
      },
      (FlowyError error) {
        Log.error('PageViewDeepLinkHandler: Failed to get view $viewId: $error');
        onStateChange(this, DeepLinkState.finish);
        return FlowyResult.failure(error);
      },
    );
  }
} 