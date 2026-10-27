import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'tx_form_page.dart';

class TxSearchDelegate extends SearchDelegate<void> {
  final Repo repo;

  TxSearchDelegate(this.repo)
      : super(
          searchFieldLabel: 'Cari catatan, kategori, #tag, aset...',
          keyboardType: TextInputType.text,
        );

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Hapus teks',
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Kembali',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildInitialGuide(context);
    }
    return _buildList(context);
  }

  Widget _buildInitialGuide(BuildContext context) {
    return FutureBuilder<List<Tag>>(
      future: repo.tags(),
      builder: (context, snapshot) {
        final tags = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.search,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'Pencarian Transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ketik kata kunci untuk mencari berdasarkan catatan, kategori, deskripsi, aset, atau nama tag.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Saran Tag Populer:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in tags)
                    ActionChip(
                      label: Text('#${t.name}'),
                      onPressed: () {
                        query = t.name;
                        showResults(context);
                      },
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return FutureBuilder<List<TxItem>>(
      future: repo.searchTransactions(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 54, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ditemukan transaksi dengan kata kunci "$query".',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              child: Text(
                'Ditemukan ${items.length} transaksi',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: groupedTxWidgets(
                  context,
                  items,
                  (t) => openTxForm(context, edit: t),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

