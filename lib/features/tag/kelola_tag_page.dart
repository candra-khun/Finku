import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class KelolaTagPage extends StatelessWidget {
  const KelolaTagPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repo>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Tag'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTagDialog(context, repo),
        icon: const Icon(Icons.add),
        label: const Text('Tag Baru'),
      ),
      body: RepoFuture<List<Tag>>(
        load: (r) => r.tags(),
        builder: (context, tags) {
          if (tags.isEmpty) {
            return const Center(
              child: Text('Belum ada tag yang dibuat.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: tags.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  tag.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: FutureBuilder<int>(
                  future: repo.tagUsageCount(tag.id),
                  builder: (ctx, snap) {
                    final count = snap.data ?? 0;
                    return Text(
                      count > 0 ? '$count transaksi' : 'Belum dipakai di transaksi',
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Ubah nama tag',
                      onPressed: () => _showEditTagDialog(context, repo, tag),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      tooltip: 'Hapus tag',
                      onPressed: () => _showDeleteTagDialog(context, repo, tag),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddTagDialog(BuildContext context, Repo repo) async {
    final name = await askText(
      context,
      title: 'Tag Baru',
      label: 'Nama tag',
    );
    if (name == null || name.trim().isEmpty) return;
    await repo.addTag(name);
  }

  Future<void> _showEditTagDialog(
    BuildContext context,
    Repo repo,
    Tag tag,
  ) async {
    final name = await askText(
      context,
      title: 'Ubah Nama Tag',
      label: 'Nama tag',
      initial: tag.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await repo.updateTag(tag.id, name);
  }

  Future<void> _showDeleteTagDialog(
    BuildContext context,
    Repo repo,
    Tag tag,
  ) async {
    final usage = await repo.tagUsageCount(tag.id);
    if (!context.mounted) return;

    final ok = await confirm(
      context,
      title: 'Hapus Tag "${tag.name}"?',
      message: usage > 0
          ? 'Tag ini terpasang pada $usage transaksi. Tag akan dihapus dari transaksi-transaksi tersebut.'
          : 'Tag ini belum digunakan dan akan dihapus permanen.',
      okLabel: 'Hapus',
    );

    if (ok) {
      await repo.deleteTag(tag.id);
    }
  }
}

