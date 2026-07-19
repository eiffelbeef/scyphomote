import 'package:flutter/material.dart';
import '../models/media_info.dart';
import '../services/jellyfin_api_service.dart';
import 'safe_network_image.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  final JellyfinApiService apiService;
  final void Function(String, String) onTap;

  const PersonCard({
    super.key,
    required this.person,
    required this.apiService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = apiService.getPersonImageUrl(person);

    return InkWell(
      onTap: () => onTap(person.id, person.name),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeNetworkImage(
              imageUrl: imageUrl,
              fallbackWidget: _personPlaceholder(context),
              width: 100,
              height: 150,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (person.role != null) ...[
              const SizedBox(height: 2),
              Text(
                person.role!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _personPlaceholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 100,
      height: 150,
      alignment: Alignment.center,
      color: colors.secondaryContainer,
      child: Icon(
        Icons.person_rounded, 
        size: 40,
        color: colors.onSecondaryContainer,
      ),
    );
  }
}
