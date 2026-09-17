import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/localization.dart';
import '../../data/local/database.dart';

class RecipeViewScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeViewScreen({super.key, required this.recipe});

  @override
  State<RecipeViewScreen> createState() => _RecipeViewScreenState();
}

class _RecipeViewScreenState extends State<RecipeViewScreen> {
  YoutubePlayerController? _ytController;
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    if (widget.recipe.sourceType == RecipeSourceType.video) {
      final videoId = YoutubePlayer.convertUrlToId(widget.recipe.sourceUrl);
      if (videoId != null) {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false),
        );
      }
    } else {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(widget.recipe.sourceUrl));
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.title),
        actions: [
          if (widget.recipe.sourceType != RecipeSourceType.video)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.kitchenSet, size: 18),
              tooltip: context.l10n.cookModeStart,
              // Replace rather than push: cooking mode offers "open the
              // page" too, and the two should not stack up endlessly.
              onPressed: () =>
                  context.pushReplacement('/cook', extra: widget.recipe),
            ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.arrowUpRightFromSquare, size: 18),
            tooltip: context.l10n.recipeViewOpenExternally,
            onPressed: () => launchUrl(
              Uri.parse(widget.recipe.sourceUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_ytController != null) {
      return YoutubePlayer(controller: _ytController!);
    }
    if (widget.recipe.sourceType == RecipeSourceType.video) {
      return Center(child: Text(context.l10n.recipeViewBadLink));
    }
    if (_webController != null) {
      return WebViewWidget(controller: _webController!);
    }
    return const SizedBox.shrink();
  }
}
