import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.arrowUpRightFromSquare, size: 18),
            tooltip: 'Open externally',
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
      return const Center(
        child: Text('Could not parse this YouTube link. Use "Open externally".'),
      );
    }
    if (_webController != null) {
      return WebViewWidget(controller: _webController!);
    }
    return const SizedBox.shrink();
  }
}
