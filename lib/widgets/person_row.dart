import 'package:flutter/material.dart';
import '../models/media_info.dart';
import '../services/jellyfin_api_service.dart';
import 'safe_network_image.dart';

class PersonRow extends StatelessWidget {
  final Person person;
  final JellyfinApiService apiService;
  final void Function(String, String) onTap;

  const PersonRow({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SafeNetworkImage(
              imageUrl: imageUrl,
              fallbackWidget: _personPlaceholder(context),
              width: 80,
              height: 120,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    person.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (person.role != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      person.role!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _personPlaceholder(BuildContext context) => Container(
    width: 80,
    height: 120,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.person_rounded, size: 32),
  );
}
