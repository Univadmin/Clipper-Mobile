import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'models/lighter_series.dart';
import 'services/ocr.dart';
export 'services/ocr.dart' show ScanResult;
import 'widgets/scan_review_sheet.dart';
import 'screens/camera_scanner_page.dart';
import 'auth/auth_service.dart';
import 'auth/auth_gate.dart';
import 'controllers/collection_controller.dart';
export 'controllers/collection_controller.dart';
import 'repositories/collection_repository.dart';
import 'repositories/firebase_collection_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _UnlockApp());
}

class _UnlockApp extends StatefulWidget {
  const _UnlockApp();
  @override
  State<_UnlockApp> createState() => _UnlockAppState();
}

class _UnlockAppState extends State<_UnlockApp> {
  late final AuthService _auth = LocalAuthService();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent),
    ),
    home: AuthGate(
      auth: _auth,
      signedInBuilder: (context, signOut) => _BootstrapApp(onSignOut: signOut),
    ),
  );
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp({required this.onSignOut});
  final VoidCallback onSignOut;
  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return LighterCollectionApp(onSignOut: widget.onSignOut);
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Koleksiyon bağlantısı başlatılamadı. Bağlantıyı ve uygulama ayarlarını kontrol edin.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() {
                            _initialization = _initialize();
                          }),
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

class LighterCollectionApp extends StatefulWidget {
  const LighterCollectionApp({this.repository, this.onSignOut, super.key});
  final VoidCallback? onSignOut;

  final CollectionRepository? repository;

  @override
  State<LighterCollectionApp> createState() => _LighterCollectionAppState();
}

class _LighterCollectionAppState extends State<LighterCollectionApp> {
  late final LighterCollectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LighterCollectionController(
      repo: widget.repository ?? FirebaseCollectionRepository(),
    );
    _controller.addListener(_onControllerChanged);
  }

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _selectedIndex = 0;

  int _lastErrorVersion = 0;

  void _onControllerChanged() {
    if (_controller.errorVersion != _lastErrorVersion) {
      _lastErrorVersion = _controller.errorVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.operationError != null) {
          _showSnack(_controller.operationError!);
        }
      });
    }
  }

  BuildContext get _modalContext =>
      _navigatorKey.currentContext ?? _messengerKey.currentContext ?? context;

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepOrangeAccent,
      brightness: Brightness.light,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'iClip',
          scaffoldMessengerKey: _messengerKey,
          navigatorKey: _navigatorKey,
          theme: ThemeData(
            colorScheme: colorScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF7F4F1),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: const CardThemeData(
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          home: Scaffold(
            appBar: AppBar(
              title: Text(
                _selectedIndex == 0 ? 'Koleksiyon' : 'Ekle / Düzenle',
              ),
              actions: [
                IconButton(
                  tooltip: 'Uygulama bilgisi',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => showAboutDialog(
                    context: _modalContext,
                    applicationName: 'iClip',
                    applicationVersion: const String.fromEnvironment(
                      'APP_VERSION',
                      defaultValue: 'Geliştirme',
                    ),
                    children: const [
                      Text(
                        'Dört parçalı Clipper serilerinizi ve eksik parçalarınızı takip edin.',
                      ),
                    ],
                  ),
                ),
                if (widget.onSignOut != null)
                  IconButton(
                    tooltip: 'Çıkış yap',
                    icon: const Icon(Icons.logout),
                    onPressed: _controller.isSaving ? null : widget.onSignOut,
                  ),
                IconButton(
                  tooltip: 'Kamerayla tara',
                  icon: const Icon(Icons.camera_alt_outlined),
                  onPressed: _handleCameraScan,
                ),
                _CollectionStats(
                  total: _controller.totalSeries,
                  completed: _controller.completedSeries,
                  inProgress: _controller.inProgressSeries,
                ),
              ],
            ),
            body: Column(
              children: [
                if (_controller.isSaving) const LinearProgressIndicator(),
                if (_controller.dataWarning != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _controller.dataWarning!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_controller.loadError != null)
                  MaterialBanner(
                    content: Text(_controller.loadError!),
                    actions: [
                      TextButton(
                        onPressed: _controller.retry,
                        child: const Text('Yeniden dene'),
                      ),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      CollectionListView(
                        controller: _controller,
                        onFilterTap: _showFilterSheet,
                      ),
                      ManageSeriesView(controller: _controller),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.table_rows_outlined),
                  label: 'Koleksiyon',
                ),
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  label: 'Ekle / Düzenle',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCameraScan() async {
    try {
      final rawText = await Navigator.of(_modalContext).push<String>(
        MaterialPageRoute(
          builder: (_) => const CameraScannerPage(),
          fullscreenDialog: true,
        ),
      );

      if (!mounted || rawText == null) return;
      if (rawText.trim().isEmpty) {
        _showSnack('Metin algılanamadı, tekrar dene.');
        return;
      }

      final parsed = ScanResult.tryParse(rawText);
      final query = parsed?.seriesName ?? rawText;
      final ranked = _controller.rankedMatches(query);
      final existing =
          ranked.isNotEmpty &&
              ranked.first.score >= 0.92 &&
              (ranked.length == 1 ||
                  ranked.first.score - ranked[1].score >= 0.12)
          ? ranked.first.series
          : null;

      if (existing != null) {
        _showSeriesStatusSheet(existing, parsed?.slot);
        return;
      }

      final suggestions = ranked
          .where((match) => match.score >= 0.35)
          .take(5)
          .toList();

      if (suggestions.isNotEmpty) {
        final selected = await showModalBottomSheet<LighterSeries>(
          context: _modalContext,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) =>
              _MatchSuggestionSheet(query: query, matches: suggestions),
        );
        if (!mounted) return;
        if (selected != null) {
          _showSeriesStatusSheet(selected, parsed?.slot);
          return;
        }
      }

      if (parsed != null) {
        _showCreateFromScanSheet(parsed);
        return;
      }

      _showUnmatchedScanSheet(rawText);
    } catch (error) {
      if (mounted) {
        _showSnack('Kamera kullanılırken hata oluştu: $error');
      }
    }
  }

  void _showSeriesStatusSheet(LighterSeries series, int? slot) {
    final modalContext = _modalContext;
    showModalBottomSheet<void>(
      context: modalContext,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final current = _controller.getById(series.id) ?? series;
            final hasSlotInfo = slot != null;
            final slotOwned = slot != null
                ? current.hasPiece(slot)
                : current.isComplete;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PieceStatusRow(serie: current, highlightSlot: slot),
                  const SizedBox(height: 16),
                  Text(
                    current.isComplete
                        ? 'Bu seri tamamen sende.'
                        : hasSlotInfo
                        ? slotOwned
                              ? '$slot/4 zaten koleksiyonunda.'
                              : '$slot/4 henüz eklenmemiş.'
                        : 'Eksik parçaları aşağıdan işaretleyebilirsin.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: List.generate(4, (index) {
                      final pos = index + 1;
                      final owned = current.hasPiece(pos);
                      return FilterChip(
                        label: Text('$pos/4'),
                        selected: owned,
                        onSelected: _controller.isBusy(current.id)
                            ? null
                            : (value) async => await _controller.setPiece(
                                current.id,
                                pos,
                                value,
                              ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (slot != null && !slotOwned)
                    FilledButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text('$slot/4 çakmağını ekle'),
                      onPressed: () async {
                        final saved = await _controller.setPiece(
                          current.id,
                          slot,
                          true,
                        );
                        if (saved && context.mounted) {
                          Navigator.of(context).pop();
                          _showSnack(
                            '${current.name} $slot/4 koleksiyona eklendi.',
                          );
                        }
                      },
                    )
                  else
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Tamam'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateFromScanSheet(ScanResult result) {
    showModalBottomSheet<bool>(
      context: _modalContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ScanReviewSheet(
        result: result,
        onSave: (name, slot) async {
          final saved = await _controller.upsertSeries(
            name: name,
            ownedPieces: {slot},
          );
          if (saved) _showSnack('$name koleksiyona eklendi.');
          return saved;
        },
      ),
    );
  }

  void _showUnmatchedScanSheet(String rawText) {
    final modalContext = _modalContext;
    showModalBottomSheet<void>(
      context: modalContext,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seri bulunamadı',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                rawText.isEmpty ? 'Metin algılanamadı.' : '"$rawText"',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Ekle / Düzenle sekmesini aç'),
                onPressed: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Yeni seriyi eklerken kameradan okuttuğun adı yukarıya yazabilirsin.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterSheet(SeriesFilter filter) {
    final items = _controller.seriesByFilter(filter);
    final modalContext = _modalContext;
    showModalBottomSheet<void>(
      context: modalContext,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final title = filter == SeriesFilter.completed
            ? 'Tamamlanan Setler'
            : 'Devam Eden Setler';
        return _FilterResultSheet(title: title, series: items);
      },
    );
  }

  void _showSnack(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class CollectionListView extends StatefulWidget {
  const CollectionListView({
    required this.controller,
    required this.onFilterTap,
    super.key,
  });

  final LighterCollectionController controller;
  final ValueChanged<SeriesFilter> onFilterTap;

  @override
  State<CollectionListView> createState() => _CollectionListViewState();
}

class _CollectionListViewState extends State<CollectionListView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final q = _query.trim().toLowerCase();
        final filtered = widget.controller.series.where((serie) {
          return serie.name.toLowerCase().contains(q) ||
              serie.seriesNumber.toString().contains(q);
        }).toList();

        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: CustomScrollView(
            key: const PageStorageKey('collection-series'),
            slivers: [
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              SliverToBoxAdapter(
                child: _CollectionHighlights(
                  total: widget.controller.totalSeries,
                  completed: widget.controller.completedSeries,
                  inProgress: widget.controller.inProgressSeries,
                  onFilterTap: widget.onFilterTap,
                ),
              ),
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(
                    query: _query,
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _CollectionSeriesCard(
                    key: ValueKey(filtered[index].id),
                    series: filtered[index],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return SearchBar(
      controller: _searchController,
      hintText: 'Seri veya model ara...',
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      onChanged: (value) => setState(() => _query = value),
      leading: const Icon(Icons.search),
      trailing: [
        if (_query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
      ],
    );
  }
}

class ManageSeriesView extends StatefulWidget {
  const ManageSeriesView({required this.controller, super.key});

  final LighterCollectionController controller;

  @override
  State<ManageSeriesView> createState() => _ManageSeriesViewState();
}

class _ManageSeriesViewState extends State<ManageSeriesView> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final Set<int> _ownedPieces = {};

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final series = widget.controller.series;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom + 20;
        return SafeArea(
          child: CustomScrollView(
            key: const PageStorageKey('manage-series'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormCard(context),
                      const SizedBox(height: 28),
                      Text(
                        'Mevcut Setler',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
                sliver: series.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Henüz kayıtlı bir seri yok. Yeni eklediğiniz seriler burada görünecek.',
                            ),
                          ),
                        ),
                      )
                    : SliverList.builder(
                        itemCount: series.length,
                        itemBuilder: (context, index) {
                          final serie = series[index];
                          return _ManageSeriesCard(
                            key: ValueKey(serie.id),
                            series: serie,
                            controller: widget.controller,
                            onEdit: () => _openEditDialog(serie),
                            onDelete: () => _confirmDelete(serie),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni Seri Ekle (Clipper)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Seri numarası otomatik atanır. Sıradaki numara: ${widget.controller.nextSeriesNumber}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Seri / Model Adı',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen bir seri adı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _PieceSelector(
                ownedPieces: _ownedPieces,
                onToggle: (slot) {
                  setState(() {
                    if (_ownedPieces.contains(slot)) {
                      _ownedPieces.remove(slot);
                    } else {
                      _ownedPieces.add(slot);
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Seriyi Kaydet'),
                  onPressed:
                      widget.controller.isSaving ||
                          widget.controller.isLoading ||
                          widget.controller.loadError != null
                      ? null
                      : _handleSubmit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final saved = await widget.controller.upsertSeries(
      name: _modelController.text.trim(),
      ownedPieces: _ownedPieces,
    );

    if (saved && mounted) {
      setState(() {
        _modelController.clear();
        _ownedPieces.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seri başarıyla eklendi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditDialog(LighterSeries series) async {
    var editedName = series.name;
    final ownedPieces = {...series.ownedPieces};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Seriyi Düzenle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: series.name,
                      onChanged: (value) => editedName = value,
                      decoration: const InputDecoration(
                        labelText: 'Seri / Model Adı',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PieceSelector(
                      ownedPieces: ownedPieces,
                      onToggle: (slot) {
                        setStateDialog(() {
                          if (ownedPieces.contains(slot)) {
                            ownedPieces.remove(slot);
                          } else {
                            ownedPieces.add(slot);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final updatedName = editedName.trim();
                    if (updatedName.isEmpty) return;
                    final saved = await widget.controller.upsertSeries(
                      id: series.id,
                      name: updatedName,
                      ownedPieces: ownedPieces,
                    );
                    if (saved && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(LighterSeries series) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seriyi Sil'),
          content: Text(
            '"${series.name}" serisini tamamen silmek üzeresiniz. Bu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final deleted = await widget.controller.removeSeries(series.id);
                if (deleted && context.mounted) {
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${series.name} silindi'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }
}

class _CollectionSeriesCard extends StatelessWidget {
  const _CollectionSeriesCard({required this.series, super.key});
  final LighterSeries series;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SeriesNumberBadge(number: series.seriesNumber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _PieceStatusRow(serie: series),
                  const SizedBox(height: 8),
                  Text(
                    series.isComplete
                        ? 'Tamamlandı'
                        : 'Eksik parçalar: ${series.missingPieces.join(', ')}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceStatusRow extends StatelessWidget {
  const _PieceStatusRow({required this.serie, this.highlightSlot});

  final LighterSeries serie;
  final int? highlightSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(4, (index) {
        final slot = index + 1;
        final owned = serie.hasPiece(slot);
        final isHighlighted = highlightSlot == slot;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: owned
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isHighlighted
                  ? colorScheme.secondary
                  : owned
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            '$slot/4',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: owned ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }),
    );
  }
}

class _PieceSelector extends StatelessWidget {
  const _PieceSelector({required this.ownedPieces, required this.onToggle});

  final Set<int> ownedPieces;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bende olan çakmaklar'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: List.generate(4, (index) {
            final slot = index + 1;
            final selected = ownedPieces.contains(slot);
            return FilterChip(
              label: Text('$slot/4'),
              selected: selected,
              onSelected: (_) => onToggle(slot),
            );
          }),
        ),
      ],
    );
  }
}

class _ManageSeriesCard extends StatelessWidget {
  const _ManageSeriesCard({
    required this.series,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final LighterSeries series;
  final LighterCollectionController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final missing = series.missingPieces;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SeriesNumberBadge(number: series.seriesNumber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        series.isComplete
                            ? 'Tüm çakmaklar tamamlandı'
                            : 'Eksik: ${missing.join(', ')}',
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: controller.isBusy(series.id) ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Seriyi düzenle',
                    ),
                    IconButton(
                      onPressed: controller.isBusy(series.id) ? null : onDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.redAccent,
                      tooltip: 'Seriyi sil',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PieceStatusRow(serie: series),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: List.generate(4, (index) {
                final slot = index + 1;
                final owned = series.hasPiece(slot);
                return FilterChip(
                  label: Text('$slot/4'),
                  selected: owned,
                  onSelected: controller.isBusy(series.id)
                      ? null
                      : (value) async =>
                            await controller.setPiece(series.id, slot, value),
                );
              }),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: series.completionRatio,
              minHeight: 6,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 6),
            Text('Toplanan: ${series.ownedCount} / 4'),
          ],
        ),
      ),
    );
  }
}

class _CollectionStats extends StatelessWidget {
  const _CollectionStats({
    required this.total,
    required this.completed,
    required this.inProgress,
  });

  final int total;
  final int completed;
  final int inProgress;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2) {
      return const SizedBox.shrink();
    }
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Toplam: $total', style: style),
          Text('Tamamlanan: $completed | Devam: $inProgress', style: style),
        ],
      ),
    );
  }
}

class _CollectionHighlights extends StatelessWidget {
  const _CollectionHighlights({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.onFilterTap,
  });

  final int total;
  final int completed;
  final int inProgress;
  final ValueChanged<SeriesFilter> onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _HighlightChip(
            icon: Icons.collections_bookmark_outlined,
            label: 'Toplam Seri',
            value: '$total',
            color: Theme.of(context).colorScheme.primary,
          ),
          _HighlightChip(
            icon: Icons.verified_outlined,
            label: 'Tamamlanan',
            value: '$completed',
            color: Colors.green.shade600,
            onTap: () => onFilterTap(SeriesFilter.completed),
          ),
          _HighlightChip(
            icon: Icons.incomplete_circle_outlined,
            label: 'Devam Eden',
            value: '$inProgress',
            color: Colors.orange.shade700,
            onTap: () => onFilterTap(SeriesFilter.inProgress),
          ),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chipBody = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return chipBody;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: chipBody,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'Sonuç bulunamadı',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '"$query" ile eşleşen bir seri bulunamadı.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onClear, child: const Text('Aramayı temizle')),
        ],
      ),
    );
  }
}

class _SeriesNumberBadge extends StatelessWidget {
  const _SeriesNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        '$number',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class _FilterResultSheet extends StatelessWidget {
  const _FilterResultSheet({required this.title, required this.series});

  final String title;
  final List<LighterSeries> series;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (series.isEmpty)
            const Text('Henüz liste boş.')
          else
            SizedBox(
              height: min(series.length * 72.0, maxHeight),
              child: ListView.separated(
                itemCount: series.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (context, index) {
                  final serie = series[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: _SeriesNumberBadge(number: serie.seriesNumber),
                    title: Text(serie.name),
                    subtitle: Text(
                      serie.isComplete
                          ? 'Tamamlandı'
                          : 'Eksik: ${serie.missingPieces.join(', ')}',
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: List.generate(
                        4,
                        (slotIndex) => Icon(
                          serie.hasPiece(slotIndex + 1)
                              ? Icons.local_fire_department
                              : Icons.circle_outlined,
                          size: 18,
                          color: serie.hasPiece(slotIndex + 1)
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
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

class _MatchSuggestionSheet extends StatelessWidget {
  const _MatchSuggestionSheet({required this.query, required this.matches});

  final String query;
  final List<SeriesMatch> matches;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '"$query"',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Benzer seriler bulundu, birini seçersen o seri üzerinde devam edebilirsin.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ...matches.map(
            (match) => ListTile(
              leading: _SeriesNumberBadge(number: match.series.seriesNumber),
              title: Text(match.series.name),
              subtitle: Text(
                match.series.isComplete
                    ? 'Tüm çakmaklar sende'
                    : 'Eksik: ${match.series.missingPieces.join(', ')}',
              ),
              onTap: () => Navigator.of(context).pop(match.series),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Yeni seri olarak ekle'),
          ),
        ],
      ),
    );
  }
}
