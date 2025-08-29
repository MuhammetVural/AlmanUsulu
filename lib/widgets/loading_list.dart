import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6, // kaç tane skeleton görünsün
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade700,
        child: const ListTile(
          leading: CircleAvatar(radius: 14, backgroundColor: Colors.white),
          title: SizedBox(height: 12, width: double.infinity, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white))),
          subtitle: SizedBox(height: 12, width: 150, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white))),
        ),
      ),
    );
  }
}