// ABOUTME: Invite status screen showing the authenticated user's invite info
// ABOUTME: Accessible from the My Profile more-options menu

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/invite_status/invite_status_bloc.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/providers/invite_code_provider.dart';

/// Screen displaying the authenticated user's invite status.
///
/// Creates the [InviteStatusBloc] and dispatches [InviteStatusRequested].
/// The [InviteStatusView] handles rendering based on BLoC state.
class InviteStatusScreen extends ConsumerWidget {
  const InviteStatusScreen({super.key});

  static const routeName = 'invite-status';
  static const path = '/invite-status';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(inviteCodeServiceProvider);

    return BlocProvider(
      create: (_) =>
          InviteStatusBloc(inviteCodeService: service)
            ..add(const InviteStatusRequested()),
      child: const InviteStatusView(),
    );
  }
}

/// View for the invite status screen.
///
/// Uses [BlocBuilder] to render loading, error, and success states.
class InviteStatusView extends StatelessWidget {
  @visibleForTesting
  const InviteStatusView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: VineTheme.navGreen,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.iconButtonBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                VineTheme.whiteText,
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text('Invites', style: VineTheme.titleFont()),
      ),
      body: BlocBuilder<InviteStatusBloc, InviteStatusState>(
        builder: (context, state) {
          return switch (state.status) {
            InviteStatusStatus.initial ||
            InviteStatusStatus.loading => const _LoadingView(),
            InviteStatusStatus.failure => _ErrorView(
              error: state.error ?? 'Failed to load invite status',
              onRetry: () => context.read<InviteStatusBloc>().add(
                const InviteStatusRequested(),
              ),
            ),
            InviteStatusStatus.success => _StatusView(
              result: state.result!,
              onRefresh: () {
                context.read<InviteStatusBloc>().add(
                  const InviteStatusRequested(),
                );
              },
            ),
          };
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: VineTheme.secondaryText,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.result, required this.onRefresh});

  final InviteCodeResult result;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusCard(result: result),
        if (result.code != null) ...[
          const SizedBox(height: 16),
          _InviteCodeCard(code: result.code!),
        ],
        if (result.claimedAt != null) ...[
          const SizedBox(height: 16),
          _ClaimedAtCard(claimedAt: result.claimedAt!),
        ],
        if (result.message != null) ...[
          const SizedBox(height: 16),
          _MessageCard(message: result.message!),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.result});

  final InviteCodeResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: result.valid
                  ? VineTheme.vineGreen.withAlpha(51)
                  : VineTheme.secondaryText.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              result.valid ? Icons.check_circle : Icons.cancel,
              color: result.valid
                  ? VineTheme.vineGreen
                  : VineTheme.secondaryText,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite Status',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.valid ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: result.valid
                        ? VineTheme.vineGreen
                        : VineTheme.secondaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite Code',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimedAtCard extends StatelessWidget {
  const _ClaimedAtCard({required this.claimedAt});

  final DateTime claimedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Claimed',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(claimedAt),
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
