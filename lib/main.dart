import 'dart:async';
import 'dart:math' as math;

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
  static const double _gridSpacing = 30; // 增加间距使图标更小，但保持数量不变
  static const int _iconsPerPage = 24; // 每页最多24个图标 (4x6) - 保持原数量

  late List<List<AppIconData>> _pages = _initializePages();

  List<List<AppIconData>> _initializePages() {
    // 获取非Dock栏图标
    final List<AppIconData> nonDockIcons = _defaultIcons
        .where((a) => !{
            'Instagram', 'Twitter', 'WhatsApp', 'YouTube'
          }.contains(a.label))
        .toList();

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
    for (final a in _defaultIcons)
      if ({'Instagram', 'Twitter', 'WhatsApp', 'YouTube'}.contains(a.label)) a,
  ];
  bool _isEditing = false;
  AppIconData? _draggingIcon;
  int? _dragStartIndex;
  int? _hoverSlot;
  double _cachedStatusBarHeight = 0;
  bool _dragFromDock = false;
  int _currentPage = 0;
  final PageController _pageController = PageController();

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
      _cachedStatusBarHeight = MediaQuery.of(context).viewPadding.top;
      _dragFromDock = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setSystemUiEditing(true);
    });
  }

  void _handleDragEnd({required bool wasAccepted}) {
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
      }
    });
    if (!_isEditing) {
      _setSystemUiEditing(false);
    }
  }

  void _handleDonePressed() {
    setState(() {
      _isEditing = false;
      _draggingIcon = null;
      _hoverSlot = null;
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
      setState(() {
        // 从 Dock 拖到桌面，插入到当前页的中间位置
        final int middleIndex = _currentIcons.length ~/ 2;
        _pages[_currentPage].insert(middleIndex, icon);
        _dockIcons.remove(icon);
        _hoverSlot = middleIndex;
        // 检查是否需要创建新页面
        _checkAndCreatePageIfNeeded();
      });
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

  Widget _buildDraggableIcon({
    required int index,
    required double itemWidth,
  }) {
    final AppIconData icon = _currentIcons[index];
    final bool isDragging = identical(_draggingIcon, icon);
    final bool isHighlighted = _hoverSlot == index && _draggingIcon != null;

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
      onAccept: (_) {
        setState(() {
          _hoverSlot = index;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final bool showHighlight = isHighlighted || candidateData.isNotEmpty;
        return LongPressDraggable<AppIconData>(
          data: icon,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _DragFeedback(icon: icon, size: itemWidth),
          onDragStarted: () => _handleDragStart(context, index),
          onDragEnd: (details) => _handleDragEnd(wasAccepted: details.wasAccepted),
          childWhenDragging: _DropPlaceholder(
            size: itemWidth,
            isActive: showHighlight,
            isVisible: true,
          ),
          child: AppleIconTile(
            key: ValueKey(icon.label),
            icon: icon,
            isActive: isDragging,
            isEditing: _isEditing,
            isHighlighted: showHighlight,
            onDelete: () => _handleDelete(icon),
            size: itemWidth,
          ),
        );
      },
    );
  }

  Widget _buildTrailingDropTarget(double itemWidth) {
    final bool isActive = _hoverSlot == _currentIcons.length && _draggingIcon != null;
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
        onAccept: (_) {
          setState(() {
            _hoverSlot = _currentIcons.length;
          });
        },
        builder: (context, candidateData, rejectedData) {
          final bool shouldShow = _draggingIcon != null || candidateData.isNotEmpty;
          return _DropPlaceholder(
            size: itemWidth,
            isActive: isActive || candidateData.isNotEmpty,
            isVisible: shouldShow,
          );
        },
      ),
    );
  }

  Widget _buildDock(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const int columns = 4;
    const double spacing = 25; // 增加间距使Dock图标更小，与主页面一致
    const double horizontalPadding = 12;
    // 计算可用宽度：屏幕宽度 - 左右外边距(36) - 左右内边距(24)
    final double availableWidth = screenWidth - 36 - (horizontalPadding * 2);
    final double itemWidth = (availableWidth - spacing * (columns - 1)) / columns;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      height: itemWidth + 16,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30),
        ],
      ),
      child: Stack(
        children: [
          // 放置4个 DragTarget 槽位
          for (int i = 0; i < columns; i++)
            Positioned(
              left: i * (itemWidth + spacing),
              top: 0,
              width: itemWidth,
              height: itemWidth,
              child: DragTarget<AppIconData>(
                onWillAccept: (data) {
                  if (data == null) return false;
                  // 如果 Dock 已满（4个），且拖入的不是 Dock 中已有的，则拒绝
                  if (_dockIcons.length >= 4 && !_dockIcons.contains(data)) {
                    return false;
                  }
                  return true;
                },
                onAccept: (data) {
                  setState(() {
                    _currentIcons.remove(data);
                    if (_dockIcons.contains(data)) {
                      _dockIcons.remove(data);
                    }
                    // 只有在 Dock 未满时才能插入新图标
                    if (_dockIcons.length < 4) {
                      if (i <= _dockIcons.length) {
                        _dockIcons.insert(i, data);
                      } else {
                        _dockIcons.add(data);
                      }
                    } else {
                      // Dock 已满，插入到指定位置
                      if (i <= _dockIcons.length) {
                        _dockIcons.insert(i, data);
                      } else {
                        _dockIcons.add(data);
                      }
                    }
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  final bool hasIcon = i < _dockIcons.length;
                  final bool active = candidateData.isNotEmpty;
                  if (!hasIcon) {
                    return _DropPlaceholder(size: itemWidth, isActive: active, isVisible: true);
                  }
                  // 如果有图标，显示占位符但保持透明
                  return Container(
                    width: itemWidth,
                    height: itemWidth,
                    color: Colors.transparent,
                  );
                },
              ),
            ),
          // 使用 AnimatedPositioned 显示实际的图标
          for (int i = 0; i < _dockIcons.length; i++)
            AnimatedPositioned(
              key: ValueKey(_dockIcons[i].label),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: i * (itemWidth + spacing),
              top: 0,
              width: itemWidth,
              height: itemWidth,
              child: _DockIconTile(
                icon: _dockIcons[i],
                isEditing: _isEditing,
                size: itemWidth,
                onDelete: () => _handleDeleteDock(_dockIcons[i]),
                onDragStart: () => _handleDockDragStart(context, i),
                onDragEnd: (details) => _handleDragEnd(wasAccepted: details.wasAccepted),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      physics: _isEditing ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemCount: math.max(2, _pages.length), // 使用实际的分页数量，至少2页
                      itemBuilder: (context, pageIndex) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double width = constraints.maxWidth;
                              final int columns = _columnCountForWidth(width);
                              final double itemWidth =
                                  (width - _gridSpacing * (columns - 1)) / columns;

                              final double cellHeight = itemWidth + 40;
                              // 获取当前页面的图标
                              final List<AppIconData> pageIcons = pageIndex < _pages.length
                                  ? _pages[pageIndex]
                                  : [];

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (int i = 0; i < pageIcons.length; i++)
                                    _AnimatedGridItem(
                                      key: ValueKey(pageIcons[i].label),
                                      index: i,
                                      columns: columns,
                                      spacing: _gridSpacing,
                                      itemWidth: itemWidth,
                                      itemHeight: cellHeight,
                                      child: _buildDraggableIcon(
                                        index: i,
                                        itemWidth: itemWidth,
                                      ),
                                    ),
                                  if (_draggingIcon != null &&
                                      _hoverSlot != null)
                                    _AnimatedGridItem(
                                      key: const ValueKey('trailing_drop'),
                                      index: _hoverSlot!,
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
                  // 页面指示器 - 至少显示2页
                  Padding(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < math.max(2, _pages.length); i++)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentPage == i
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 12.0,  // 使用图标标签的字体大小
              child: _buildDock(context),
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

class AppIconData {
  const AppIconData({required this.assetPath, required this.label});

  final String assetPath;
  final String label;
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
  });

  final AppIconData icon;
  final double size;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final double radius = size * 0.225; // iPhone 标准圆角比例
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6), // 减小内边距
          decoration: BoxDecoration(
            color: Colors.white,
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
                color: Colors.white,
                alignment: Alignment.center,
                child: Image.asset(
                  icon.assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          icon.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
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

class _DropPlaceholder extends StatelessWidget {
  const _DropPlaceholder({
    required this.size,
    required this.isActive,
    required this.isVisible,
  });

  final double size;
  final bool isActive;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final double radius = size * 0.225; // iPhone 标准圆角比例
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isActive ? 1 : 0.75,
      child: SizedBox(
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withOpacity(isActive ? 0.8 : 0.4),
              width: 2,
            ),
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
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
  const _IconSquare({required this.icon, required this.size, required this.isHighlighted});

  final AppIconData icon;
  final double size;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final double radius = size * 0.225; // iPhone 标准圆角比例
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(6), // 减小内边距
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: isHighlighted ? Border.all(color: Colors.white.withOpacity(0.7), width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: Image.asset(
              icon.assetPath,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
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
  });

  final AppIconData icon;
  final bool isEditing;
  final double size;
  final VoidCallback onDelete;
  final VoidCallback onDragStart;
  final Function(DraggableDetails) onDragEnd;

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
          child: _IconSquare(icon: widget.icon, size: widget.size, isHighlighted: true),
        ),
        onDragStarted: widget.onDragStart,
        onDragEnd: widget.onDragEnd,
        childWhenDragging: const SizedBox.shrink(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _IconSquare(icon: widget.icon, size: widget.size, isHighlighted: false),
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
    );
  }
}
