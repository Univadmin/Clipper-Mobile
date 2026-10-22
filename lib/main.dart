import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'models/lighter_series.dart';
import 'repositories/collection_repository.dart';
import 'repositories/firebase_collection_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LighterCollectionApp());
}

enum SeriesFilter { completed, inProgress }

class ScanResult {
  const ScanResult({required this.seriesName, required this.slot});

  final String seriesName;
  final int slot;

  static ScanResult? tryParse(String text) {
    final normalized = text.replaceAll('\n', ' ');
    final regex =
        RegExp(r'([A-Za-zÇçĞğİıÖöŞşÜü0-9&\-\s]+?)\s+(\d)\s*/\s*4');
    final match = regex.firstMatch(normalized);
    if (match == null) return null;
    final slot = int.tryParse(match.group(2)!);
    if (slot == null || slot < 1 || slot > 4) return null;
    // Seri adından sonundaki "-" ve boşlukları temizle
    var name = match.group(1)!.trim();
    // Sonundaki "-" karakterini ve önündeki boşlukları temizle
    name = name.replaceAll(RegExp(r'\s*-\s*$'), '').trim();
    if (name.isEmpty) return null;
    return ScanResult(seriesName: name, slot: slot);
  }
}

class LighterCollectionApp extends StatefulWidget {
  const LighterCollectionApp({super.key});

  @override
  State<LighterCollectionApp> createState() => _LighterCollectionAppState();
}

class _LighterCollectionAppState extends State<LighterCollectionApp> {
  late final LighterCollectionController _controller;
  
  @override
  void initState() {
    super.initState();
    final repository = FirebaseCollectionRepository();
    _controller = LighterCollectionController(repo: repository);
  }
  final TextRecognizer _textRecognizer = TextRecognizer();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _selectedIndex = 0;

  BuildContext get _modalContext =>
      _navigatorKey.currentContext ??
      _messengerKey.currentContext ??
      context;

  @override
  void dispose() {
    _textRecognizer.close();
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
              title:
                  Text(_selectedIndex == 0 ? 'Koleksiyon' : 'Ekle / Düzenle'),
              actions: [
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
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedIndex == 0
                  ? CollectionListView(
                      controller: _controller,
                      onFilterTap: _showFilterSheet,
                    )
                  : ManageSeriesView(controller: _controller),
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
          builder: (_) => _CameraScannerPage(
            textRecognizer: _textRecognizer,
          ),
          fullscreenDialog: true,
        ),
      );

      if (!mounted || rawText == null || rawText.trim().isEmpty) {
        _showSnack('Metin algılanamadı, tekrar dene.');
        return;
      }

      final parsed = ScanResult.tryParse(rawText);
      final query = parsed?.seriesName ?? rawText;
      final existing = _controller.findBestMatch(query);

      if (existing != null) {
        _showSeriesStatusSheet(existing, parsed?.slot);
        return;
      }

      final suggestions = _controller
          .rankedMatches(query)
          .where((match) => match.score >= 0.08)
          .take(5)
          .toList();

      if (suggestions.isNotEmpty) {
        final selected = await showModalBottomSheet<LighterSeries>(
          context: _modalContext,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => _MatchSuggestionSheet(
            query: query,
            matches: suggestions,
          ),
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
            final slotOwned =
                slot != null ? current.hasPiece(slot) : current.isComplete;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
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
                        onSelected: (value) async =>
                            await _controller.setPiece(current.id, pos, value),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (slot != null && !slotOwned)
                    FilledButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text('$slot/4 çakmağını ekle'),
                      onPressed: () async {
                        await _controller.setPiece(current.id, slot, true);
                        if (context.mounted) {
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
                'Yeni seri bulundu',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('${result.seriesName} ${result.slot}/4'),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Seriyi ekle'),
                onPressed: () {
                  _controller.upsertSeries(
                    name: result.seriesName,
                    ownedPieces: {result.slot},
                  );
                  Navigator.of(context).pop();
                  _showSnack('${result.seriesName} koleksiyona eklendi.');
                },
              ),
            ],
          ),
        );
      },
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
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
        final filtered = widget.controller.series.where((serie) {
          final q = _query.toLowerCase();
          return serie.name.toLowerCase().contains(q) ||
              serie.seriesNumber.toString().contains(q);
        }).toList();

        if (widget.controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: CustomScrollView(
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
              SliverToBoxAdapter(
                child: filtered.isEmpty
                    ? _EmptyState(
                        query: _query,
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : _SeriesDataTable(series: filtered),
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
      padding: const MaterialStatePropertyAll(
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
        final bottomPadding =
            MediaQuery.of(context).viewPadding.bottom + 20;
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
            children: [
              _buildFormCard(context),
              const SizedBox(height: 28),
              Text(
                'Mevcut Setler',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (series.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Henüz kayıtlı bir seri yok.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Yeni eklediğiniz her seri burada düzenlenebilir olacak.',
                        ),
                      ],
                    ),
                  ),
                )
              else
              ...series.map(
                (serie) => _ManageSeriesCard(
                  key: ValueKey(serie.id),
                  series: serie,
                  controller: widget.controller,
                  onEdit: () => _openEditDialog(serie),
                  onDelete: () => _confirmDelete(serie),
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
                  onPressed: _handleSubmit,
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

    await widget.controller.upsertSeries(
      name: _modelController.text.trim(),
      ownedPieces: _ownedPieces,
    );

    if (mounted) {
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

  void _openEditDialog(LighterSeries series) {
    final modelController = TextEditingController(text: series.name);
    final ownedPieces = {...series.ownedPieces};

    showDialog<void>(
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
                    TextField(
                      controller: modelController,
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
                    final updatedName = modelController.text.trim();
                    if (updatedName.isEmpty) return;
                    await widget.controller.upsertSeries(
                      id: series.id,
                      name: updatedName,
                      ownedPieces: ownedPieces,
                    );
                    if (context.mounted) {
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
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                await widget.controller.removeSeries(series.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
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

class _SeriesDataTable extends StatelessWidget {
  const _SeriesDataTable({required this.series});

  final List<LighterSeries> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 96,
          dataRowMaxHeight: 140,
          columns: const [
            DataColumn(
              label: Text(
                'Seri / Model',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                'Seri No',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          rows: series
              .map(
                (serie) => DataRow(
                  key: ValueKey(serie.id),
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          _SeriesNumberBadge(number: serie.seriesNumber),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${serie.name} */4',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                _PieceStatusRow(serie: serie),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        serie.seriesNumber.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: serie.isComplete
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
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
                ? colorScheme.primary.withOpacity(0.15)
                : colorScheme.surfaceVariant,
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
              color: owned
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }),
    );
  }
}

class _PieceSelector extends StatelessWidget {
  const _PieceSelector({
    required this.ownedPieces,
    required this.onToggle,
  });

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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
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
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Seriyi düzenle',
                    ),
                    IconButton(
                      onPressed: onDelete,
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
                  onSelected: (value) async =>
                      await controller.setPiece(series.id, slot, value),
                );
              }),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: series.completionRatio,
              minHeight: 6,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceVariant,
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
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Toplam: $total', style: style),
          Text(
            'Tamamlanan: $completed | Devam: $inProgress',
            style: style,
          ),
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
        color: color.withOpacity(0.08),
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '"$query" ile eşleşen bir seri bulunamadı.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onClear,
            child: const Text('Aramayı temizle'),
          ),
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
      backgroundColor: colorScheme.primary.withOpacity(0.12),
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
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
  const _MatchSuggestionSheet({
    required this.query,
    required this.matches,
  });

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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
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

class _CameraScannerPage extends StatefulWidget {
  const _CameraScannerPage({required this.textRecognizer});

  final TextRecognizer textRecognizer;

  @override
  State<_CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<_CameraScannerPage> {
  CameraController? _cameraController;
  Future<void>? _initFuture;
  String? _error;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Cihazda kamera bulunamadı.');
        return;
      }
      final selected = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      setState(() => _cameraController = controller);
    } catch (e) {
      setState(() => _error = 'Kamera başlatılamadı: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }
    
    setState(() {
      _processing = true;
      _error = null;
    });
    
    XFile? capturedFile;
    try {
      // Her taramada yeni bir dosya oluştur
      capturedFile = await controller.takePicture();
      
      // Dosyayı işle - her seferinde yeni bir InputImage oluştur
      final inputImage = InputImage.fromFilePath(capturedFile.path);
      final recognised = await widget.textRecognizer.processImage(inputImage);
      
      // İşlem sonrası dosyayı hemen temizle (cache'i önlemek için)
      try {
        final file = File(capturedFile.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Dosya silme hatası kritik değil
      }
      
      if (!mounted) {
        setState(() => _processing = false);
        return;
      }
      
      // Sonucu al ve kontrol et
      final resultText = recognised.text.trim();
      
      // Eğer sonuç boşsa veya önceki ile aynıysa, hata göster
      if (resultText.isEmpty) {
        setState(() {
          _processing = false;
          _error = 'Metin algılanamadı, tekrar deneyin.';
        });
        return;
      }
      
      // State'i temizle ve sonucu döndür
      setState(() {
        _processing = false;
      });
      
      if (mounted) {
        Navigator.of(context).pop(resultText);
      }
    } catch (e) {
      // Hata durumunda dosyayı temizle
      if (capturedFile != null) {
        try {
          final file = File(capturedFile.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Dosya silme hatası kritik değil
        }
      }
      
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'Okuma başarısız: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metni Tara'),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (_cameraController == null ||
                    snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CameraPreview(_cameraController!),
                    ),
                    if (_processing)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Metni Tara'),
          onPressed: _processing ||
                  _cameraController == null ||
                  !(_cameraController?.value.isInitialized ?? false)
              ? null
              : _scan,
        ),
      ),
    );
  }
}

class LighterCollectionController extends ChangeNotifier {
  final CollectionRepository repository;
  StreamSubscription<List<LighterSeries>>? _subscription;
  List<LighterSeries> _series = [];
  bool _isLoading = true;

  LighterCollectionController({CollectionRepository? repo})
      : repository = repo ?? FirebaseCollectionRepository() {
    _subscription = repository.watchSeries().listen(
      (series) {
        _series = series;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  bool get isLoading => _isLoading;

  int get nextSeriesNumber {
    if (_series.isEmpty) return 1;
    return _series.map((s) => s.seriesNumber).reduce(max) + 1;
  }

  UnmodifiableListView<LighterSeries> get series {
    final ordered = [..._series]
      ..sort((a, b) => a.seriesNumber.compareTo(b.seriesNumber));
    return UnmodifiableListView(ordered);
  }

  int get totalSeries => _series.length;
  int get completedSeries => _series.where((s) => s.isComplete).length;
  int get inProgressSeries => totalSeries - completedSeries;

  List<LighterSeries> seriesByFilter(SeriesFilter filter) {
    final items = filter == SeriesFilter.completed
        ? _series.where((s) => s.isComplete)
        : _series.where((s) => !s.isComplete);
    final sorted = [...items]
      ..sort((a, b) => a.seriesNumber.compareTo(b.seriesNumber));
    return sorted;
  }

  LighterSeries? getById(String id) {
    try {
      return _series.firstWhere((serie) => serie.id == id);
    } catch (_) {
      return null;
    }
  }

  LighterSeries? findBestMatch(String rawText, {double minScore = 0.15}) {
    final normalizedQuery = _normalizeText(rawText);
    if (normalizedQuery.isEmpty) return null;
    LighterSeries? best;
    double bestScore = 0;
    for (final serie in _series) {
      final score =
          _matchScore(normalizedQuery, _normalizeText(serie.name));
      if (score > bestScore) {
        bestScore = score;
        best = serie;
      }
    }
    return bestScore >= minScore ? best : null;
  }

  List<SeriesMatch> rankedMatches(String rawText) {
    final normalizedQuery = _normalizeText(rawText);
    if (normalizedQuery.isEmpty) return const [];
    final results = <SeriesMatch>[];
    for (final serie in _series) {
      final score =
          _matchScore(normalizedQuery, _normalizeText(serie.name));
      if (score > 0) {
        results.add(SeriesMatch(series: serie, score: score));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  Future<void> upsertSeries({
    String? id,
    required String name,
    Set<int>? ownedPieces,
  }) async {
    final sanitized = _sanitizePieces(ownedPieces ?? {});
    if (id == null) {
      final newSeries = LighterSeries(
        id: _IdGenerator.next(),
        name: name.trim(),
        seriesNumber: nextSeriesNumber,
        ownedPieces: sanitized,
      );
      await repository.addSeries(newSeries);
    } else {
      final existing = getById(id);
      if (existing == null) return;
      final updated = existing.copyWith(
        name: name.trim(),
        ownedPieces: sanitized,
      );
      await repository.updateSeries(updated);
    }
  }

  Future<void> setPiece(String id, int slot, bool owned) async {
    await repository.setPiece(id, slot, owned);
  }

  Set<int> _sanitizePieces(Set<int> pieces) {
    return pieces.where((slot) => slot >= 1 && slot <= 4).toSet();
  }

  Future<void> removeSeries(String id) async {
    await repository.deleteSeries(id);
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  static String _normalizeText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9çğıöşü\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _matchScore(String haystack, String needle) {
    if (needle.isEmpty || haystack.isEmpty) return 0;
    if (haystack.contains(needle) || needle.contains(haystack)) {
      return 1;
    }
    final queryTokens = haystack.split(' ').where((t) => t.isNotEmpty).toSet();
    final needleTokens =
        needle.split(' ').where((token) => token.isNotEmpty).toList();
    if (needleTokens.isEmpty) return 0;
    final matches = needleTokens.where(
      (token) => queryTokens.any(
        (candidate) =>
            candidate.contains(token) || token.contains(candidate),
      ),
    );
    return matches.length / needleTokens.length;
  }
}

class _IdGenerator {
  static int _seed = 0;

  static String next() {
    _seed += 1;
    return 'series-$_seed';
  }
}

class SeriesMatch {
  const SeriesMatch({required this.series, required this.score});
  final LighterSeries series;
  final double score;
}