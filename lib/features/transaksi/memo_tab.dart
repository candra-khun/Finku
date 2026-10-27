import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dialogs.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Dialog tambah (edit == null) atau ubah memo.
Future<void> showMemoDialog(BuildContext context, {Memo? edit}) async {
  final repo = context.read<Repo>();
  final text = await askText(
    context,
    title: edit == null ? 'Memo baru' : 'Ubah memo',
    label: 'Isi memo',
    initial: edit?.content ?? '',
    multiline: true,
  );
  if (text == null) return;
  if (edit == null) {
    await repo.addMemo(text);
  } else {
    await repo.updateMemo(edit.id, text);
  }
}

class MemoTab extends StatelessWidget {
  const MemoTab({super.key});

  @override
  Widget build(BuildContext context) {
    return RepoFuture<List<Memo>>(
      load: (repo) => repo.memos(),
      builder: (context, memos) {
        if (memos.isEmpty) {
          return const EmptyState(
            icon: Icons.sticky_note_2_outlined,
            text: 'Belum ada memo.\nKetuk tombol di kanan bawah untuk menulis.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: memos.length,
          itemBuilder: (context, i) {
            final m = memos[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => showMemoDialog(context, edit: m),
                title: Text(m.content),
                subtitle: Text(tglPanjang(m.createdAt)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final repo = context.read<Repo>();
                    final ok = await confirm(
                      context,
                      title: 'Hapus memo?',
                      message: 'Memo ini akan dihapus.',
                      okLabel: 'Hapus',
                    );
                    if (ok) await repo.deleteMemo(m.id);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
