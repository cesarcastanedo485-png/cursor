import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/shell_providers.dart';

/// Deep link handler for /repos. Sets Cloud tab + Repos sub-tab, then pops.
class ReposRouteScreen extends ConsumerStatefulWidget {
  const ReposRouteScreen({super.key});

  @override
  ConsumerState<ReposRouteScreen> createState() => _ReposRouteScreenState();
}

class _ReposRouteScreenState extends ConsumerState<ReposRouteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainShellTabProvider.notifier).state = 0;
      ref.read(cloudAgentsSubTabProvider.notifier).state = 2;
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
