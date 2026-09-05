import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/announcement.dart';
import '../../models/app_user.dart';
import '../../models/village_request.dart';
import '../../services/muhtarim_service.dart';
import 'work_posts_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = MuhtarimService();
  late Future<AppUser> _userFuture = _service.currentUser();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Profil yüklenemedi\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () =>
                          setState(() => _userFuture = _service.currentUser()),
                      child: const Text('Tekrar dene'),
                    ),
                    TextButton(
                      onPressed: _service.signOut,
                      child: const Text('Çıkış yap'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _Dashboard(user: snapshot.requireData, service: _service);
      },
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.user, required this.service});
  final AppUser user;
  final MuhtarimService service;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AnnouncementsPage(user: widget.user, service: widget.service),
      WorkPostsPage(user: widget.user, service: widget.service),
      _RequestsPage(user: widget.user, service: widget.service),
      if (widget.user.isMukhtar)
        _MembersPage(user: widget.user, service: widget.service),
      _ProfilePage(user: widget.user, service: widget.service),
    ];
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.campaign_outlined),
        selectedIcon: Icon(Icons.campaign),
        label: 'Duyurular',
      ),
      const NavigationDestination(
        icon: Icon(Icons.construction_outlined),
        selectedIcon: Icon(Icons.construction),
        label: 'Çalışmalar',
      ),
      const NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: 'Talepler',
      ),
      if (widget.user.isMukhtar)
        const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Köylüler',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profil',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.user.villageName),
            Text(
              [
                if (widget.user.villageLocation.isNotEmpty)
                  widget.user.villageLocation,
                widget.user.isMukhtar ? 'Muhtar paneli' : 'Köy meydanı',
              ].join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}

class _AnnouncementsPage extends StatefulWidget {
  const _AnnouncementsPage({required this.user, required this.service});
  final AppUser user;
  final MuhtarimService service;

  @override
  State<_AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<_AnnouncementsPage> {
  late Future<List<Announcement>> _future = widget.service.announcements();

  void _refresh() => setState(() => _future = widget.service.announcements());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<Announcement>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _SectionHeader(
                title: 'Köyden haberler',
                subtitle: 'Düğün, hayır, çalışma ve önemli bilgilendirmeler',
                action: widget.user.isMukhtar
                    ? FilledButton.icon(
                        onPressed: () => _newAnnouncement(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Duyuru'),
                      )
                    : null,
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _ErrorCard(message: '${snapshot.error}', onRetry: _refresh)
              else if (items.isEmpty)
                const _EmptyCard(
                  icon: Icons.campaign_outlined,
                  text: 'Henüz duyuru yok.',
                )
              else
                ...items.map((item) => _AnnouncementCard(item: item)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _newAnnouncement(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AnnouncementForm(service: widget.service),
    );
    if (created == true) _refresh();
  }
}

class _RequestsPage extends StatefulWidget {
  const _RequestsPage({required this.user, required this.service});
  final AppUser user;
  final MuhtarimService service;

  @override
  State<_RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<_RequestsPage> {
  late Future<List<VillageRequest>> _future = widget.service.requests();
  void _refresh() => setState(() => _future = widget.service.requests());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<VillageRequest>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _SectionHeader(
                title: widget.user.isMukhtar
                    ? 'Köyden gelen talepler'
                    : 'Taleplerim',
                subtitle: widget.user.isMukhtar
                    ? 'Gelen bildirimleri inceleyip durumunu güncelleyin'
                    : 'Sorunu muhtarlığa iletin ve sonucunu takip edin',
                action: widget.user.isMukhtar
                    ? null
                    : FilledButton.icon(
                        onPressed: () => _newRequest(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Talep'),
                      ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _ErrorCard(message: '${snapshot.error}', onRetry: _refresh)
              else if (items.isEmpty)
                const _EmptyCard(
                  icon: Icons.assignment_outlined,
                  text: 'Henüz talep yok.',
                )
              else
                ...items.map(
                  (item) => _RequestCard(
                    item: item,
                    isMukhtar: widget.user.isMukhtar,
                    onStatusChanged: (status) async {
                      await widget.service.updateRequestStatus(item.id, status);
                      _refresh();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _newRequest(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestForm(service: widget.service),
    );
    if (created == true) _refresh();
  }
}

class _MembersPage extends StatefulWidget {
  const _MembersPage({required this.user, required this.service});
  final AppUser user;
  final MuhtarimService service;

  @override
  State<_MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<_MembersPage> {
  late Future<List<Map<String, dynamic>>> _future = widget.service.members();

  void _refresh() => setState(() => _future = widget.service.members());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Köy halkı',
            subtitle: 'Katılım kodu: ${widget.user.joinCode}',
          ),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError)
            _ErrorCard(message: '${snapshot.error}', onRetry: _refresh)
          else
            ...(snapshot.data ?? []).map(
              (member) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (member['full_name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                    ),
                  ),
                  title: Text(member['full_name'] as String? ?? 'İsimsiz'),
                  subtitle: Text(
                    member['role'] == 'mukhtar' ? 'Muhtar' : 'Köy sakini',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.user, required this.service});
  final AppUser user;
  final MuhtarimService service;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  child: Text(
                    user.fullName.substring(0, 1).toUpperCase(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(user.isMukhtar ? 'Muhtar' : 'Köy sakini'),
                const SizedBox(height: 4),
                Text(user.villageName),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: service.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Çıkış yap'),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});
  final Announcement item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(item.type)),
                const Spacer(),
                Text(
                  DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(item.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(item.body),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.isMukhtar,
    required this.onStatusChanged,
  });
  final VillageRequest item;
  final bool isMukhtar;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      'open': 'Yeni',
      'in_progress': 'İşlemde',
      'resolved': 'Çözüldü',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(item.category)),
                const Spacer(),
                Text(labels[item.status] ?? item.status),
              ],
            ),
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.description),
            ],
            const SizedBox(height: 10),
            Text(
              '${item.ownerName} • ${DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (isMukhtar) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: item.status,
                decoration: const InputDecoration(labelText: 'Durum'),
                items: labels.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null && value != item.status) {
                    onStatusChanged(value);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnnouncementForm extends StatefulWidget {
  const _AnnouncementForm({required this.service});
  final MuhtarimService service;
  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _type = 'Genel';
  bool _busy = false;

  @override
  Widget build(BuildContext context) => _FormShell(
    title: 'Yeni duyuru',
    children: [
      TextField(
        controller: _title,
        decoration: const InputDecoration(labelText: 'Başlık'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _type,
        decoration: const InputDecoration(labelText: 'Duyuru türü'),
        items: [
          'Genel',
          'Düğün',
          'Hayır',
          'Çalışma',
          'Acil',
        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (value) => _type = value ?? _type,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _body,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Duyuru metni'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Gönderiliyor...' : 'Duyuruyu yayınla'),
      ),
    ],
  );

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.service.createAnnouncement(
        title: _title.text.trim(),
        body: _body.text.trim(),
        type: _type,
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RequestForm extends StatefulWidget {
  const _RequestForm({required this.service});
  final MuhtarimService service;
  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _category = 'Su';
  bool _busy = false;

  @override
  Widget build(BuildContext context) => _FormShell(
    title: 'Yeni talep',
    children: [
      DropdownButtonFormField<String>(
        initialValue: _category,
        decoration: const InputDecoration(labelText: 'Kategori'),
        items: [
          'Su',
          'Yol',
          'Elektrik',
          'Temizlik',
          'Diğer',
        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (value) => _category = value ?? _category,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _title,
        decoration: const InputDecoration(labelText: 'Kısa başlık'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _description,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Sorunu açıklayın'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Gönderiliyor...' : 'Talebi gönder'),
      ),
    ],
  );

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.service.createRequest(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _FormShell extends StatelessWidget {
  const _FormShell({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Veriler alınamadı: $message'),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    ),
  );
}
