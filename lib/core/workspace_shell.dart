import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'design_system.dart';
import 'supabase_client.dart';

class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({super.key, required this.title, required this.child, this.active = 'Classes', this.actions = const []});
  final String title;
  final Widget child;
  final String active;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final compact = box.maxWidth < 850;
    return Scaffold(
      drawer: compact ? Drawer(child: _Navigation(active: active)) : null,
      body: Row(children: [
        if (!compact) const _IconRail(),
        if (!compact) SizedBox(width: 225, child: _Navigation(active: active)),
        Expanded(child: Column(children: [
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(color: SmartGradeColors.white, border: Border(bottom: BorderSide(color: SmartGradeColors.line))),
            child: Row(children: [
              if (compact) Builder(builder: (context) => IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu_rounded))),
              if (compact) const SizedBox(width: 6),
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('SMARTGRADE  /  WORKSPACE', style: TextStyle(fontSize: 10, color: SmartGradeColors.muted, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                Text(title, style: const TextStyle(fontSize: 18, color: SmartGradeColors.ink, fontWeight: FontWeight.w700)),
              ]),
              const Spacer(),
              ...actions,
              const SizedBox(width: 12),
              const CircleAvatar(radius: 16, backgroundColor: SmartGradeColors.mustard, foregroundColor: SmartGradeColors.black, child: Icon(Icons.person_rounded, size: 18)),
              const SizedBox(width: 9),
              if (!compact) const Text('Teacher Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(child: child),
        ])),
      ]),
    );
  });
}

class _IconRail extends StatelessWidget {
  const _IconRail();
  @override
  Widget build(BuildContext context) => Container(
    width: 58,
    color: SmartGradeColors.black,
    child: SafeArea(child: Column(children: [
      const SizedBox(height: 16),
      const Icon(Icons.school_rounded, color: SmartGradeColors.mustard, size: 27),
      const SizedBox(height: 28),
      const _RailButton(icon: Icons.grid_view_rounded, route: '/classes', tooltip: 'Classes'),
      const _RailButton(icon: Icons.table_chart_outlined, route: '/gradebooks', tooltip: 'Gradebooks'),
      const _RailButton(icon: Icons.bar_chart_rounded, route: '/reports', tooltip: 'Reports'),
      const Spacer(),
      IconButton(tooltip: 'Settings', onPressed: () => context.go('/settings'), icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20)),
      const SizedBox(height: 14),
    ])),
  );
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.active});
  final String active;
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF2A252C),
    child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(22, 20, 18, 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SMARTGRADE', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        SizedBox(height: 3),
        Text('CLASS RECORD SYSTEM', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.4)),
      ])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('TEACHER WORKSPACE', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
      const SizedBox(height: 9),
      _NavItem(label: 'Classes', icon: Icons.dashboard_outlined, active: active == 'Classes', onTap: () => context.go('/classes')),
      _NavItem(label: 'Gradebooks', icon: Icons.table_chart_outlined, active: active == 'Gradebooks' || active == 'Gradebook', onTap: () => context.go('/gradebooks')),
      _NavItem(label: 'Reports', icon: Icons.description_outlined, active: active == 'Reports', onTap: () => context.go('/reports')),
      const Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 10), child: Text('QUICK FILTERS', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
      const _Filter(label: 'Active classes', color: SmartGradeColors.red),
      const _Filter(label: 'Missing scores', color: SmartGradeColors.mustard),
      const _Filter(label: 'At-risk students', color: Colors.white54),
      const Spacer(),
      Padding(padding: const EdgeInsets.all(16), child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24), minimumSize: const Size.fromHeight(42)),
        onPressed: () async { await supabase.auth.signOut(); if (context.mounted) context.go('/login'); },
        icon: const Icon(Icons.logout_rounded, size: 17), label: const Text('Sign out'),
      )),
    ])),
  );
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.route, required this.tooltip});
  final IconData icon;
  final String route;
  final String tooltip;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: IconButton(tooltip: tooltip, onPressed: () => context.go(route), icon: Icon(icon, color: Colors.white70, size: 20)),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.icon, required this.active, required this.onTap, this.badge});
  final String label; final IconData icon; final bool active; final VoidCallback onTap; final String? badge;
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(color: active ? SmartGradeColors.red : Colors.transparent, borderRadius: BorderRadius.circular(7)),
    child: ListTile(dense: true, minLeadingWidth: 20, leading: Icon(icon, size: 18, color: active ? Colors.white : Colors.white60), title: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500)), trailing: badge == null ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: SmartGradeColors.mustard, borderRadius: BorderRadius.circular(10)), child: Text(badge!, style: const TextStyle(fontSize: 9, color: SmartGradeColors.black, fontWeight: FontWeight.bold))), onTap: onTap),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.color}); final String label; final Color color;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 6), child: Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 10), Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11))]));
}
