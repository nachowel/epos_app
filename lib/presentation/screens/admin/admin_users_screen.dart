import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/errors/exceptions.dart';
import '../../../domain/models/user.dart';
import '../../providers/admin_users_provider.dart';
import '../../providers/auth_provider.dart';
import 'widgets/admin_scaffold.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminUsersNotifierProvider.notifier).loadUsers(),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _showAddCashierDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController pinController = TextEditingController();
    final TextEditingController confirmPinController = TextEditingController();
    bool isSaving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Add Cashier'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (error != null)
                      Container(
                        padding: const EdgeInsets.all(AppSizes.spacingSm),
                        margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                        color: AppColors.error.withValues(alpha: 0.1),
                        child: Text(error!, style: const TextStyle(color: AppColors.error)),
                      ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSizes.spacingMd),
                    TextField(
                      controller: pinController,
                      decoration: const InputDecoration(labelText: 'PIN'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      textInputAction: TextInputAction.next,
                    ),
                    TextField(
                      controller: confirmPinController,
                      decoration: const InputDecoration(labelText: 'Confirm PIN'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() {
                            error = null;
                            isSaving = true;
                          });

                          try {
                            if (pinController.text != confirmPinController.text) {
                              throw const ValidationException('PINs do not match.');
                            }

                            await ref
                                .read(adminUsersNotifierProvider.notifier)
                                .addCashier(
                                  name: nameController.text,
                                  pin: pinController.text,
                                );
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            setState(() {
                              error = e is ValidationException ? e.message : e.toString();
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add Cashier'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditUserDialog(User user) async {
    final TextEditingController nameController = TextEditingController(text: user.name);
    bool isActive = user.isActive;
    bool isSaving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Edit ${user.name}'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (error != null)
                      Container(
                        padding: const EdgeInsets.all(AppSizes.spacingSm),
                        margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                        color: AppColors.error.withValues(alpha: 0.1),
                        child: Text(error!, style: const TextStyle(color: AppColors.error)),
                      ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: AppSizes.spacingMd),
                    SwitchListTile(
                      title: const Text('Active Account'),
                      value: isActive,
                      onChanged: (bool value) {
                        setState(() => isActive = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() {
                            error = null;
                            isSaving = true;
                          });

                          try {
                            await ref
                                .read(adminUsersNotifierProvider.notifier)
                                .updateUser(
                                  id: user.id,
                                  name: nameController.text,
                                  isActive: isActive,
                                );
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            setState(() {
                              error = e is ValidationException ? e.message : e.toString();
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChangePinDialog(User user) async {
    final TextEditingController pinController = TextEditingController();
    final TextEditingController confirmPinController = TextEditingController();
    bool isSaving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Change PIN for ${user.name}'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (error != null)
                      Container(
                        padding: const EdgeInsets.all(AppSizes.spacingSm),
                        margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                        color: AppColors.error.withValues(alpha: 0.1),
                        child: Text(error!, style: const TextStyle(color: AppColors.error)),
                      ),
                    TextField(
                      controller: pinController,
                      decoration: const InputDecoration(labelText: 'New PIN'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      textInputAction: TextInputAction.next,
                    ),
                    TextField(
                      controller: confirmPinController,
                      decoration: const InputDecoration(labelText: 'Confirm New PIN'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() {
                            error = null;
                            isSaving = true;
                          });

                          try {
                            if (pinController.text != confirmPinController.text) {
                              throw const ValidationException('PINs do not match.');
                            }

                            await ref
                                .read(adminUsersNotifierProvider.notifier)
                                .changePin(
                                  id: user.id,
                                  newPin: pinController.text,
                                );
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            setState(() {
                              error = e is ValidationException ? e.message : e.toString();
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Change PIN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersNotifierProvider);
    final currentUser = ref.watch(authNotifierProvider).currentUser;

    return AdminScaffold(
      title: 'Users Management',
      currentRoute: '/admin/users',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _showAddCashierDialog,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Add Cashier'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingMd),
          if (state.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(AppSizes.spacingMd),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Text(state.errorMessage!, style: const TextStyle(color: AppColors.error)),
            ),
          if (state.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.separated(
                itemCount: state.users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final User user = state.users[index];
                  final bool isSuperAdmin = user.id == 1; // Basic safety rendering measure if ID 1 is the main admin
                  final bool isSelf = currentUser?.id == user.id;

                  return Card(
                    elevation: 0,
                    color: AppColors.surface,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.spacingMd),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: user.isActive ? AppColors.primary : AppColors.surfaceMuted,
                            child: Icon(
                              user.role == UserRole.admin ? Icons.admin_panel_settings : Icons.person,
                              color: user.isActive ? AppColors.surface : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSizes.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontSize: AppSizes.fontLg,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (isSelf)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('You', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: user.role == UserRole.admin
                                            ? AppColors.primary.withValues(alpha: 0.1)
                                            : AppColors.border,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        user.role.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: user.role == UserRole.admin
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: user.isActive
                                            ? AppColors.success.withValues(alpha: 0.1)
                                            : AppColors.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        user.isActive ? 'ACTIVE' : 'INACTIVE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: user.isActive ? AppColors.success : AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: <Widget>[
                              OutlinedButton.icon(
                                onPressed: () => _showEditUserDialog(user),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showChangePinDialog(user),
                                icon: const Icon(Icons.password, size: 16),
                                label: const Text('Change PIN'),
                              ),
                              if (!isSuperAdmin) // For absolute safety, don't show toggle on ID 1
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    if (user.isActive) {
                                      final bool? confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Confirm Deactivation'),
                                            content: Text('Are you sure you want to deactivate ${user.name}? They will no longer be able to log in.'),
                                            actions: <Widget>[
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.surface),
                                                child: const Text('Deactivate'),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirm != true || !context.mounted) {
                                        return;
                                      }
                                    }

                                    ref.read(adminUsersNotifierProvider.notifier).updateUser(
                                      id: user.id,
                                      isActive: !user.isActive,
                                    ).catchError((e) {
                                      if (context.mounted) {
                                        _showError((e as ValidationException).message);
                                      }
                                    });
                                  },
                                  icon: Icon(user.isActive ? Icons.block : Icons.check_circle, size: 16),
                                  label: Text(user.isActive ? 'Deactivate' : 'Activate'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: user.isActive ? AppColors.error : AppColors.success,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
