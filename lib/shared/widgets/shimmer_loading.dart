// lib/shared/widgets/shimmer_loading.dart
//
// Reusable shimmer skeleton loading system.
// Pure Flutter — no external packages needed.
//
// Usage:
//   loading: () => SkeletonLoaders.cardList(),
//   loading: () => SkeletonLoaders.dashboard(),
//   etc.

import 'package:flutter/material.dart';

// =============================================================================
// CORE: Shimmer animation wrapper
// =============================================================================

/// Wraps any child with a sweeping shimmer gradient animation.
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// =============================================================================
// BUILDING BLOCKS: ShimmerBox and ShimmerCircle
// =============================================================================

/// A rectangular shimmer placeholder.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circular shimmer placeholder (for avatars).
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE0E0E0),
        shape: BoxShape.circle,
      ),
    );
  }
}

// =============================================================================
// PRESETS: Drop-in skeleton loaders for every screen type
// =============================================================================

class SkeletonLoaders {
  SkeletonLoaders._();

  // ---------------------------------------------------------------------------
  // LIST TILE: Leave requests, classwork, timetable, attendance sections
  // ---------------------------------------------------------------------------
  static Widget listTile({int count = 6}) {
    return ShimmerEffect(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: const Row(
              children: [
                ShimmerCircle(size: 44),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 160, height: 14),
                      SizedBox(height: 8),
                      ShimmerBox(width: 120, height: 11),
                    ],
                  ),
                ),
                ShimmerBox(width: 60, height: 24, radius: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARD LIST: Homework, staff list, front office, transport
  // ---------------------------------------------------------------------------
  static Widget cardList({int count = 5}) {
    return ShimmerEffect(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerBox(width: 44, height: 44, radius: 12),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 180, height: 16),
                          SizedBox(height: 8),
                          ShimmerBox(width: 120, height: 12),
                        ],
                      ),
                    ),
                    const ShimmerBox(width: 56, height: 22, radius: 8),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 100, height: 12),
                    ShimmerBox(width: 90, height: 12),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NOTICE CARD: Notice board (shimmer version)
  // ---------------------------------------------------------------------------
  static Widget noticeCard({int count = 5}) {
    return ShimmerEffect(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.grey.shade50,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 80, height: 24, radius: 12),
                      ShimmerBox(width: 100, height: 14),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 250, height: 18),
                      SizedBox(height: 12),
                      ShimmerBox(width: double.infinity, height: 13),
                      SizedBox(height: 6),
                      ShimmerBox(width: double.infinity, height: 13),
                      SizedBox(height: 6),
                      ShimmerBox(width: 150, height: 13),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NOTICE CARD (SLIVER): For use inside SliverList
  // ---------------------------------------------------------------------------
  static Widget noticeCardSliver({int count = 5}) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return ShimmerEffect(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.grey.shade50,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 80, height: 24, radius: 12),
                        ShimmerBox(width: 100, height: 14),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 250, height: 18),
                        SizedBox(height: 12),
                        ShimmerBox(width: double.infinity, height: 13),
                        SizedBox(height: 6),
                        ShimmerBox(width: double.infinity, height: 13),
                        SizedBox(height: 6),
                        ShimmerBox(width: 150, height: 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: count,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD: Hero header + metrics + quick links grid
  // ---------------------------------------------------------------------------
  static Widget dashboard() {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // Hero header
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFE0E0E0),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 16),
                  SizedBox(height: 8),
                  ShimmerBox(width: 200, height: 24),
                  SizedBox(height: 6),
                  ShimmerBox(width: 100, height: 12),
                ],
              ),
            ),
            // Metric cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Quick links grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ShimmerBox(width: 50, height: 10, radius: 4),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILE PAGE: Avatar header + info cards
  // ---------------------------------------------------------------------------
  static Widget profilePage() {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 16, bottom: 36, left: 20, right: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  const ShimmerCircle(size: 80),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: 150, height: 20),
                      const SizedBox(height: 8),
                      ShimmerBox(width: 100, height: 14, radius: 4),
                      const SizedBox(height: 10),
                      ShimmerBox(width: 70, height: 22, radius: 12),
                    ],
                  ),
                ],
              ),
            ),
            // Info cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(3, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ShimmerBox(width: 36, height: 36, radius: 10),
                            const SizedBox(width: 12),
                            ShimmerBox(width: 140, height: 16, radius: 4),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(4, (j) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ShimmerBox(width: 100, height: 12),
                                ShimmerBox(width: 130, height: 12),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DETAIL PAGE: Header + content blocks
  // ---------------------------------------------------------------------------
  static Widget detailPage() {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 250, height: 22),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      ShimmerBox(width: 80, height: 24, radius: 12),
                      SizedBox(width: 8),
                      ShimmerBox(width: 100, height: 24, radius: 12),
                    ],
                  ),
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 100, height: 14),
                      ShimmerBox(width: 120, height: 14),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 80, height: 14),
                      ShimmerBox(width: 140, height: 14),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Content section
            const ShimmerBox(width: 120, height: 18),
            const SizedBox(height: 12),
            const ShimmerBox(width: double.infinity, height: 14),
            const SizedBox(height: 6),
            const ShimmerBox(width: double.infinity, height: 14),
            const SizedBox(height: 6),
            const ShimmerBox(width: double.infinity, height: 14),
            const SizedBox(height: 6),
            const ShimmerBox(width: 200, height: 14),
            const SizedBox(height: 24),
            // Second section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(4, (i) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 100, height: 13),
                        ShimmerBox(width: 130, height: 13),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODULE DASHBOARD GRID: Academics, fees, inventory, etc.
  // ---------------------------------------------------------------------------
  static Widget moduleDashboard() {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary stat cards row
            Row(
              children: List.generate(2, (i) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 0 ? 8 : 0, left: i == 1 ? 8 : 0),
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShimmerBox(width: 60, height: 10),
                        SizedBox(height: 8),
                        ShimmerBox(width: 80, height: 18),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(2, (i) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 0 ? 8 : 0, left: i == 1 ? 8 : 0),
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShimmerBox(width: 60, height: 10),
                        SizedBox(height: 8),
                        ShimmerBox(width: 80, height: 18),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // Section title
            const ShimmerBox(width: 150, height: 16),
            const SizedBox(height: 16),
            // List items
            ...List.generate(5, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: const Row(
                  children: [
                    ShimmerCircle(size: 40),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 180, height: 14),
                          SizedBox(height: 6),
                          ShimmerBox(width: 120, height: 11),
                        ],
                      ),
                    ),
                    ShimmerBox(width: 50, height: 14),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TABLE VIEW: Audit trail, marks entry, attendance reports
  // ---------------------------------------------------------------------------
  static Widget tableView() {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters row
            const Row(
              children: [
                Expanded(child: ShimmerBox(width: double.infinity, height: 44, radius: 12)),
                SizedBox(width: 12),
                ShimmerBox(width: 100, height: 44, radius: 12),
              ],
            ),
            const SizedBox(height: 20),
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: ShimmerBox(width: 60, height: 12)),
                  SizedBox(width: 12),
                  Expanded(flex: 3, child: ShimmerBox(width: 100, height: 12)),
                  SizedBox(width: 12),
                  Expanded(flex: 2, child: ShimmerBox(width: 60, height: 12)),
                ],
              ),
            ),
            // Table rows
            ...List.generate(8, (i) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    const Expanded(flex: 2, child: ShimmerBox(width: 50, height: 12)),
                    const SizedBox(width: 12),
                    const Expanded(flex: 3, child: ShimmerBox(width: 80, height: 12)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: ShimmerBox(width: 40, height: 12, radius: 4)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORM PAGE: Create homework, apply leave, create notice
  // ---------------------------------------------------------------------------
  static Widget formPage() {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(5, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 80 + (i * 10).toDouble(), height: 12),
                    const SizedBox(height: 8),
                    const ShimmerBox(width: double.infinity, height: 48, radius: 12),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            const ShimmerBox(width: double.infinity, height: 50, radius: 12),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GRID CARDS: Timetable cells, section selection
  // ---------------------------------------------------------------------------
  static Widget gridCards({int count = 6, int crossAxisCount = 2}) {
    return ShimmerEffect(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBox(width: 36, height: 36, radius: 10),
                  SizedBox(height: 12),
                  ShimmerBox(width: 100, height: 14),
                  SizedBox(height: 6),
                  ShimmerBox(width: 70, height: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMMUNICATION LOG: Message-style list
  // ---------------------------------------------------------------------------
  static Widget communicationLog({int count = 6}) {
    return ShimmerEffect(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 140, height: 14),
                    ShimmerBox(width: 70, height: 10),
                  ],
                ),
                const SizedBox(height: 10),
                const ShimmerBox(width: double.infinity, height: 12),
                const SizedBox(height: 6),
                ShimmerBox(width: 200, height: 12, radius: 4),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ShimmerBox(width: 60, height: 20, radius: 10),
                    const SizedBox(width: 8),
                    ShimmerBox(width: 50, height: 20, radius: 10),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ATTENDANCE LIST: Student list with checkmarks
  // ---------------------------------------------------------------------------
  static Widget attendanceList({int count = 10}) {
    return ShimmerEffect(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                const ShimmerCircle(size: 40),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 10),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ShimmerBox(width: 32, height: 32, radius: 8),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
