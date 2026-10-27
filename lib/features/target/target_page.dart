import 'package:flutter/material.dart';

import 'goal_form_page.dart';
import 'target_goals_view.dart';

/// Halaman Mandiri Target Menabung (dapat dipanggil dari Menu Lainnya atau shortcut)
class TargetPage extends StatelessWidget {
  const TargetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Menabung (Goals)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openGoalForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Buat Target'),
      ),
      body: const TargetGoalsView(),
    );
  }
}

