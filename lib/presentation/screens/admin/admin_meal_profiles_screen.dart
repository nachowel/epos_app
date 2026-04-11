import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/models/meal_adjustment_profile.dart';
import '../../providers/admin_meal_profiles_provider.dart';
import 'widgets/admin_scaffold.dart';

class AdminMealProfilesScreen extends ConsumerStatefulWidget {
  const AdminMealProfilesScreen({super.key});

  @override
  ConsumerState<AdminMealProfilesScreen> createState() =>
      _AdminMealProfilesScreenState();
}

class _AdminMealProfilesScreenState
    extends ConsumerState<AdminMealProfilesScreen> {
  _MealProfileFilter _filter = _MealProfileFilter.all;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminMealProfilesNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminMealProfilesState state = ref.watch(
      adminMealProfilesNotifierProvider,
    );
    final List<MealAdjustmentProfile> visibleProfiles = state.profiles
        .where((MealAdjustmentProfile profile) {
          switch (_filter) {
            case _MealProfileFilter.all:
              return true;
            case _MealProfileFilter.standard:
              return profile.kind == MealAdjustmentProfileKind.standard;
            case _MealProfileFilter.sandwich:
              return profile.kind == MealAdjustmentProfileKind.sandwich;
          }
        })
        .toList(growable: false);

    return AdminScaffold(
      title: 'Meal Profiles',
      currentRoute: '/admin/meal-profiles',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Manage both Standard Meal Profiles and Sandwich Profiles here. Create, duplicate, archive, or assign profiles without leaving the Meal Profiles screen.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppSizes.fontSm,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacingMd),
              ElevatedButton.icon(
                key: const ValueKey<String>('meal-profile-create-btn'),
                onPressed: state.isSaving ? null : () => _showCreateDialog(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Profile'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSizes.spacingSm,
              runSpacing: AppSizes.spacingSm,
              children: <Widget>[
                _ProfileFilterChip(
                  key: const ValueKey<String>('meal-profile-filter-all'),
                  label: 'All',
                  selected: _filter == _MealProfileFilter.all,
                  onSelected: () {
                    setState(() {
                      _filter = _MealProfileFilter.all;
                    });
                  },
                ),
                _ProfileFilterChip(
                  key: const ValueKey<String>('meal-profile-filter-standard'),
                  label: 'Standard',
                  selected: _filter == _MealProfileFilter.standard,
                  onSelected: () {
                    setState(() {
                      _filter = _MealProfileFilter.standard;
                    });
                  },
                ),
                _ProfileFilterChip(
                  key: const ValueKey<String>('meal-profile-filter-sandwich'),
                  label: 'Sandwich',
                  selected: _filter == _MealProfileFilter.sandwich,
                  onSelected: () {
                    setState(() {
                      _filter = _MealProfileFilter.sandwich;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          if (state.errorMessage != null)
            _MessageBanner(
              message: state.errorMessage!,
              color: AppColors.error,
            ),
          if (state.successMessage != null)
            _MessageBanner(
              message: state.successMessage!,
              color: AppColors.success,
            ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.profiles.isEmpty
                ? const Center(
                    child: Text(
                      'No meal profiles yet. Create one to get started.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : visibleProfiles.isEmpty
                ? Center(
                    child: Text(
                      'No ${_filterEmptyStateLabel(_filter)} profiles match this filter.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(adminMealProfilesNotifierProvider.notifier)
                        .load(),
                    child: ListView.builder(
                      itemCount: visibleProfiles.length,
                      itemBuilder: (BuildContext context, int index) {
                        final MealAdjustmentProfile profile =
                            visibleProfiles[index];
                        return _ProfileCard(
                          profile: profile,
                          productCount:
                              state.productCountByProfileId[profile.id] ?? 0,
                          healthStatus:
                              state.healthByProfileId[profile.id] ??
                              MealAdjustmentHealthStatus.invalid,
                          isSaving: state.isSaving,
                          onEdit: () =>
                              context.go('/admin/meal-profiles/${profile.id}'),
                          onDuplicate: () => _duplicateProfile(profile),
                          onArchive: () => _archiveProfile(profile),
                          onDelete: () => _confirmDeleteProfile(profile, state),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final MealAdjustmentProfileKind? kind =
        await showDialog<MealAdjustmentProfileKind>(
          context: context,
          builder: (BuildContext context) => const _ProfileTypePickerDialog(),
        );
    if (kind == null || !mounted) return;
    final _CreateProfileResult? result = await showDialog<_CreateProfileResult>(
      context: context,
      builder: (BuildContext context) => _CreateProfileDialog(kind: kind),
    );
    if (result == null) return;
    final int? profileId = await ref
        .read(adminMealProfilesNotifierProvider.notifier)
        .createProfile(
          name: result.name,
          description: result.description.isEmpty ? null : result.description,
          kind: result.kind,
          freeSwapLimit: result.freeSwapLimit,
        );
    if (profileId != null && mounted) {
      context.go('/admin/meal-profiles/$profileId');
    }
  }

  Future<void> _duplicateProfile(MealAdjustmentProfile profile) async {
    final int? newId = await ref
        .read(adminMealProfilesNotifierProvider.notifier)
        .duplicateProfile(profile.id);
    if (newId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile "${profile.name}" duplicated.')),
      );
    }
  }

  Future<void> _archiveProfile(MealAdjustmentProfile profile) async {
    if (!profile.isActive) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Archive profile?'),
        content: Text(
          'This will deactivate "${profile.name}". Products using it will continue working until reassigned.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const ValueKey<String>('meal-profile-archive-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref
        .read(adminMealProfilesNotifierProvider.notifier)
        .archiveProfile(profile.id);
  }

  Future<void> _confirmDeleteProfile(
    MealAdjustmentProfile profile,
    AdminMealProfilesState state,
  ) async {
    final int productCount = state.productCountByProfileId[profile.id] ?? 0;
    if (productCount > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete "${profile.name}" — it is still assigned to $productCount product(s).',
          ),
        ),
      );
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text(
          'This will permanently delete "${profile.name}" and all its components, extras, and pricing rules.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const ValueKey<String>('meal-profile-delete-confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref
        .read(adminMealProfilesNotifierProvider.notifier)
        .deleteProfile(profile.id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile card
// ───────────────────────���─────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.productCount,
    required this.healthStatus,
    required this.isSaving,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchive,
    required this.onDelete,
  });

  final MealAdjustmentProfile profile;
  final int productCount;
  final MealAdjustmentHealthStatus healthStatus;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isSandwich = profile.kind == MealAdjustmentProfileKind.sandwich;
    return Opacity(
      opacity: profile.isActive ? 1 : 0.62,
      child: Card(
        key: ValueKey<String>('meal-profile-card-${profile.id}'),
        margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
        child: ListTile(
          title: Text(
            profile.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (profile.description != null &&
                  profile.description!.isNotEmpty)
                Text(
                  profile.description!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: AppSizes.spacingXs),
              Wrap(
                spacing: AppSizes.spacingXs,
                runSpacing: AppSizes.spacingXs,
                children: <Widget>[
                  _StatusChip(
                    label: profile.isActive ? 'Active' : 'Archived',
                    color: profile.isActive
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  _StatusChip(
                    label: _profileKindBadgeLabel(profile.kind),
                    color: isSandwich ? AppColors.primary : AppColors.success,
                  ),
                  _StatusChip(
                    label: 'Health: ${healthStatus.name}',
                    color: _healthColor(healthStatus),
                  ),
                  _StatusChip(
                    label: '$productCount product(s)',
                    color: productCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  if (isSandwich)
                    const _StatusChip(
                      label: 'Bread + sauce + toast flow',
                      color: AppColors.textSecondary,
                    )
                  else
                    _StatusChip(
                      label: 'Free swaps: ${profile.freeSwapLimit}',
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _profileKindSummary(profile.kind),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: Wrap(
            spacing: AppSizes.spacingSm,
            children: <Widget>[
              OutlinedButton(
                key: ValueKey<String>('meal-profile-edit-${profile.id}'),
                onPressed: isSaving ? null : onEdit,
                child: const Text('Edit'),
              ),
              OutlinedButton(
                key: ValueKey<String>('meal-profile-dup-${profile.id}'),
                onPressed: isSaving ? null : onDuplicate,
                child: const Text('Duplicate'),
              ),
              if (profile.isActive)
                OutlinedButton(
                  key: ValueKey<String>('meal-profile-archive-${profile.id}'),
                  onPressed: isSaving ? null : onArchive,
                  child: const Text('Archive'),
                ),
              TextButton(
                key: ValueKey<String>('meal-profile-del-${profile.id}'),
                onPressed: isSaving ? null : onDelete,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────��───────────────────────────────────────────────────────
// Create dialog
// ─────────────────────────────���───────────────────────────────────────────────

class _CreateProfileResult {
  const _CreateProfileResult({
    required this.name,
    required this.description,
    required this.kind,
    required this.freeSwapLimit,
  });

  final String name;
  final String description;
  final MealAdjustmentProfileKind kind;
  final int freeSwapLimit;
}

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog({required this.kind});

  final MealAdjustmentProfileKind kind;

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _freeSwapController = TextEditingController(
    text: '0',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _freeSwapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSandwich = widget.kind == MealAdjustmentProfileKind.sandwich;
    return AlertDialog(
      title: Text('Create ${_profileKindName(widget.kind)}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CreateProfileHelperBanner(kind: widget.kind),
            const SizedBox(height: AppSizes.spacingSm),
            TextField(
              key: const ValueKey<String>('meal-profile-create-name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Profile name'),
              autofocus: true,
            ),
            const SizedBox(height: AppSizes.spacingSm),
            TextField(
              key: const ValueKey<String>('meal-profile-create-desc'),
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            if (!isSandwich) ...<Widget>[
              const SizedBox(height: AppSizes.spacingSm),
              TextField(
                key: const ValueKey<String>('meal-profile-create-swaps'),
                controller: _freeSwapController,
                decoration: const InputDecoration(labelText: 'Free swap limit'),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey<String>('meal-profile-create-submit'),
          onPressed: () {
            final String name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              _CreateProfileResult(
                name: name,
                description: _descriptionController.text.trim(),
                kind: widget.kind,
                freeSwapLimit:
                    int.tryParse(_freeSwapController.text.trim()) ?? 0,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// ──────────────────────���──────────────────────────��───────────────────────────
// Shared widgets
// ───────��─────────────���───────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ProfileFilterChip extends StatelessWidget {
  const _ProfileFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ProfileTypePickerDialog extends StatelessWidget {
  const _ProfileTypePickerDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Profile Type'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ProfileTypeChoiceTile(
              key: const ValueKey<String>('meal-profile-kind-standard'),
              kind: MealAdjustmentProfileKind.standard,
              onTap: () =>
                  Navigator.of(context).pop(MealAdjustmentProfileKind.standard),
            ),
            const SizedBox(height: AppSizes.spacingSm),
            _ProfileTypeChoiceTile(
              key: const ValueKey<String>('meal-profile-kind-sandwich'),
              kind: MealAdjustmentProfileKind.sandwich,
              onTap: () =>
                  Navigator.of(context).pop(MealAdjustmentProfileKind.sandwich),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ProfileTypeChoiceTile extends StatelessWidget {
  const _ProfileTypeChoiceTile({
    super.key,
    required this.kind,
    required this.onTap,
  });

  final MealAdjustmentProfileKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSizes.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: kind == MealAdjustmentProfileKind.sandwich
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _profileKindName(kind),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _StatusChip(
                  label: _profileKindBadgeLabel(kind),
                  color: kind == MealAdjustmentProfileKind.sandwich
                      ? AppColors.primary
                      : AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _profileKindSummary(kind),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateProfileHelperBanner extends StatelessWidget {
  const _CreateProfileHelperBanner({required this.kind});

  final MealAdjustmentProfileKind kind;

  @override
  Widget build(BuildContext context) {
    final bool isSandwich = kind == MealAdjustmentProfileKind.sandwich;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        isSandwich
            ? 'This sandwich profile defines editable bread surcharges, enabled free sauces, sandwich-only toast, and paid add-ins.'
            : 'This standard meal profile defines components, swaps, add-ins, and pricing rules.',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Color _healthColor(MealAdjustmentHealthStatus status) {
  switch (status) {
    case MealAdjustmentHealthStatus.valid:
      return AppColors.success;
    case MealAdjustmentHealthStatus.incomplete:
      return AppColors.warning;
    case MealAdjustmentHealthStatus.invalid:
      return AppColors.error;
  }
}

String _profileKindLabel(MealAdjustmentProfileKind kind) {
  return _profileKindName(kind);
}

String _profileKindName(MealAdjustmentProfileKind kind) {
  switch (kind) {
    case MealAdjustmentProfileKind.standard:
      return 'Standard Meal Profile';
    case MealAdjustmentProfileKind.sandwich:
      return 'Sandwich Profile';
  }
}

String _profileKindBadgeLabel(MealAdjustmentProfileKind kind) {
  switch (kind) {
    case MealAdjustmentProfileKind.standard:
      return 'STANDARD';
    case MealAdjustmentProfileKind.sandwich:
      return 'SANDWICH';
  }
}

String _profileKindSummary(MealAdjustmentProfileKind kind) {
  switch (kind) {
    case MealAdjustmentProfileKind.standard:
      return 'Standard meal behaviour with components, swaps, add-ins, and pricing rules.';
    case MealAdjustmentProfileKind.sandwich:
      return 'Sandwich behaviour with editable bread surcharges, free multi-select sauces, sandwich-only toast, and paid add-ins.';
  }
}

String _filterEmptyStateLabel(_MealProfileFilter filter) {
  switch (filter) {
    case _MealProfileFilter.all:
      return 'meal';
    case _MealProfileFilter.standard:
      return 'standard';
    case _MealProfileFilter.sandwich:
      return 'sandwich';
  }
}

enum _MealProfileFilter { all, standard, sandwich }
