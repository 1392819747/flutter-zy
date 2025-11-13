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
  static const double _maxContentWidth = 760;

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

  int _columnCountForWidth(double width) {
    if (width >= 1100) {
      return 6;
    }
    if (width >= 900) {
      return 5;
    }
    if (width >= 600) {
      return 4;
    }
    if (width >= 360) {
      return 4;
    }
    return 3;
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
  }) {
    final List<Widget> widgets = <Widget>[];
    for (int index = 0; index < _icons.length; index++) {
      final AppIconData icon = _icons[index];
      final Offset offset = _slotOffset(
        slot: index,
        columns: columns,
        itemWidth: itemWidth,
        itemHeight: itemHeight,
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
  }) {
    final int row = slot ~/ columns;
    final int column = slot % columns;
    final double dx = column * (itemWidth + _gridSpacing);
    final double dy = row * (itemHeight + _runSpacing);
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
    final double safeTop = mediaQuery.padding.top;
    final double safeBottom = mediaQuery.padding.bottom;
    final double doneTop = _isEditing ? 14 : safeTop + 14;
    final double contentTopPadding = _isEditing ? 72 : safeTop + 44;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    contentTopPadding,
                    20,
                    safeBottom + 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double width = constraints.maxWidth;
                            final int columns = _columnCountForWidth(width);
                            final double itemWidth =
                                (width - _gridSpacing * (columns - 1)) / columns;
                            final double itemHeight = itemWidth + 52;
                            final int slotCount =
                                _icons.length + (_draggingIcon != null ? 1 : 0);
                            final int rows = slotCount == 0
                                ? 0
                                : ((slotCount - 1) ~/ columns) + 1;
                            final double gridHeight = rows == 0
                                ? itemHeight
                                : rows * itemHeight +
                                    math.max(0, rows - 1) * _runSpacing;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: SizedBox(
                                      height: gridHeight,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: _buildPositionedIcons(
                                          columns: columns,
                                          itemWidth: itemWidth,
                                          itemHeight: itemHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const _Dock(),
                                const SizedBox(height: 16),
                                const _HomeIndicator(),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              top: doneTop,
              right: 20,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isEditing
                    ? _DoneButton(onPressed: _handleDonePressed)
                    : const SizedBox.shrink(),
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
  const _DoneButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('done_button'),
      style: TextButton.styleFrom(
        backgroundColor: const Color.fromRGBO(180, 180, 180, 0.6),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 134,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _DockIcon(
                  icon: CupertinoIcons.phone_fill,
                  label: 'Phone',
                  colors: [Color(0xFF39D87E), Color(0xFF28B865)],
                ),
                _DockIcon(
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  label: 'Messages',
                  colors: [Color(0xFF7CD1FF), Color(0xFF3AA8F2)],
                ),
                _DockIcon(
                  icon: CupertinoIcons.compass_fill,
                  label: 'Safari',
                  colors: [Color(0xFF66B8FF), Color(0xFF0A7AFF)],
                ),
                _DockIcon(
                  icon: CupertinoIcons.music_note_2,
                  label: 'Music',
                  colors: [Color(0xFFFF7A7A), Color(0xFFFA2C55)],
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
  });

  final IconData icon;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 34,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
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
