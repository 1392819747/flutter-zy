import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const AppleIconSortApp());
}

class AppleIconSortApp extends StatelessWidget {
  const AppleIconSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Apple Icon Sort',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF158A80)),
        useMaterial3: true,
      ),
      home: const AppleIconSortPage(),
    );
  }
}

class AppleIconSortPage extends StatefulWidget {
  const AppleIconSortPage({super.key});

  @override
  State<AppleIconSortPage> createState() => _AppleIconSortPageState();
}

class _AppleIconSortPageState extends State<AppleIconSortPage> {
  static const double _gridSpacing = 18; // 缩小行间距，在保持图标大小的同时容纳更多行
  static const double _iconVisualScale = 0.88; // 控制图标相对于单元格的大小
  static const int _iconsPerPage = 24; // 每页最多24个图标 (4x6) - 保持原数量

  late List<List<AppIconData>> _pages = _initializePages();

  List<List<AppIconData>> _initializePages() {
    // 获取非Dock栏图标
    final List<AppIconData> nonDockIcons = List.of(_defaultIcons);

    // 将Gmail单独提取出来
    AppIconData? gmailIcon;
    final List<AppIconData> otherIcons = [];

    for (final icon in nonDockIcons) {
      if (icon.label == 'Gmail') {
        gmailIcon = icon;
      } else {
        otherIcons.add(icon);
      }
    }

    // 创建分页数据
    final List<List<AppIconData>> pages = [];
    const int iconsPerPage = 24;

    // 第一页：其他图标
    for (int i = 0; i < otherIcons.length; i += iconsPerPage) {
      final int end = math.min(i + iconsPerPage, otherIcons.length);
      pages.add(otherIcons.sublist(i, end));
    }

    // 第二页：只放Gmail
    if (gmailIcon != null) {
      pages.add([gmailIcon]);
    } else {
      pages.add([]);
    }

    // 确保至少有2页
    while (pages.length < 2) {
      pages.add([]);
    }

    return pages;
  }

  late List<AppIconData> _dockIcons = [
    const AppIconData(
      label: 'Phone',
      iconData: CupertinoIcons.phone_fill,
      backgroundColor: Color(0xFF34C759),
      iconColor: Colors.white,
    ),
    const AppIconData(
      label: 'Messages',
      iconData: CupertinoIcons.chat_bubble_text_fill,
      backgroundColor: Color(0xFF32D74B),
      iconColor: Colors.white,
    ),
    const AppIconData(
      label: 'Safari',
      iconData: CupertinoIcons.compass_fill,
      backgroundColor: Color(0xFF0A84FF),
      iconColor: Colors.white,
    ),
    const AppIconData(
      label: 'Music',
      iconData: CupertinoIcons.music_note_2,
      backgroundColor: Color(0xFFFF2D55),
      iconColor: Colors.white,
    ),
  ];
  bool _isEditing = false;
  AppIconData? _draggingIcon;
  int? _dragStartIndex;
  int? _hoverSlot;
  int? _hoverDockSlot;
  final GlobalKey _dockKey = GlobalKey();
  _DockDimensions? _latestDockDimensions;
  double _cachedStatusBarHeight = 0;
  bool _dragFromDock = false;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int? _pendingAutoScrollPage;

  // 获取当前页的图标
  List<AppIconData> get _currentIcons => _pages[_currentPage];

  // 获取所有图标（用于搜索和管理）
  List<AppIconData> get _allIcons {
    return _pages.expand((page) => page).toList();
  }

  void _setSystemUiEditing(bool editing) {
    if (editing) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    } else {
      // 恢复系统UI，等待一帧确保状态更新
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!editing) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      });
    }
  }

  void _handleDragStart(BuildContext context, int index) {
    final AppIconData icon = _currentIcons[index];
    HapticFeedback.heavyImpact();
    setState(() {
      _isEditing = true;
      _draggingIcon = icon;
      _dragStartIndex = index;
      _hoverSlot = index;
      _cachedStatusBarHeight = MediaQuery.of(context).viewPadding.top;
      _dragFromDock = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setSystemUiEditing(true);
    });
  }

  void _handleDockDragStart(BuildContext context, int slot) {
    final AppIconData icon = _dockIcons[slot];
    HapticFeedback.heavyImpact();
    setState(() {
      _isEditing = true;
      _draggingIcon = icon;
      _dragStartIndex = slot;
      _hoverSlot = null;
      _hoverDockSlot = slot;
      _cachedStatusBarHeight = MediaQuery.of(context).viewPadding.top;
      _dragFromDock = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setSystemUiEditing(true);
    });
  }

  void _handleDragEnd({required bool wasAccepted}) {
    _cancelAutoScroll();
    setState(() {
      if (!wasAccepted && _draggingIcon != null && _dragStartIndex != null) {
        final AppIconData icon = _draggingIcon!;
        if (_dragFromDock) {
          final int currentIndex = _dockIcons.indexOf(icon);
          if (currentIndex != -1) {
            final AppIconData item = _dockIcons.removeAt(currentIndex);
            final int restoredIndex = math.max(0, math.min(_dragStartIndex!, _dockIcons.length));
            _dockIcons.insert(restoredIndex, item);
          }
        } else {
          // 查找图标在当前页面中的位置并恢复
          final int currentIndex = _currentIcons.indexOf(icon);
          if (currentIndex != -1) {
            final AppIconData item = _pages[_currentPage].removeAt(currentIndex);
            final int restoredIndex = math.max(0, math.min(_dragStartIndex!, _currentIcons.length));
            _pages[_currentPage].insert(restoredIndex, item);
          }
        }
      }
      _draggingIcon = null;
      _dragStartIndex = null;
      _hoverSlot = null;
      _hoverDockSlot = null;
      _dragFromDock = false;
    });
  }

  void _handleDelete(AppIconData icon) {
    setState(() {
      // 查找并删除图标
      for (int i = 0; i < _pages.length; i++) {
        if (_pages[i].remove(icon)) {
          break; // 只删除找到的第一个匹配项
        }
      }
      if (_currentIcons.isEmpty && _currentPage > 0) {
        // 如果当前页为空且不是第一页，切换到前一页
        _currentPage--;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      if (_allIcons.isEmpty) {
        _isEditing = false;
      }
      if (identical(_draggingIcon, icon)) {
        _draggingIcon = null;
        _hoverSlot = null;
        _dragStartIndex = null;
      }
    });
    if (!_isEditing) {
      _setSystemUiEditing(false);
    }
  }

  void _handleDeleteDock(AppIconData icon) {
    setState(() {
      _dockIcons.remove(icon);
      if (_dockIcons.isEmpty) {
        _isEditing = false;
      }
      if (identical(_draggingIcon, icon)) {
        _draggingIcon = null;
        _hoverSlot = null;
        _dragStartIndex = null;
        _hoverDockSlot = null;
      }
    });
    if (!_isEditing) {
      _setSystemUiEditing(false);
    }
  }

  void _handleDonePressed() {
    _cancelAutoScroll();
    setState(() {
      _isEditing = false;
      _draggingIcon = null;
      _hoverSlot = null;
      _hoverDockSlot = null;
      _dragStartIndex = null;
      // 重置状态栏高度缓存
      _cachedStatusBarHeight = 0;
    });

    // 使用WidgetsBinding.instance.addPostFrameCallback确保状态更新后再执行UI操作
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setSystemUiEditing(false);
    });
  }

  int _columnCountForWidth(double width) {
    if (width >= 320) {
      return 4;
    }
    if (width >= 280) {
      return 3;
    }
    return 2;
  }

  void _updateDragPosition(AppIconData icon, int slot) {
    // 查找图标在所有页面中的位置
    int findIconPageIndex(AppIconData icon) {
      for (int i = 0; i < _pages.length; i++) {
        if (_pages[i].contains(icon)) {
          return i;
        }
      }
      return -1;
    }

    int findIconIndexInPage(AppIconData icon, int pageIndex) {
      return _pages[pageIndex].indexOf(icon);
    }

    // 查找图标在当前页面中的位置
    int currentPageIndex = _currentPage;
    int currentIndexInPage = findIconIndexInPage(icon, currentPageIndex);
    int iconPageIndex = findIconPageIndex(icon);

    // 如果图标不在任何页面中，说明是从 Dock 拖到桌面
    if (iconPageIndex == -1) {
      if (_hoverSlot != slot) {
        setState(() {
          _hoverSlot = math.min(slot, _currentIcons.length);
        });
      }
      return;
    }

    // 如果图标在其他页面，需要先移动到当前页面
    if (iconPageIndex != currentPageIndex) {
      setState(() {
        // 从原页面移除
        _pages[iconPageIndex].remove(icon);
        // 插入到当前页面的指定位置
        int insertIndex = math.min(slot, _currentIcons.length);
        _pages[_currentPage].insert(insertIndex, icon);
        _hoverSlot = insertIndex;
        // 检查是否需要创建新页面
        _checkAndCreatePageIfNeeded();
      });
      return;
    }

    // 图标在当前页面内移动
    int desiredIndex = slot;
    if (currentIndexInPage < slot) {
      desiredIndex -= 1;
    }
    if (_currentIcons.isEmpty) {
      desiredIndex = 0;
    } else {
      desiredIndex = math.max(0, math.min(desiredIndex, _currentIcons.length - 1));
    }

    if (desiredIndex == currentIndexInPage) {
      if (_hoverSlot != slot) {
        setState(() {
          _hoverSlot = slot;
        });
      }
      return;
    }

    setState(() {
      final AppIconData item = _pages[_currentPage].removeAt(currentIndexInPage);
      int insertIndex = slot;
      if (currentIndexInPage < slot) {
        insertIndex -= 1;
      }
      insertIndex = math.max(0, math.min(insertIndex, _currentIcons.length));
      _pages[_currentPage].insert(insertIndex, item);
      _hoverSlot = slot;
    });
  }

  void _checkAndCreatePageIfNeeded() {
    // 如果当前页面满了，自动创建新页面
    if (_currentIcons.length > _iconsPerPage) {
      // 创建新页面
      final List<AppIconData> overflowIcons = _pages[_currentPage].sublist(_iconsPerPage);
      _pages[_currentPage] = _pages[_currentPage].sublist(0, _iconsPerPage);

      // 如果还有下一页，将溢出的图标添加到下一页
      if (_currentPage + 1 < _pages.length) {
        _pages[_currentPage + 1].insertAll(0, overflowIcons);
      } else {
        // 创建新的页面
        _pages.add(overflowIcons);
      }

      // 切换到新的页面
      if (_currentPage + 1 < _pages.length) {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _handleDropAccepted(AppIconData icon, int slot) {
    setState(() {
      if (!_currentIcons.contains(icon)) {
        // 确保图标不再其他位置
        for (final page in _pages) {
          page.remove(icon);
        }
        _dockIcons.remove(icon);
        final int insertIndex = math.min(slot, _currentIcons.length);
        _pages[_currentPage].insert(insertIndex, icon);
        _hoverSlot = insertIndex;
        _checkAndCreatePageIfNeeded();
      } else {
        _hoverSlot = slot;
      }
      _hoverDockSlot = null;
    });
  }

  void _handleDockDrop(AppIconData icon, int slot) {
    setState(() {
      for (final page in _pages) {
        page.remove(icon);
      }
      final bool alreadyInDock = _dockIcons.contains(icon);
      if (!alreadyInDock && _dockIcons.length >= 4) {
        _hoverDockSlot = null;
        return;
      }
      _dockIcons.remove(icon);
      final int insertIndex = math.min(slot, _dockIcons.length);
      _dockIcons.insert(insertIndex, icon);
      _hoverDockSlot = null;
    });
  }

  Widget _buildDraggableIcon({
    required int index,
    required double itemWidth,
  }) {
    final AppIconData icon = _currentIcons[index];
    final bool isDragging = identical(_draggingIcon, icon);
    final double tileSize = itemWidth * _iconVisualScale;

    return DragTarget<AppIconData>(
      onWillAccept: (from) => from != null,
      onMove: (details) {
        if (details.data != null && !identical(details.data, icon)) {
          _updateDragPosition(details.data, index);
        } else if (_hoverSlot != index) {
          setState(() {
            _hoverSlot = index;
          });
        }
      },
      onLeave: (_) {
        if (_hoverSlot == index && _draggingIcon != null) {
          setState(() {
            _hoverSlot = null;
          });
        }
      },
      onAccept: (data) {
        if (data != null) {
          _handleDropAccepted(data, index);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<AppIconData>(
          data: icon,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _DragFeedback(icon: icon, size: tileSize),
          onDragStarted: () => _handleDragStart(context, index),
          onDragUpdate: _handleDragUpdate,
          onDragEnd: (details) => _handleDragEnd(wasAccepted: details.wasAccepted),
          childWhenDragging: const SizedBox.shrink(),
          child: SizedBox(
            width: itemWidth,
            child: Center(
              child: AppleIconTile(
                key: ValueKey(icon.label),
                icon: icon,
                isActive: isDragging,
                isEditing: _isEditing,
                isHighlighted: false,
                onDelete: () => _handleDelete(icon),
                size: tileSize,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrailingDropTarget(double itemWidth) {
    final bool isActive = _hoverSlot == _currentIcons.length && _draggingIcon != null;
    final double tileSize = itemWidth * _iconVisualScale;
    return SizedBox(
      width: itemWidth,
      child: DragTarget<AppIconData>(
        onWillAccept: (data) => data != null,
        onMove: (details) {
          if (details.data != null) {
            _updateDragPosition(details.data, _currentIcons.length);
          }
        },
        onLeave: (_) {
          if (_hoverSlot == _currentIcons.length && _draggingIcon != null) {
            setState(() {
              _hoverSlot = null;
            });
          }
        },
        onAccept: (data) {
          if (data != null) {
            _handleDropAccepted(data, _currentIcons.length);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return SizedBox(height: itemWidth);
        },
      ),
    );
  }

  _DockDimensions _calculateDockDimensions(BuildContext context) {
    const int columns = 4;
    const double horizontalPadding = 18;
    const double verticalPadding = 20;
    const double spacing = _gridSpacing;

    final Size size = MediaQuery.of(context).size;
    final double outerWidth = size.width - 24; // 左右各12
    final double availableWidth = outerWidth - (horizontalPadding * 2);
    final double gridWidth = size.width - 36;
    final double gridItemWidth = (gridWidth - spacing * (columns - 1)) / columns;
    final double dockItemWidth = (availableWidth - spacing * (columns - 1)) / columns;
    final double itemWidth = math.min(gridItemWidth, dockItemWidth);
    final double contentWidth = itemWidth * columns + spacing * (columns - 1);
    final double dockHeight = itemWidth + verticalPadding;

    return _DockDimensions(
      itemSize: itemWidth,
      contentWidth: contentWidth,
      height: dockHeight,
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      spacing: spacing,
    );
  }

  Widget _buildDock(BuildContext context, _DockDimensions dims) {
    return Container(
      key: _dockKey,
      padding: EdgeInsets.symmetric(
        horizontal: dims.horizontalPadding,
        vertical: dims.verticalPadding * 0.5,
      ),
      height: dims.height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30),
        ],
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: dims.contentWidth,
        height: dims.itemSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < 4; i++)
              Positioned(
                left: i * (dims.itemSize + dims.spacing),
                top: 0,
                width: dims.itemSize,
                height: dims.itemSize,
                child: DragTarget<AppIconData>(
                  onWillAccept: (data) {
                    if (data == null) return false;
                    if (_dockIcons.length >= 4 && !_dockIcons.contains(data)) {
                      return false;
                    }
                    return true;
                  },
                  onAccept: (data) {
                    _handleDockDrop(data, i);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ..._buildDockIconWidgets(dims),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDockIconWidgets(_DockDimensions dims) {
    final List<Widget> widgets = [];
    final bool draggingDockIcon =
        _dragFromDock && _draggingIcon != null && _dockIcons.contains(_draggingIcon);

    final List<AppIconData> iconsToRender = [
      for (final icon in _dockIcons)
        if (!(draggingDockIcon && identical(icon, _draggingIcon))) icon,
    ];

    final int count = iconsToRender.length;
    final double usedWidth =
        count * dims.itemSize + math.max(0, count - 1) * dims.spacing;
    final double start = math.max(0, (dims.contentWidth - usedWidth) / 2);

    for (int displayIndex = 0; displayIndex < count; displayIndex++) {
      final AppIconData icon = iconsToRender[displayIndex];
      final int iconIndex = _dockIcons.indexOf(icon);
      final double left = start + displayIndex * (dims.itemSize + dims.spacing);
      widgets.add(
        AnimatedPositioned(
          key: ValueKey(icon.label),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: left,
          top: 0,
          width: dims.itemSize,
          height: dims.itemSize,
          child: Center(
            child: SizedBox(
              width: dims.itemSize * _iconVisualScale,
              height: dims.itemSize * _iconVisualScale,
              child: _DockIconTile(
                icon: icon,
                isEditing: _isEditing,
                size: dims.itemSize * _iconVisualScale,
                onDelete: () => _handleDeleteDock(icon),
                onDragStart: () => _handleDockDragStart(context, iconIndex),
                onDragEnd: (details) => _handleDragEnd(wasAccepted: details.wasAccepted),
                onDragUpdate: _handleDragUpdate,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < math.max(2, _pages.length); i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == i ? Colors.white : Colors.white.withOpacity(0.3),
            ),
          ),
      ],
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final Size screenSize = MediaQuery.of(context).size;
    const double edgeThreshold = 40;
    final double dx = details.globalPosition.dx;
    final int maxPageIndex = math.max(2, _pages.length) - 1;

    if (dx <= edgeThreshold && _currentPage > 0) {
      _scheduleAutoScroll(_currentPage - 1);
    } else if (dx >= screenSize.width - edgeThreshold &&
        _currentPage < maxPageIndex) {
      _scheduleAutoScroll(_currentPage + 1);
    } else {
      _cancelAutoScroll();
    }

    _handleDockHover(details.globalPosition);
  }

  void _scheduleAutoScroll(int targetPage) {
    if (_pendingAutoScrollPage == targetPage &&
        _autoScrollTimer?.isActive == true) {
      return;
    }
    _autoScrollTimer?.cancel();
    _pendingAutoScrollPage = targetPage;
    _autoScrollTimer = Timer(const Duration(seconds: 2), () {
      if (!_pageController.hasClients) {
        _cancelAutoScroll();
        return;
      }
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _cancelAutoScroll();
    });
  }

  void _cancelAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _pendingAutoScrollPage = null;
  }

  void _handleDockHover(Offset globalPosition) {
    final RenderBox? dockBox =
        _dockKey.currentContext?.findRenderObject() as RenderBox?;
    final _DockDimensions? dims = _latestDockDimensions;
    if (dockBox == null || dims == null) {
      return;
    }
    final Offset local = dockBox.globalToLocal(globalPosition);
    const double verticalTolerance = 36;
    final bool insideX = local.dx >= 0 && local.dx <= dockBox.size.width;
    final bool insideY =
        local.dy >= -verticalTolerance && local.dy <= dockBox.size.height + verticalTolerance;

    if (!insideX || !insideY) {
      if (_hoverDockSlot != null) {
        setState(() {
          _hoverDockSlot = null;
        });
      }
      return;
    }

    final double slotWidth = dims.itemSize + dims.spacing;
    int slot = (local.dx / slotWidth).floor();
    slot = math.max(0, math.min(3, slot));

    if (_hoverDockSlot != slot) {
      setState(() {
        _hoverDockSlot = slot;
      });
    }
  }

  @override
  void dispose() {
    _cancelAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _DockDimensions dockDimensions = _calculateDockDimensions(context);
    _latestDockDimensions = dockDimensions;

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF158A80),
                    Color(0xFF072F2C),
                    Color(0xFF010C0B),
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            const Color(0xFF158A80).withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 主内容区域 - 支持分页
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _isEditing && _cachedStatusBarHeight > 0
                        ? _cachedStatusBarHeight
                        : MediaQuery.of(context).viewPadding.top,
                    bottom: 0,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                      controller: _pageController,
                      physics: const PageScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                          _hoverSlot = null;
                        });
                      },
                      itemCount: math.max(2, _pages.length), // 使用实际的分页数量，至少2页
                      itemBuilder: (context, pageIndex) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double width = constraints.maxWidth;
                              final int columns = _columnCountForWidth(width);
                              final double itemWidth =
                                  (width - _gridSpacing * (columns - 1)) / columns;

                              double cellHeight = itemWidth + 16;
                              final int targetRows = (_iconsPerPage / columns).ceil();
                              final double maxHeightForRows =
                                  (constraints.maxHeight - (_gridSpacing * (targetRows - 1))) /
                                      targetRows;
                              cellHeight = math.min(cellHeight, maxHeightForRows);
                              // 获取当前页面的图标
                              final List<AppIconData> pageIcons = pageIndex < _pages.length
                                  ? _pages[pageIndex]
                                  : [];
                              final bool isCurrentPage = pageIndex == _currentPage;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (int i = 0; i < pageIcons.length; i++)
                                    _AnimatedGridItem(
                                      key: ValueKey('${pageIndex}_${pageIcons[i].label}'),
                                      index: i,
                                      columns: columns,
                                      spacing: _gridSpacing,
                                      itemWidth: itemWidth,
                                      itemHeight: cellHeight,
                                      child: isCurrentPage
                                          ? _buildDraggableIcon(
                                              index: i,
                                              itemWidth: itemWidth,
                                            )
                                          : IgnorePointer(
                                              child: SizedBox(
                                                width: itemWidth,
                                                child: Center(
                                                  child: AppleIconTile(
                                                    key: ValueKey('static_${pageIndex}_${pageIcons[i].label}'),
                                                    icon: pageIcons[i],
                                                    isEditing: _isEditing,
                                                    onDelete: () {},
                                                    size: itemWidth * _iconVisualScale,
                                                    isActive: false,
                                                    isHighlighted: false,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  if (isCurrentPage &&
                                      _draggingIcon != null &&
                                      pageIcons.length < _iconsPerPage)
                                    _AnimatedGridItem(
                                      key: const ValueKey('trailing_drop'),
                                      index: pageIcons.length,
                                      columns: columns,
                                      spacing: _gridSpacing,
                                      itemWidth: itemWidth,
                                      itemHeight: cellHeight,
                                      child: _buildTrailingDropTarget(itemWidth),
                                    ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28 + dockDimensions.height,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10),
                    ],
                  ),
                  child: _buildPageIndicator(),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _buildDock(context, dockDimensions),
            ),
                  // Done 按钮 - 在编辑模式时显示在状态栏区域
                  if (_isEditing)
                    Positioned(
                      top: 8,
                      right: 18,
                      child: _DoneButton(onPressed: _handleDonePressed),
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

class _DockDimensions {
  const _DockDimensions({
    required this.itemSize,
    required this.contentWidth,
    required this.height,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.spacing,
  });

  final double itemSize;
  final double contentWidth;
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double spacing;
}

class AppIconData {
  const AppIconData({
    this.assetPath,
    required this.label,
    this.iconData,
    this.iconColor,
    this.backgroundColor,
  }) : assert(assetPath != null || iconData != null,
            'Either assetPath or iconData must be provided');

  final String? assetPath;
  final String label;
  final IconData? iconData;
  final Color? iconColor;
  final Color? backgroundColor;
}

class AppleIconTile extends StatefulWidget {
  const AppleIconTile({
    super.key,
    required this.icon,
    required this.isEditing,
    required this.onDelete,
    required this.size,
    required this.isActive,
    required this.isHighlighted,
  });

  final AppIconData icon;
  final bool isEditing;
  final VoidCallback onDelete;
  final double size;
  final bool isActive;
  final bool isHighlighted;

  @override
  State<AppleIconTile> createState() => _AppleIconTileState();
}

class _AppleIconTileState extends State<AppleIconTile>
    with SingleTickerProviderStateMixin {
  static const double _maxAngle = 2 * math.pi / 180;
  static const Duration _shakeDuration = Duration(milliseconds: 150);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _shakeDuration,
    lowerBound: -_maxAngle,
    upperBound: _maxAngle,
  );
  Timer? _startDelayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _startShaking();
    }
  }

  @override
  void didUpdateWidget(covariant AppleIconTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !_controller.isAnimating) {
      _startShaking();
    } else if (!widget.isEditing && _controller.isAnimating) {
      _stopShaking();
    }
  }

  void _startShaking() {
    _startDelayTimer?.cancel();
    _startDelayTimer = Timer(
      Duration(milliseconds: 80 + math.Random().nextInt(220)),
      () {
        if (!mounted || !widget.isEditing) {
          return;
        }
        _controller.repeat(min: -_maxAngle, max: _maxAngle, reverse: true);
      },
    );
  }

  void _stopShaking() {
    _startDelayTimer?.cancel();
    _controller.animateTo(
      0,
      duration: _shakeDuration,
      curve: Curves.easeInOut,
    ).whenComplete(() {
      if (mounted) {
        _controller.stop();
      }
    });
  }

  @override
  void dispose() {
    _startDelayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double angle = widget.isEditing ? _controller.value : 0;
        return Transform.rotate(
          angle: angle,
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppleIconBody(
              icon: widget.icon,
              isHighlighted: widget.isHighlighted,
              size: widget.size,
            ),
            Positioned(
              top: -12,
              left: -12,
              child: IgnorePointer(
                ignoring: !widget.isEditing || widget.isActive,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: widget.isEditing && !widget.isActive ? 1 : 0,
                  child: _DeleteButton(onPressed: widget.onDelete),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppleIconBody extends StatelessWidget {
  const AppleIconBody({
    super.key,
    required this.icon,
    required this.size,
    required this.isHighlighted,
    this.showLabel = true,
  });

  final AppIconData icon;
  final double size;
  final bool isHighlighted;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final double radius = size * 0.225; // iPhone 标准圆角比例
    final Widget iconContent = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(4), // 更紧凑的内容
          decoration: BoxDecoration(
            color: icon.backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            border: isHighlighted
                ? Border.all(color: Colors.white.withOpacity(0.7), width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: icon.backgroundColor ?? Colors.white,
                alignment: Alignment.center,
                child: icon.assetPath != null
                    ? Image.asset(
                        icon.assetPath!,
                        fit: BoxFit.contain,
                      )
                    : Icon(
                        icon.iconData,
                        color: icon.iconColor ?? Colors.white,
                        size: size * 0.5,
                      ),
              ),
            ),
          ),
        );
    if (!showLabel) {
      return iconContent;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconContent,
        const SizedBox(height: 4),
        Text(
          icon.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 1),
                blurRadius: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(180, 180, 180, 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: const Text(
          '-',
          style: TextStyle(
            fontSize: 28,
            height: 0.9,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(180, 180, 180, 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Done',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.icon, required this.size});

  final AppIconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: 1.05,
        child: SizedBox(
          width: size,
          child: AppleIconBody(
            icon: icon,
            isHighlighted: true,
            size: size,
          ),
        ),
      ),
    );
  }
}

class _AnimatedGridItem extends StatelessWidget {
  const _AnimatedGridItem({
    super.key,
    required this.index,
    required this.columns,
    required this.spacing,
    required this.itemWidth,
    required this.itemHeight,
    required this.child,
  });

  final int index;
  final int columns;
  final double spacing;
  final double itemWidth;
  final double itemHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int row = index ~/ columns;
    final int col = index % columns;
    final double left = col * (itemWidth + spacing);
    final double top = row * (itemHeight + spacing);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      left: left,
      top: top,
      width: itemWidth,
      height: itemHeight,
      child: child,
    );
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({
    required this.icon,
    required this.size,
    required this.isHighlighted,
    this.showLabel = false,
  });

  final AppIconData icon;
  final double size;
  final bool isHighlighted;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final Widget content = AppleIconBody(
      icon: icon,
      size: size,
      isHighlighted: isHighlighted,
      showLabel: showLabel,
    );
    return content;
  }
}

// removed: moved inside _AppleIconSortPageState

const List<AppIconData> _defaultIcons = [
  AppIconData(assetPath: 'assets/icons/amazon.png', label: 'Amazon'),
  AppIconData(assetPath: 'assets/icons/dropbox.png', label: 'Dropbox'),
  AppIconData(assetPath: 'assets/icons/facebook.png', label: 'Facebook'),
  AppIconData(assetPath: 'assets/icons/github.png', label: 'GitHub'),
  AppIconData(assetPath: 'assets/icons/google.png', label: 'Google'),
  AppIconData(assetPath: 'assets/icons/google-drive.png', label: 'Drive'),
  AppIconData(assetPath: 'assets/icons/instagram.png', label: 'Instagram'),
  AppIconData(assetPath: 'assets/icons/linkedin.png', label: 'LinkedIn'),
  AppIconData(assetPath: 'assets/icons/messenger.png', label: 'Messenger'),
  AppIconData(assetPath: 'assets/icons/paypal.png', label: 'PayPal'),
  AppIconData(assetPath: 'assets/icons/pinterest.png', label: 'Pinterest'),
  AppIconData(assetPath: 'assets/icons/reddit.png', label: 'Reddit'),
  AppIconData(assetPath: 'assets/icons/skype.png', label: 'Skype'),
  AppIconData(assetPath: 'assets/icons/spotify.png', label: 'Spotify'),
  AppIconData(assetPath: 'assets/icons/telegram.png', label: 'Telegram'),
  AppIconData(assetPath: 'assets/icons/twitter.png', label: 'Twitter'),
  AppIconData(assetPath: 'assets/icons/whatsapp.png', label: 'WhatsApp'),
  AppIconData(assetPath: 'assets/icons/youtube.png', label: 'YouTube'),
  AppIconData(assetPath: 'assets/icons/gmail.png', label: 'Gmail'), // 移到最后，在第二页
];

class _DockIconTile extends StatefulWidget {
  const _DockIconTile({
    required this.icon,
    required this.isEditing,
    required this.size,
    required this.onDelete,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDragUpdate,
  });

  final AppIconData icon;
  final bool isEditing;
  final double size;
  final VoidCallback onDelete;
  final VoidCallback onDragStart;
  final Function(DraggableDetails) onDragEnd;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  @override
  State<_DockIconTile> createState() => _DockIconTileState();
}

class _DockIconTileState extends State<_DockIconTile>
    with SingleTickerProviderStateMixin {
  static const double _maxAngle = 2 * math.pi / 180;
  static const Duration _shakeDuration = Duration(milliseconds: 150);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _shakeDuration,
    lowerBound: -_maxAngle,
    upperBound: _maxAngle,
  );
  Timer? _startDelayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _startShaking();
    }
  }

  @override
  void didUpdateWidget(covariant _DockIconTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !_controller.isAnimating) {
      _startShaking();
    } else if (!widget.isEditing && _controller.isAnimating) {
      _stopShaking();
    }
  }

  void _startShaking() {
    _startDelayTimer?.cancel();
    _startDelayTimer = Timer(
      Duration(milliseconds: 80 + math.Random().nextInt(220)),
      () {
        if (!mounted || !widget.isEditing) {
          return;
        }
        _controller.repeat(min: -_maxAngle, max: _maxAngle, reverse: true);
      },
    );
  }

  void _stopShaking() {
    _startDelayTimer?.cancel();
    _controller.animateTo(
      0,
      duration: _shakeDuration,
      curve: Curves.easeInOut,
    ).whenComplete(() {
      if (mounted) {
        _controller.stop();
      }
    });
  }

  @override
  void dispose() {
    _startDelayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double visualSize = widget.size * 0.88;
    final double offset = (widget.size - visualSize) / 2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double angle = widget.isEditing ? _controller.value : 0;
        return Transform.rotate(
          angle: angle,
          child: child,
        );
      },
      child: LongPressDraggable<AppIconData>(
        data: widget.icon,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: SizedBox(
          width: widget.size,
          height: widget.size,
          child: _IconSquare(
            icon: widget.icon,
            size: widget.size,
            isHighlighted: true,
            showLabel: false,
          ),
        ),
        onDragStarted: widget.onDragStart,
        onDragEnd: widget.onDragEnd,
        onDragUpdate: widget.onDragUpdate,
        childWhenDragging: const SizedBox.shrink(),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: _IconSquare(icon: widget.icon, size: widget.size, isHighlighted: false),
              ),
              Positioned(
                top: -10,
                left: -10,
                child: IgnorePointer(
                  ignoring: !widget.isEditing,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: widget.isEditing ? 1 : 0,
                    child: _DeleteButton(onPressed: widget.onDelete),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
