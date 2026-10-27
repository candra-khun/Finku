import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'format.dart';

/// Dialog satu kolom teks. Mengembalikan teks (sudah di-trim) atau null.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  bool multiline = false,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 8 : 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            Navigator.pop(ctx, text.isEmpty ? null : text);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'Ya',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(okLabel)),
      ],
    ),
  );
  return result ?? false;
}

/// Dialog tambah grup aset. Mengembalikan id grup baru atau null.
Future<int?> showAddGroupDialog(BuildContext context, Repo repo) async {
  final name = await askText(context, title: 'Grup aset baru', label: 'Nama grup');
  if (name == null) return null;
  return repo.addGroup(name);
}

/// Dialog tambah aset (nama, grup, saldo awal). Mengembalikan id aset baru.
Future<int?> showAddAssetDialog(
  BuildContext context,
  Repo repo, {
  int? initialGroupId,
}) async {
  final groups = await repo.groups();
  if (!context.mounted) return null;
  final nameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController();
  int? groupId = initialGroupId ?? (groups.isEmpty ? null : groups.first.id);
  String? error;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Aset baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Nama aset', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: groupId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Grup', border: OutlineInputBorder()),
                items: [
                  for (final g in groups)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: (v) => setState(() => groupId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Saldo awal',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || groupId == null) {
                setState(() => error = 'Nama dan grup wajib diisi.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || groupId == null) return null;
  final initial = parseRibuan(balanceCtrl.text);
  return repo.addAsset(nameCtrl.text, groupId!, initial);
}

/// Dialog ubah data aset (nama, grup, saldo awal).
Future<bool> showEditAssetDialog(
  BuildContext context,
  Repo repo,
  Asset asset,
) async {
  final groups = await repo.groups();
  if (!context.mounted) return false;
  final nameCtrl = TextEditingController(text: asset.name);
  final balanceCtrl =
      TextEditingController(text: formatRibuan(asset.initialBalance));
  int? groupId = asset.groupId;
  String? error;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Ubah Aset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Nama aset', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: groupId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Grup', border: OutlineInputBorder()),
                items: [
                  for (final g in groups)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: (v) => setState(() => groupId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Saldo awal',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || groupId == null) {
                setState(() => error = 'Nama dan grup wajib diisi.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || groupId == null) return false;
  final initial = parseRibuan(balanceCtrl.text);
  await repo.updateAsset(
    asset.id,
    name: nameCtrl.text,
    groupId: groupId!,
    initialBalance: initial,
  );
  return true;
}

/// Dialog ubah nama grup aset.
Future<bool> showEditGroupDialog(
  BuildContext context,
  Repo repo,
  AssetGroup group,
) async {
  final name = await askText(
    context,
    title: 'Ubah Nama Grup',
    label: 'Nama grup',
    initial: group.name,
  );
  if (name == null || name.trim().isEmpty) return false;
  await repo.updateGroup(group.id, name);
  return true;
}

/// Dialog konfirmasi hapus grup aset.
Future<bool> showDeleteGroupDialog(
  BuildContext context,
  Repo repo,
  AssetGroup group,
) async {
  final count = await repo.groupAssetCount(group.id);
  final allGroups = await repo.groups();
  final otherGroups = allGroups.where((g) => g.id != group.id).toList();

  if (!context.mounted) return false;

  int? targetGroupId = otherGroups.isNotEmpty ? otherGroups.first.id : null;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Hapus Grup "${group.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (count > 0) ...[
              Text(
                'Grup ini memiliki $count aset aktif. Pilih grup tujuan pemindahan aset-aset tersebut sebelum grup ini dihapus:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: targetGroupId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pindahkan aset ke grup',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final g in otherGroups)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: (v) => setState(() => targetGroupId = v),
              ),
            ] else
              const Text('Grup ini kosong dan akan dihapus permanen.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (count > 0 && targetGroupId == null) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    ),
  );

  if (ok != true) return false;
  await repo.deleteGroup(group.id, targetGroupId: targetGroupId);
  return true;
}
