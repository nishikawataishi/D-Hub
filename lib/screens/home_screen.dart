import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

/// ホーム画面
/// 団体一覧を2列グリッドで表示。検索・ジャンルフィルタリング機能付き。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _firestoreService = FirestoreService();
  OrgCategory _selectedCategory = OrgCategory.all;
  String _searchQuery = '';

  /// 検索とフィルタリング（リスト内でクライアント側フィルタ）
  List<Organization> _filterOrganizations(List<Organization> orgs) {
    return orgs.where((org) {
      final matchesCategory =
          _selectedCategory == OrgCategory.all ||
          org.category == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          org.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          org.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('D.scout'),
        actions: [
          // 開発用: Firestoreにデータを投入するボタン
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'データ投入（開発用）',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _firestoreService.seedData();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Firestoreにデータを投入しました！'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'サークル・ゼミを検索',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.textSecondary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ジャンルフィルター（チップ）
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: OrgCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = OrgCategory.values[index];
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  label: Text(category.label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedCategory = category);
                  },
                  backgroundColor: AppTheme.surface,
                  selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 団体グリッド（2列）- Firestoreからリアルタイム取得
          Expanded(
            child: StreamBuilder<List<Organization>>(
              stream: _firestoreService.getOrganizations(),
              builder: (context, snapshot) {
                // Firestoreから取得できた場合はそのデータを使用
                // 取得できない場合はモックデータにフォールバック
                final allOrgs = snapshot.hasData && snapshot.data!.isNotEmpty
                    ? snapshot.data!
                    : mockOrganizations;

                final filtered = _filterOrganizations(allOrgs);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '該当する団体が見つかりません',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _OrganizationCard(organization: filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 団体カード（グリッドアイテム）
class _OrganizationCard extends StatelessWidget {
  final Organization organization;

  const _OrganizationCard({required this.organization});

  /// キャンパスに応じたバッジの色を返す
  Color _campusColor() {
    switch (organization.campus) {
      case Campus.imadegawa:
        return AppTheme.campusImadegawa;
      case Campus.kyotanabe:
        return AppTheme.campusKyotanabe;
      case Campus.both:
        return AppTheme.campusBoth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // メイン画像エリア＋キャンパスバッジ
          Stack(
            children: [
              Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _campusColor().withValues(alpha: 0.15),
                      _campusColor().withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    organization.logoEmoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              // キャンパスバッジ
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _campusColor(),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    organization.campus.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // テキスト情報
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ジャンルタグ
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      organization.category.label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 団体名
                  Text(
                    organization.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 説明文
                  Expanded(
                    child: Text(
                      organization.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
