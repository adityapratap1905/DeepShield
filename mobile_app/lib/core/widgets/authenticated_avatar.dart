import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../network/dio_client.dart';

/// Renders a protected DeepShield profile photo with an initials fallback.
class AuthenticatedAvatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  const AuthenticatedAvatar({
    super.key,
    required this.name,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
    this.imageUrl,
  });

  @override
  State<AuthenticatedAvatar> createState() => _AuthenticatedAvatarState();
}

class _AuthenticatedAvatarState extends State<AuthenticatedAvatar> {
  Future<Uint8List>? _photo;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _loadPhoto();
  }

  void _loadPhoto() {
    final path = widget.imageUrl;
    if (path == null ||
        !path.startsWith('/profiles/') ||
        !path.endsWith('/avatar')) {
      _photo = null;
      return;
    }
    _photo = _fetchPhoto(path);
  }

  Future<Uint8List> _fetchPhoto(String path) async {
    final response = await DioClient.instance.dio.get<List<int>>(
      '${ApiConstants.baseUrl}$path',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('The profile photo response was empty.');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    if (photo == null) return _fallback();
    return FutureBuilder<Uint8List>(
      future: photo,
      builder: (context, snapshot) => snapshot.hasData
          ? CircleAvatar(
              radius: widget.radius,
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.foregroundColor,
              backgroundImage: MemoryImage(snapshot.data!),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
        child: Text(
          widget.name.isEmpty ? 'U' : widget.name[0].toUpperCase(),
          style: TextStyle(fontSize: widget.radius * 0.78),
        ),
      );
}
