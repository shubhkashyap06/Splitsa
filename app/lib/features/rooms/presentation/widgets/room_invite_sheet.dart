import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/remote/session.dart';
import '../../../../data/repositories/room_repository.dart';
import '../../../../shared/widgets/avatar_widget.dart';
import '../../../../shared/widgets/sheets.dart';
import 'room_icons.dart';

/// Room Invite sheet (UI_UX_SPEC.md §4 "Room Invite"): two tabs.
///   • From Room Detail: **Invite** (code + link to share) / **Join**
///   • From an empty Rooms tab: **Create** / **Join**
/// Joining always previews the room before confirming — never silent.
class RoomInviteSheet extends ConsumerStatefulWidget {
  const RoomInviteSheet._({this.roomId, this.roomName, this.initialJoinCode});

  final String? roomId;
  final String? roomName;
  final String? initialJoinCode;

  static Future<void> showInvite(
    BuildContext context, {
    required String roomId,
    required String roomName,
  }) => showAppSheet(
    context,
    (_) => RoomInviteSheet._(roomId: roomId, roomName: roomName),
  );

  static Future<void> showCreateOrJoin(
    BuildContext context, {
    String? joinCode,
  }) => showAppSheet(
    context,
    (_) => RoomInviteSheet._(initialJoinCode: joinCode),
  );

  @override
  ConsumerState<RoomInviteSheet> createState() => _RoomInviteSheetState();
}

class _RoomInviteSheetState extends ConsumerState<RoomInviteSheet> {
  late int _tab = widget.initialJoinCode != null ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final firstTab = widget.roomId != null ? 'Invite' : 'Create';
    return DarkSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tabs(
            labels: [firstTab, 'Join'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: AppSpacing.xl),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _tab == 1
                ? _JoinTab(initialCode: widget.initialJoinCode)
                : widget.roomId != null
                ? _InviteTab(
                    roomId: widget.roomId!,
                    roomName: widget.roomName ?? 'this room',
                  )
                : const _CreateTab(),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.btn : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: AppTextStyles.bodySemibold.copyWith(
                      color: i == index
                          ? AppColors.onBtn
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Create ────────────────────────────────────────────────────────────────

class _CreateTab extends ConsumerStatefulWidget {
  const _CreateTab();

  @override
  ConsumerState<_CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends ConsumerState<_CreateTab> {
  final _name = TextEditingController();
  String _icon = kRoomIconKeys.first;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final me = ref.read(currentUserIdProvider);
    if (me == null) return;
    try {
      final id = await ref
          .read(roomRepositoryProvider)
          .createRoom(name: _name.text, createdBy: me, icon: _icon);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/rooms/$id');
    } on RoomActionError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DarkField(
          controller: _name,
          label: 'Room name',
          hint: 'Flat 4B, Goa Trip…',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final key in kRoomIconKeys)
              GestureDetector(
                onTap: () => setState(() => _icon = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: key == _icon
                        ? AppColors.marigold.withValues(alpha: 0.15)
                        : AppColors.textPrimary.withValues(alpha: 0.05),
                    border: Border.all(
                      color: key == _icon
                          ? AppColors.marigold
                          : Colors.transparent,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    roomIcon(key),
                    size: 20,
                    color: key == _icon
                        ? AppColors.marigold
                        : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Works offline — invite people once you\'re back online.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        PillButton(label: 'Create room', onPressed: _create),
      ],
    );
  }
}

// ── Invite ────────────────────────────────────────────────────────────────

class _InviteTab extends ConsumerStatefulWidget {
  const _InviteTab({required this.roomId, required this.roomName});
  final String roomId;
  final String roomName;

  @override
  ConsumerState<_InviteTab> createState() => _InviteTabState();
}

class _InviteTabState extends ConsumerState<_InviteTab> {
  InviteCode? _invite;
  String? _error;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await ref
          .read(roomRepositoryProvider)
          .createInvite(widget.roomId);
      if (mounted) setState(() => _invite = invite);
    } on RoomActionError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    if (invite == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get a join code for ${widget.roomName}. It works for 7 days, up to 10 people.',
            style: AppTextStyles.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.rust),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PillButton(
            label: 'Get invite code',
            loading: _loading,
            onPressed: _generate,
          ),
        ],
      );
    }

    final link = invite.linkFor(AppConfig.instance.webOrigin);
    final shareText = link == null
        ? 'Join "${widget.roomName}" on Splitsa — code ${invite.displayCode}'
        : 'Join "${widget.roomName}" on Splitsa: $link (or use code ${invite.displayCode})';
    final daysLeft = invite.expiresAt.difference(DateTime.now()).inDays;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: AppColors.cardShadow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text('JOIN CODE', style: AppTextStyles.labelCaps),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                invite.displayCode.split('').join(' '),
                style: AppTextStyles.titleLarge.copyWith(
                  letterSpacing: 4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PillButton(
          label: link == null ? 'Copy invite' : 'Copy link',
          icon: Icons.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: shareText));
            if (context.mounted) {
              showToast(context, 'Invite copied — send it to the group');
            }
          },
        ),
      ],
    );
  }
}

// ── Join ──────────────────────────────────────────────────────────────────

class _JoinTab extends ConsumerStatefulWidget {
  const _JoinTab({this.initialCode});
  final String? initialCode;

  @override
  ConsumerState<_JoinTab> createState() => _JoinTabState();
}

class _JoinTabState extends ConsumerState<_JoinTab> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  RoomPreview? _preview;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialCode ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookUp());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ref
          .read(roomRepositoryProvider)
          .previewInvite(_code.text);
      if (mounted) setState(() => _preview = p);
    } on RoomActionError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    setState(() => _loading = true);
    try {
      final roomId = await ref
          .read(roomRepositoryProvider)
          .joinWithCode(_code.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/rooms/$roomId');
    } on RoomActionError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    if (preview == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DarkField(
            controller: _code,
            label: 'Join code',
            hint: 'e.g. K7MQ4X',
            autofocus: widget.initialCode == null,
            textCapitalization: TextCapitalization.characters,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: AppSpacing.xl),
          PillButton(label: 'Find room', loading: _loading, onPressed: _lookUp),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: AppColors.cardShadow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(roomIcon(preview.icon), color: AppColors.marigold, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preview.name, style: AppTextStyles.titleSmall),
                    Text(
                      '${preview.memberCount} member${preview.memberCount == 1 ? '' : 's'}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              AvatarStack(
                names: preview.memberNames,
                tones: [for (final n in preview.memberNames) _toneForName(n)],
                size: 26,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.rust),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PillButton(
          label: 'Join ${preview.name}',
          loading: _loading,
          onPressed: _join,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _preview = null),
            child: Text(
              'Wrong room? Try another code',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  static Color _toneForName(String n) {
    final tones = [
      AppColors.marigold,
      AppColors.jade,
      AppColors.rust,
      Color(0xFF7A86FF),
    ];
    return tones[n.hashCode.abs() % tones.length];
  }
}
