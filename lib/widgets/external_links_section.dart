import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'themed_svg_icon.dart';

String? _svgAssetForLinkName(String name) => switch (name.toLowerCase()) {
      'imdb' => 'assets/imdb.svg',
      'tmdb' => 'assets/tmdb.svg',
      'tvdb' => 'assets/tvdb.svg',
      'trakt' => 'assets/trakt.svg',
      'musicbrainz' => 'assets/musicbrainz.svg',
      'lastfm' || 'last.fm' => 'assets/lastfm.svg',
      _ => null,
    };

class ExternalLinksSection extends StatelessWidget {
  final List<Map<String, dynamic>> externalUrls;

  const ExternalLinksSection({super.key, required this.externalUrls});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: externalUrls.map((link) {
        final linkName = link['Name'] as String? ?? '';
        final linkUrl = link['Url'] as String? ?? '';
        final svgAsset = _svgAssetForLinkName(linkName);
        return OutlinedButton.icon(
          onPressed: linkUrl.isNotEmpty
              ? () => launchUrl(
                  Uri.parse(linkUrl),
                  mode: LaunchMode.externalApplication,
                )
              : null,
          icon: svgAsset != null
              ? ThemedSvgIcon(
                  svgAsset,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                )
              : const Icon(Icons.link_rounded, size: 18),
          label: Text(linkName),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          ),
        );
      }).toList(),
    );
  }
}
