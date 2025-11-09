import 'package:flutter/material.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/features/auth/presentation/SignInWidget.dart';
import 'package:mobiletest/features/employee/domain/employee_models.dart';

class EmployeeSidebar extends StatelessWidget {
  final String selectedTab; // 'orders' | 'history'
  final ValueChanged<String> onSelectTab;
  final EmployeeDetail? employee;
  final bool employeeLoading;
  final String? employeeError;

  const EmployeeSidebar({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
    required this.employee,
    required this.employeeLoading,
    required this.employeeError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/Logo.png', width: 72, height: 72, fit: BoxFit.contain),
                const SizedBox(height: 10),
                const Text('Chicken Kitchen',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C))),
              ],
            ),
          ),
          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Menu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                const SizedBox(height: 8),
                _SidebarTab(
                  icon: Icons.list_alt,
                  label: 'Orders',
                  selected: selectedTab == 'orders',
                  onTap: () => onSelectTab('orders'),
                ),
                const SizedBox(height: 8),
                _SidebarTab(
                  icon: Icons.history,
                  label: 'History',
                  selected: selectedTab == 'history',
                  onTap: () => onSelectTab('history'),
                ),
              ],
            ),
          ),
          // Store info scrollable (center)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin cửa hàng',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(height: 8),
                  if (employeeLoading)
                    const Text('Đang tải...', style: TextStyle(fontSize: 12, color: Colors.black45))
                  else if (employeeError != null)
                    Text('Lỗi: $employeeError', style: const TextStyle(fontSize: 12, color: Colors.red))
                  else if (employee != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.store_mall_directory, size: 16, color: Colors.black45),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(employee!.storeName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.black45),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(employee!.storeAddress,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ),
                          ],
                        ),
                        if (employee!.storePhone != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 16, color: Colors.black45),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(employee!.storePhone!,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
          // Bottom fixed employee panel + logout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (employee != null) ...[
                  Row(
                    children: [
                      const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(employee!.userFullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(employee!.position,
                                style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Đăng xuất'),
                          content: const Text('Bạn có chắc muốn đăng xuất?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                final auth = AuthService();
                                await auth.logout();
                                if (!context.mounted) return;
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const SignInWidget()),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB71C1C),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Log out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB71C1C),
                      side: const BorderSide(color: Color(0xFFB71C1C)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
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

class _SidebarTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFB71C1C).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: const Color(0xFFB71C1C).withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFFB71C1C) : Colors.black54, size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? const Color(0xFFB71C1C) : Colors.black54,
                )),
          ],
        ),
      ),
    );
  }
}
