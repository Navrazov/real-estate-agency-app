import 'package:flutter/material.dart';

/// Shimmer effect wrapper for skeleton loaders
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
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

/// A single skeleton block
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton for listing cards grid
class SkeletonListingsGrid extends StatelessWidget {
  const SkeletonListingsGrid({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: count,
        itemBuilder: (_, __) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          const AspectRatio(
            aspectRatio: 4 / 3,
            child: SkeletonBox(borderRadius: 0, height: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 60, height: 20),
                const SizedBox(height: 6),
                const SkeletonBox(height: 14),
                const SizedBox(height: 4),
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.25, height: 12),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    SkeletonBox(width: 50, height: 16),
                    SizedBox(width: 8),
                    SkeletonBox(width: 40, height: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for listing detail page
class SkeletonListingDetail extends StatelessWidget {
  const SkeletonListingDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            const AspectRatio(
              aspectRatio: 4 / 3,
              child: SkeletonBox(borderRadius: 0, height: double.infinity),
            ),
            // Thumbnails
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: List.generate(4, (_) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: const SkeletonBox(width: 60, height: 60, borderRadius: 8),
                )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Row(children: const [
                    SkeletonBox(width: 80, height: 24, borderRadius: 12),
                    SizedBox(width: 8),
                    SkeletonBox(width: 60, height: 24, borderRadius: 12),
                  ]),
                  const SizedBox(height: 12),
                  // Price
                  const SkeletonBox(width: 160, height: 28),
                  const SizedBox(height: 8),
                  // Title
                  const SkeletonBox(height: 20),
                  const SizedBox(height: 8),
                  // Address
                  const SkeletonBox(width: 220, height: 14),
                  const SizedBox(height: 16),
                  // Stats grid
                  Row(children: const [
                    Expanded(child: SkeletonBox(height: 64, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 64, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 64, borderRadius: 12)),
                  ]),
                  const SizedBox(height: 16),
                  // Description
                  const SkeletonBox(width: 100, height: 18),
                  const SizedBox(height: 8),
                  const SkeletonBox(height: 14),
                  const SizedBox(height: 4),
                  const SkeletonBox(height: 14),
                  const SizedBox(height: 4),
                  const SkeletonBox(width: 200, height: 14),
                  const SizedBox(height: 16),
                  // Button
                  const SkeletonBox(height: 48, borderRadius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for conversations list
class SkeletonConversationList extends StatelessWidget {
  const SkeletonConversationList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const SkeletonBox(width: 48, height: 48, borderRadius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonBox(width: 120, height: 16),
                        SkeletonBox(width: 40, height: 12),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const SkeletonBox(width: 200, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for chat messages
class SkeletonMessages extends StatelessWidget {
  const SkeletonMessages({super.key});

  @override
  Widget build(BuildContext context) {
    final widths = [0.6, 0.45, 0.7, 0.35, 0.55, 0.5, 0.65];
    final alignments = [false, true, false, false, true, true, false];
    final screenWidth = MediaQuery.of(context).size.width;

    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(widths.length, (i) {
            final isMine = alignments[i];
            return Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: screenWidth * widths[i],
                height: 36 + (i % 3) * 8.0,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isMine ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Skeleton for favorites list
class SkeletonFavoritesList extends StatelessWidget {
  const SkeletonFavoritesList({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              const SkeletonBox(width: 120, height: 120, borderRadius: 0),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 70, height: 22, borderRadius: 6),
                      SizedBox(height: 8),
                      SkeletonBox(height: 16),
                      SizedBox(height: 6),
                      SkeletonBox(width: 100, height: 20),
                      SizedBox(height: 4),
                      SkeletonBox(width: 150, height: 12),
                    ],
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

/// Skeleton for my listings
class SkeletonMyListings extends StatelessWidget {
  const SkeletonMyListings({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              const SkeletonBox(width: 100, height: 100, borderRadius: 0),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 60, height: 18, borderRadius: 6),
                      SizedBox(height: 6),
                      SkeletonBox(height: 16),
                      SizedBox(height: 6),
                      SkeletonBox(width: 110, height: 18),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          SkeletonBox(width: 60, height: 28, borderRadius: 6),
                          SizedBox(width: 8),
                          SkeletonBox(width: 80, height: 28, borderRadius: 6),
                        ],
                      ),
                    ],
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

/// Skeleton for user profile page
class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            const SkeletonBox(width: 80, height: 80, borderRadius: 40),
            const SizedBox(height: 12),
            // Name
            const SkeletonBox(width: 150, height: 22),
            const SizedBox(height: 6),
            // Role
            const SkeletonBox(width: 80, height: 14),
            const SizedBox(height: 16),
            // Info rows
            ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: const [
                  SkeletonBox(width: 20, height: 20, borderRadius: 4),
                  SizedBox(width: 12),
                  SkeletonBox(width: 180, height: 14),
                ],
              ),
            )),
            const SizedBox(height: 16),
            // Listings header
            const Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(width: 140, height: 18),
            ),
            const SizedBox(height: 12),
            // Listing cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 2,
              itemBuilder: (_, __) => const _SkeletonCard(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for notifications
class SkeletonNotifications extends StatelessWidget {
  const SkeletonNotifications({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 160, height: 12),
                    SizedBox(height: 4),
                    SkeletonBox(width: 80, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for edit listing page
class SkeletonEditListing extends StatelessWidget {
  const SkeletonEditListing({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            const SkeletonBox(width: 80, height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(height: 48, borderRadius: 12),
            const SizedBox(height: 16),
            // Description field
            const SkeletonBox(width: 80, height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(height: 100, borderRadius: 12),
            const SizedBox(height: 16),
            // Price field
            const SkeletonBox(width: 50, height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(height: 48, borderRadius: 12),
            const SizedBox(height: 16),
            // Dropdowns row
            Row(children: const [
              Expanded(child: SkeletonBox(height: 48, borderRadius: 12)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 48, borderRadius: 12)),
            ]),
            const SizedBox(height: 16),
            // Images
            const SkeletonBox(width: 100, height: 14),
            const SizedBox(height: 8),
            Row(children: List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: const SkeletonBox(width: 80, height: 80, borderRadius: 8),
            ))),
            const SizedBox(height: 24),
            // Button
            const SkeletonBox(height: 48, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}
