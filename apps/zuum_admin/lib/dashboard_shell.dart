import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

import 'admin_api.dart';
import 'admin_auth.dart';
import 'admin_widgets.dart';
import 'pages.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.auth});

  final AdminAuth auth;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;
  int _refreshSignal = 0;
  DateTime _now = DateTime.now();
  Timer? _tick;
  Timer? _refresh;

  static const _items = [
    _NavItem('Command', Icons.grid_view_rounded, 'Live overview'),
    _NavItem('Live ops', Icons.radar_rounded, 'Bookings in motion'),
    _NavItem('Drivers', Icons.groups_2_outlined, 'KYC + fleet'),
    _NavItem('Money', Icons.account_balance_outlined, 'Revenue + payouts'),
    _NavItem('Support', Icons.support_agent_rounded, 'Rider help'),
  ];

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _refreshSignal++);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1120;
        final content = Column(
          children: [
            _TopBar(
              item: _items[_index],
              now: _now,
              showMenu: !desktop,
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onRefresh: () => setState(() => _refreshSignal++),
              user: widget.auth.user,
              onLogout: widget.auth.logout,
            ),
            Expanded(
              child: SelectionArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: _page(),
                  ),
                ),
              ),
            ),
          ],
        );

        if (desktop) {
          return Scaffold(
            backgroundColor: ZColors.dark,
            body: Row(
              children: [
                _Sidebar(
                  items: _items,
                  index: _index,
                  onSelect: (i) => setState(() => _index = i),
                  user: widget.auth.user,
                  onLogout: widget.auth.logout,
                ),
                const VerticalDivider(width: 1, color: ZColors.darkOutline),
                Expanded(child: content),
              ],
            ),
          );
        }
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: ZColors.dark,
          drawer: Drawer(
            width: 272,
            backgroundColor: ZColors.dark,
            child: _Sidebar(
              items: _items,
              index: _index,
              onSelect: (i) {
                setState(() => _index = i);
                _scaffoldKey.currentState?.closeDrawer();
              },
              user: widget.auth.user,
              onLogout: widget.auth.logout,
            ),
          ),
          body: content,
        );
      },
    );
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _page() {
    return switch (_index) {
      0 => OverviewPage(refreshSignal: _refreshSignal),
      1 => LiveOpsPage(refreshSignal: _refreshSignal),
      2 => DriversPage(refreshSignal: _refreshSignal),
      3 => MoneyPage(refreshSignal: _refreshSignal),
      _ => SupportPage(refreshSignal: _refreshSignal),
    };
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.caption);
  final String label;
  final IconData icon;
  final String caption;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.index,
    required this.onSelect,
    required this.user,
    required this.onLogout,
  });

  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final AdminUser? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: ZColors.dark,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: ZBrandMark(onDark: true, scale: 0.82),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: AdminEyebrow('Operations console'),
          ),
          const SizedBox(height: 26),
          for (var i = 0; i < items.length; i++) ...[
            _NavButton(
              item: items[i],
              selected: i == index,
              onTap: () => onSelect(i),
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(ZSpacing.md),
            decoration: BoxDecoration(
              color: ZColors.darkRaised.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(ZRadii.md),
              border: Border.all(color: ZColors.darkOutline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _LiveDot(),
                    SizedBox(width: 7),
                    Text(
                      'LIVE API',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: ZColors.onDarkSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Bengaluru · onrender',
                  style: ZTypography.caption.copyWith(
                    color: ZColors.onDarkSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.md),
          Row(
            children: [
              AdminAvatar(label: user?.fullName ?? 'Ops', size: 32),
              const SizedBox(width: ZSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Ops desk',
                      style: ZTypography.captionStrong.copyWith(
                        color: ZColors.onDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user?.email ?? '',
                      style: ZTypography.overline.copyWith(
                        color: ZColors.onDarkSecondary,
                        fontSize: 9,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: onLogout,
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 16,
                  color: ZColors.onDarkSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ZColors.onDark : Colors.transparent,
      borderRadius: BorderRadius.circular(ZRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZRadii.md),
        hoverColor: selected
            ? Colors.transparent
            : ZColors.onDark.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: selected ? ZColors.dark : ZColors.onDarkSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: ZTypography.bodyStrong.copyWith(
                    color: selected ? ZColors.dark : ZColors.onDark,
                    fontSize: 13,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: ZColors.dark,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.item,
    required this.now,
    required this.showMenu,
    required this.onMenu,
    required this.onRefresh,
    required this.user,
    required this.onLogout,
  });

  final _NavItem item;
  final DateTime now;
  final bool showMenu;
  final VoidCallback onMenu;
  final VoidCallback onRefresh;
  final AdminUser? user;
  final VoidCallback onLogout;

  String get _stamp {
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: ZSpacing.xxl),
      decoration: const BoxDecoration(
        color: ZColors.dark,
        border: Border(bottom: BorderSide(color: ZColors.darkOutline)),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded, color: ZColors.onDark),
            ),
            const SizedBox(width: 4),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                style: ZTypography.titleMd.copyWith(color: ZColors.onDark),
              ),
              Text(
                item.caption,
                style: ZTypography.overline.copyWith(
                  color: ZColors.onDarkSecondary,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const Spacer(),
          const _LivePill(),
          const SizedBox(width: ZSpacing.md),
          Text(
            '$_stamp IST',
            style: ZTypography.numeric.copyWith(
              color: ZColors.onDarkSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: ZSpacing.md),
          IconButton(
            tooltip: 'Refresh now',
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: ZColors.onDarkSecondary,
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Account',
            color: ZColors.darkRaised,
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Text('Sign out', style: TextStyle(fontSize: 13)),
              ),
            ],
            child: Row(
              children: [
                AdminAvatar(label: user?.fullName ?? 'Ops', size: 32),
                const SizedBox(width: 8),
                if (MediaQuery.sizeOf(context).width > 700)
                  Text(
                    user?.firstName ?? 'Ops',
                    style: ZTypography.captionStrong.copyWith(
                      color: ZColors.onDark,
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

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ZColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZColors.success.withValues(alpha: 0.25)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LiveDot(),
          SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: ZColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: ZColors.success,
        shape: BoxShape.circle,
      ),
    );
  }
}
