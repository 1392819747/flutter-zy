# Apple Icon Sort App 苹果风格图标排序应用

一个精美仿苹果iOS风格的图标排序管理应用，支持拖拽排序、Dock栏管理和编辑模式。

## ✨ 主要功能

### 🖱️ 拖拽排序
- **长按拖拽**: 长按任意图标开始拖拽模式
- **智能排序**: 拖拽时其他图标自动避让，实时调整位置
- **流畅动画**: 使用AnimatedPositioned实现丝滑的位置过渡

### 📱 Dock栏管理
- **固定Dock**: 底部Dock栏默认包含4个常用应用（Instagram、Twitter、WhatsApp、YouTube）
- **自由移动**: 可以将主界面的图标拖拽到Dock栏，也可以从Dock栏移除
- **优先显示**: Dock栏图标享受更高的视觉优先级

### ✏️ 编辑模式
- **进入编辑**: 长按任意图标进入编辑模式，图标开始左右摇摆
- **删除功能**: 编辑模式下图标左上角显示删除按钮，点击可移除图标
- **完成编辑**: 右上角显示"Done"按钮，点击退出编辑模式

### 🎨 视觉效果
- **苹果风格**: 采用苹果Human Interface Guidelines设计规范
- **精美渐变**: 深绿色到黑色的对角线渐变背景
- **立体阴影**: 每个图标都有精致的阴影效果
- **响应式布局**: 自动适配不同屏幕尺寸（2-4列布局）

## 🚀 快速开始

### 安装依赖
```bash
flutter pub get
```

### 运行应用
```bash
flutter run
```

### 构建应用
```bash
flutter build ios     # 构建iOS版本
flutter build android # 构建Android版本
```

## 📖 使用指南

### 基本操作
1. **查看图标**: 应用启动后显示所有应用图标网格
2. **拖拽排序**: 长按图标并拖拽到新位置
3. **Dock管理**: 将图标拖拽到底部Dock栏进行固定
4. **编辑模式**: 长按进入编辑模式，可以删除不需要的图标

### 高级功能
- **系统UI优化**: 编辑模式下自动隐藏状态栏和导航栏
- **触觉反馈**: 拖拽开始时提供震动反馈
- **状态保持**: 应用重启后保持当前图标布局

## 🏗️ 技术架构

### 核心组件
- `AppleIconSortApp`: 应用根组件
- `AppleIconSortPage`: 主页面状态管理
- `AppleIconTile`: 单个图标组件
- `AppleIconBody`: 图标主体显示组件
- `_AnimatedGridItem`: 网格动画容器

### 设计模式
- **状态管理**: 使用StatefulWidget管理应用状态
- **组件化**: 功能模块化，便于维护和扩展
- **响应式**: 基于MediaQuery的自适应布局

### 技术特性
- **Flutter 3.9.2**: 使用最新的Flutter SDK
- **Material 3**: 采用最新的设计语言
- **动画系统**: 使用AnimationController实现图标摇摆效果
- **拖拽系统**: 基于LongPressDraggable和DragTarget的完整拖拽解决方案

## 📦 包含的应用图标

应用预置了19个流行应用的图标：
- Amazon, Dropbox, Facebook, Gmail, GitHub
- Google, Drive, Instagram, LinkedIn, Messenger
- PayPal, Pinterest, Reddit, Skype, Spotify
- Telegram, Twitter, WhatsApp, YouTube

## 🎯 未来规划

### 计划中的功能
- [ ] 图标布局本地存储
- [ ] 自定义图标添加
- [ ] 应用分组和文件夹
- [ ] 搜索功能
- [ ] 主题切换
- [ ] 手势快捷操作

### 性能优化
- [ ] 图标懒加载
- [ ] 内存使用优化
- [ ] 启动速度优化

## 🛠️ 开发指南

### 代码结构
```
lib/
├── main.dart          # 应用入口和主逻辑
test/
├── widget_test.dart   # 组件测试
assets/
├── icons/            # 应用图标资源
```

### 添加新图标
1. 将PNG图标文件放入`assets/icons/`目录
2. 在`_defaultIcons`列表中添加新的`AppIconData`条目
3. 在`pubspec.yaml`中确保assets配置正确

### 自定义主题
修改`AppleIconSortApp`中的`theme`配置来自定义应用主题色彩。

## 🧪 测试

运行组件测试：
```bash
flutter test
```

当前测试验证：
- 应用能够正确构建图标网格
- AppleIconTile组件正常渲染

## 📱 兼容性

- **iOS**: 支持iOS 14.0+
- **Android**: 支持Android 6.0+
- **Web**: 支持现代浏览器
- **桌面**: 支持macOS、Windows、Linux

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目！

## 📄 许可证

本项目采用MIT许可证，详见LICENSE文件。

---

**开发者**: Flutter专家团队
**版本**: 1.0.0
**最后更新**: 2025年11月13日