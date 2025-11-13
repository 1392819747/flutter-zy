import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

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
  static const double _gridSpacing = 26;
  static const double _runSpacing = 32;
  static const double _iconTileSize = 72;
  static const double _designWidth = 390;
  static const double _designHeight = 844;
  static const double _designSafeTop = 47;
  static const double _designSafeBottom = 34;

  final List<AppIconData> _icons = List.of(_defaultIcons);
  bool _isEditing = false;
  AppIconData? _draggingIcon;
  int? _dragStartIndex;
  int? _hoverSlot;

  @override
  void initState() {
    super.initState();
    _scheduleSystemUiUpdate();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _handleDragStart(int index) {
    final AppIconData icon = _icons[index];
    HapticFeedback.heavyImpact();
    setState(() {
      _isEditing = true;
      _draggingIcon = icon;
      _dragStartIndex = index;
      _hoverSlot = index;
    });
    _scheduleSystemUiUpdate();
  }

  void _handleDragEnd({required bool wasAccepted}) {
    setState(() {
      if (!wasAccepted && _draggingIcon != null && _dragStartIndex != null) {
        final AppIconData icon = _draggingIcon!;
        final int currentIndex = _icons.indexOf(icon);
        if (currentIndex != -1) {
          final AppIconData item = _icons.removeAt(currentIndex);
          final int restoredIndex = math.max(0, math.min(_dragStartIndex!, _icons.length));
          _icons.insert(restoredIndex, item);
        }
      }
      _draggingIcon = null;
      _dragStartIndex = null;
      _hoverSlot = null;
    });
    _scheduleSystemUiUpdate();
  }

  void _handleDelete(AppIconData icon) {
    setState(() {
      _icons.remove(icon);
      if (_icons.isEmpty) {
        _isEditing = false;
      }
      if (identical(_draggingIcon, icon)) {
        _draggingIcon = null;
        _hoverSlot = null;
        _dragStartIndex = null;
      }
    });
    _scheduleSystemUiUpdate();
  }

  void _handleDonePressed() {
    setState(() {
      _isEditing = false;
      _draggingIcon = null;
      _hoverSlot = null;
      _dragStartIndex = null;
    });
    _scheduleSystemUiUpdate();
  }

  void _scheduleSystemUiUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: _isEditing
            ? const [SystemUiOverlay.bottom]
            : SystemUiOverlay.values,
      );
    });
  }

  int _columnCountForWidth(
    double width,
    double tileSize,
    double spacing,
  ) {
    if (width <= 0) {
      return 1;
    }
    final double totalCellWidth = tileSize + spacing;
    final int estimate =
        math.max(1, ((width + spacing) / totalCellWidth).floor());
    return estimate.clamp(2, 6);
  }

  void _updateDragPosition(AppIconData icon, int slot) {
    final int currentIndex = _icons.indexOf(icon);
    if (currentIndex == -1) {
      return;
    }

    int desiredIndex = slot;
    if (currentIndex < slot) {
      desiredIndex -= 1;
    }
    if (_icons.isEmpty) {
      desiredIndex = 0;
    } else {
      desiredIndex = math.max(0, math.min(desiredIndex, _icons.length - 1));
    }

    if (desiredIndex == currentIndex) {
      if (_hoverSlot != slot) {
        setState(() {
          _hoverSlot = slot;
        });
      }
      return;
    }

    setState(() {
      final AppIconData item = _icons.removeAt(currentIndex);
      int insertIndex = slot;
      if (currentIndex < slot) {
        insertIndex -= 1;
      }
      insertIndex = math.max(0, math.min(insertIndex, _icons.length));
      _icons.insert(insertIndex, item);
      _hoverSlot = slot;
    });
  }

  List<Widget> _buildPositionedIcons({
    required int columns,
    required double itemWidth,
    required double itemHeight,
    required double gridSpacing,
    required double runSpacing,
    required double horizontalInset,
  }) {
    final List<Widget> widgets = <Widget>[];
    for (int index = 0; index < _icons.length; index++) {
      final AppIconData icon = _icons[index];
      final Offset offset = _slotOffset(
        slot: index,
        columns: columns,
        itemWidth: itemWidth,
        itemHeight: itemHeight,
        gridSpacing: gridSpacing,
        runSpacing: runSpacing,
        horizontalInset: horizontalInset,
      );
      widgets.add(
        AnimatedPositioned(
          key: ValueKey(icon.label),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          left: offset.dx,
          top: offset.dy,
          width: itemWidth,
          height: itemHeight,
          child: _buildDraggableIcon(
            index: index,
            itemWidth: itemWidth,
            itemHeight: itemHeight,
          ),
        ),
      );
    }

    if (_draggingIcon != null) {
      final Offset offset = _slotOffset(
        slot: _icons.length,
        columns: columns,
        itemWidth: itemWidth,
        itemHeight: itemHeight,
        gridSpacing: gridSpacing,
        runSpacing: runSpacing,
        horizontalInset: horizontalInset,
      );
      widgets.add(
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          left: offset.dx,
          top: offset.dy,
          width: itemWidth,
          height: itemHeight,
          child: _buildTrailingDropTarget(
            itemWidth: itemWidth,
            itemHeight: itemHeight,
          ),
        ),
      );
    }

    return widgets;
  }

  Offset _slotOffset({
    required int slot,
    required int columns,
    required double itemWidth,
    required double itemHeight,
    required double gridSpacing,
    required double runSpacing,
    required double horizontalInset,
  }) {
    final int row = slot ~/ columns;
    final int column = slot % columns;
    final double dx = horizontalInset + column * (itemWidth + gridSpacing);
    final double dy = row * (itemHeight + runSpacing);
    return Offset(dx, dy);
  }

  Widget _buildDraggableIcon({
    required int index,
    required double itemWidth,
    required double itemHeight,
  }) {
    final AppIconData icon = _icons[index];
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
        return SizedBox(
          height: itemHeight,
          child: LongPressDraggable<AppIconData>(
            data: icon,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _DragFeedback(icon: icon, size: itemWidth),
            onDragStarted: () => _handleDragStart(index),
            onDragEnd: (details) => _handleDragEnd(wasAccepted: details.wasAccepted),
            childWhenDragging: _DropPlaceholder(
              size: itemWidth,
              height: itemHeight,
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
          ),
        );
      },
    );
  }

  Widget _buildTrailingDropTarget({
    required double itemWidth,
    required double itemHeight,
  }) {
    final bool isActive = _hoverSlot == _icons.length && _draggingIcon != null;
    return SizedBox(
      width: itemWidth,
      height: itemHeight,
      child: DragTarget<AppIconData>(
        onWillAccept: (data) => data != null,
        onMove: (details) {
          if (details.data != null) {
            _updateDragPosition(details.data, _icons.length);
          }
        },
        onLeave: (_) {
          if (_hoverSlot == _icons.length && _draggingIcon != null) {
            setState(() {
              _hoverSlot = null;
            });
          }
        },
        onAccept: (_) {
          setState(() {
            _hoverSlot = _icons.length;
          });
        },
        builder: (context, candidateData, rejectedData) {
          final bool shouldShow = _draggingIcon != null || candidateData.isNotEmpty;
          return _DropPlaceholder(
            size: itemWidth,
            height: itemHeight,
            isActive: isActive || candidateData.isNotEmpty,
            isVisible: shouldShow,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double widthScale = constraints.maxWidth / _designWidth;
          final double heightScale = constraints.maxHeight / _designHeight;
          final double scale = math.min(1.0, math.min(widthScale, heightScale));
          final double phoneWidth = _designWidth * scale;
          final double phoneHeight = _designHeight * scale;
          final double safeTop = _designSafeTop * scale;
          final double safeBottom = _designSafeBottom * scale;

          return Center(
            child: SizedBox(
              width: phoneWidth,
              height: phoneHeight,
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  size: Size(phoneWidth, phoneHeight),
                  padding: EdgeInsets.only(
                    top: safeTop,
                    bottom: safeBottom,
                  ),
                ),
                child: _buildHomeSurface(
                  safeTop: safeTop,
                  safeBottom: safeBottom,
                  scale: scale,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeSurface({
    required double safeTop,
    required double safeBottom,
    required double scale,
  }) {
    final double horizontalPadding = 12 * scale;
    final double gridSpacing = _gridSpacing * scale;
    final double runSpacing = _runSpacing * scale;
    final double tileSize = _iconTileSize * scale;
    final double labelHeight = 48 * scale;
    final double contentTopPadding =
        _isEditing ? 68 * scale : safeTop + 36 * scale;
    final double contentBottomPadding = safeBottom + 24 * scale;
    final double doneTop = _isEditing ? 14 * scale : safeTop + 14 * scale;
    final double scrollPadding = 20 * scale;
    final double dockSpacing = 14 * scale;
    final double indicatorSpacing = 8 * scale;

    return Container(
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
        clipBehavior: Clip.none,
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
          AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              contentTopPadding,
              horizontalPadding,
              contentBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double availableWidth = constraints.maxWidth;
                      final int columns = _columnCountForWidth(
                        availableWidth,
                        tileSize,
                        gridSpacing,
                      );
                      final double itemWidth = math.min(
                        tileSize,
                        (availableWidth - gridSpacing * (columns - 1)) / columns,
                      );
                      final double itemHeight = itemWidth + labelHeight;
                      final int slotCount =
                          _icons.length + (_draggingIcon != null ? 1 : 0);
                      final int rows = slotCount == 0
                          ? 0
                          : ((slotCount - 1) ~/ columns) + 1;
                      final double gridHeight = rows == 0
                          ? itemHeight
                          : rows * itemHeight +
                              math.max(0, rows - 1) * runSpacing;
                      final double gridWidth = columns * itemWidth +
                          math.max(0, columns - 1) * gridSpacing;
                      final double horizontalInset =
                          math.max(0, (availableWidth - gridWidth) / 2);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(bottom: scrollPadding),
                              child: SizedBox(
                                height: gridHeight,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: _buildPositionedIcons(
                                    columns: columns,
                                    itemWidth: itemWidth,
                                    itemHeight: itemHeight,
                                    gridSpacing: gridSpacing,
                                    runSpacing: runSpacing,
                                    horizontalInset: horizontalInset,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: dockSpacing),
                          _Dock(scale: scale),
                          SizedBox(height: indicatorSpacing),
                          _HomeIndicator(scale: scale),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_isEditing,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isEditing ? 1 : 0,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: 20 * scale,
                    top: doneTop,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: _DoneButton(
                      onPressed: _handleDonePressed,
                      scale: scale,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final double radius = size * 0.3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 12 *
                (size / _AppleIconSortPageState._iconTileSize)
                    .clamp(0.8, 1.0),
            fontWeight: FontWeight.w600,
            shadows: const [
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
    required this.height,
    required this.isActive,
    required this.isVisible,
  });

  final double size;
  final double height;
  final bool isActive;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final double radius = size * 0.3;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isActive ? 1 : 0.75,
      child: SizedBox(
        height: height,
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
  const _DoneButton({required this.onPressed, required this.scale});

  final VoidCallback onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: 18 * scale,
      vertical: 10 * scale,
    );
    final TextStyle textStyle = TextStyle(
      fontSize: 16 * scale,
      fontWeight: FontWeight.w700,
    );

    return TextButton(
      key: const ValueKey('done_button'),
      style: TextButton.styleFrom(
        backgroundColor: const Color.fromRGBO(180, 180, 180, 0.6),
        foregroundColor: Colors.black,
        padding: padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: textStyle,
      ),
      onPressed: onPressed,
      child: const Text('Done'),
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

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 134 * scale,
        height: 5 * scale,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(3 * scale),
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final double radius = 32 * scale;
    final double horizontalPadding = 18 * scale;
    final double verticalPadding = 12 * scale;
    final double blurSigma = 24 * scale;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _DockIcon(
                  scale: scale,
                  icon: CupertinoIcons.phone_fill,
                  label: 'Phone',
                  colors: const [Color(0xFF39D87E), Color(0xFF28B865)],
                ),
                _DockIcon(
                  scale: scale,
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  label: 'Messages',
                  colors: const [Color(0xFF7CD1FF), Color(0xFF3AA8F2)],
                ),
                _DockIcon(
                  scale: scale,
                  icon: CupertinoIcons.compass_fill,
                  label: 'Safari',
                  colors: const [Color(0xFF66B8FF), Color(0xFF0A7AFF)],
                ),
                _DockIcon(
                  scale: scale,
                  icon: CupertinoIcons.music_note_2,
                  label: 'Music',
                  colors: const [Color(0xFFFF7A7A), Color(0xFFFA2C55)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.icon,
    required this.label,
    required this.colors,
    required this.scale,
  });

  final IconData icon;
  final String label;
  final List<Color> colors;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double size = 66 * scale;
    final double iconSize = 30 * scale;
    final double radius = 20 * scale;
    final double spacing = 6 * scale;
    final double labelFontSize = math.max(9, 12 * scale);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18 * scale,
                offset: Offset(0, 12 * scale),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: Colors.white,
          ),
        ),
        SizedBox(height: spacing),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(
                color: Colors.black45,
                offset: Offset(0, 1),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const List<AppIconData> _defaultIcons = [
  AppIconData(assetPath: 'assets/icons/amazon.png', label: 'Amazon'),
  AppIconData(assetPath: 'assets/icons/dropbox.png', label: 'Dropbox'),
  AppIconData(assetPath: 'assets/icons/facebook.png', label: 'Facebook'),
  AppIconData(assetPath: 'assets/icons/gmail.png', label: 'Gmail'),
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
];
