import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PickedLocation {
  final String name;
  final double lat;
  final double lng;

  const PickedLocation({
    required this.name,
    required this.lat,
    required this.lng,
  });
}

class _LocationError implements Exception {
  final String message;

  const _LocationError(this.message);
}

/// Bottom sheet pemilih lokasi: cari nama tempat (OpenStreetMap Nominatim)
/// atau pakai lokasi saat ini. Mengembalikan [PickedLocation].
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  static const muted = Color(0xFF858585);
  static const separator = Color(0xFF292929);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  List<PickedLocation> _results = [];
  bool _searching = false;
  bool _locating = false;
  String? _error;

  Map<String, String> get _headers => {
        'Accept-Language': 'id',
        // Nominatim meminta User-Agent; browser (web) melarang mengubahnya.
        if (!kIsWeb) 'User-Agent': 'ThridsApp/1.0',
      };

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _shorten(String displayName) {
    return displayName
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .take(3)
        .join(', ');
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(value));
  }

  Future<void> _search(String query) async {
    final text = query.trim();
    final requestId = ++_requestId;

    if (text.length < 3) {
      setState(() {
        _results = [];
        _searching = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': text,
        'format': 'jsonv2',
        'limit': '8',
      });

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode != 200) {
        throw Exception('Nominatim ${response.statusCode}');
      }

      final list = jsonDecode(response.body) as List;
      final results = <PickedLocation>[];

      for (final raw in list) {
        final map = raw as Map<String, dynamic>;
        final lat = double.tryParse('${map['lat']}');
        final lng = double.tryParse('${map['lon']}');
        final name = map['display_name'] as String?;

        if (lat != null && lng != null && name != null) {
          results.add(
            PickedLocation(name: _shorten(name), lat: lat, lng: lng),
          );
        }
      }

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _searching = false;
        _error = 'Gagal mencari lokasi. Periksa koneksi internet.';
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;

    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        throw const _LocationError(
          'Layanan lokasi mati. Aktifkan lokasi/GPS lalu coba lagi.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationError(
          'Izin lokasi ditolak. Izinkan akses lokasi di pengaturan.',
        );
      }

      final position = await Geolocator.getCurrentPosition();
      var name = 'Lokasi saya';

      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'lat': position.latitude.toString(),
          'lon': position.longitude.toString(),
          'format': 'jsonv2',
          'zoom': '16',
        });

        final response = await http.get(uri, headers: _headers);

        if (response.statusCode == 200) {
          final map = jsonDecode(response.body) as Map<String, dynamic>;
          final displayName = map['display_name'] as String?;

          if (displayName != null && displayName.isNotEmpty) {
            name = _shorten(displayName);
          }
        }
      } catch (_) {
        // Nama tempat gagal dicari; tetap pakai "Lokasi saya".
      }

      if (!mounted) return;

      Navigator.pop(
        context,
        PickedLocation(
          name: name,
          lat: position.latitude,
          lng: position.longitude,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _locating = false;
        _error = error is _LocationError
            ? error.message
            : 'Gagal mengambil lokasi saat ini.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cari lokasi',
                  hintStyle: const TextStyle(color: muted),
                  prefixIcon: const Icon(Icons.search, color: muted),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            ListTile(
              onTap: _useCurrentLocation,
              leading: _locating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Colors.white),
              title: const Text(
                'Gunakan lokasi saya saat ini',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const Divider(height: 1, color: separator),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Ketik minimal 3 huruf untuk mencari tempat.',
          style: TextStyle(color: muted),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: separator),
      itemBuilder: (context, index) {
        final place = _results[index];

        return ListTile(
          onTap: () => Navigator.pop(context, place),
          leading: const Icon(Icons.location_on_outlined, color: muted),
          title: Text(
            place.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}
