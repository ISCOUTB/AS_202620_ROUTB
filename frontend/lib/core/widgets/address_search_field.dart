import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/routb_palette.dart';
import 'routb_button.dart';
import 'routb_field.dart';
import '../../features/trips/data/geocode_repository.dart';

/// Resultado seleccionado de un punto con dirección y coordenada.
class SelectedLocation {
  const SelectedLocation({
    required this.lat,
    required this.lng,
    required this.addressText,
  });

  final double lat;
  final double lng;
  final String addressText;
}

/// Campo de búsqueda de dirección con autocompletado y pin arrastrable sobre mapa.
///
/// Permite al conductor o pasajero buscar una dirección mediante geocodificación
/// (Photon / Nominatim) y refinar la ubicación exacta arrastrando el marcador
/// sobre el mapa OSM, solventando imprecisiones de numeración en Cartagena.
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    required this.geocodeRepository,
    required this.onLocationSelected,
    this.onLocationCleared,
    this.initialLocation,
    this.label = 'Dirección o punto exacto',
    this.locateCurrentPosition,
    super.key,
  });

  final GeocodeRepository geocodeRepository;
  final ValueChanged<SelectedLocation> onLocationSelected;

  /// Se dispara cuando el texto deja de corresponder con el punto seleccionado.
  final VoidCallback? onLocationCleared;

  final SelectedLocation? initialLocation;
  final String label;

  @visibleForTesting
  final Future<SelectedLocation?> Function()? locateCurrentPosition;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final TextEditingController _queryController = TextEditingController();
  final MapController _mapController = MapController();

  List<GeocodeResult> _suggestions = const [];
  bool _isLoading = false;
  bool _showMap = false;
  String? _errorMessage;
  LatLng? _pinnedPoint;
  String? _selectedAddress;
  bool _hasSelection = false;
  int _searchEpoch = 0;

  // Centro por defecto: Cartagena / UTB
  static const LatLng _defaultCenter = LatLng(10.371078, -75.466261);

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _pinnedPoint = LatLng(
        widget.initialLocation!.lat,
        widget.initialLocation!.lng,
      );
      _selectedAddress = widget.initialLocation!.addressText;
      _queryController.text = _selectedAddress!;
      _hasSelection = true;
    } else {
      _pinnedPoint = _defaultCenter;
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.length < 2) return;
    final epoch = ++_searchEpoch;

    setState(() {
      _isLoading = true;
      _suggestions = const [];
      _errorMessage = null;
    });

    try {
      final results = await widget.geocodeRepository.search(query);
      if (mounted && epoch == _searchEpoch) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
          if (results.isNotEmpty) {
            final first = results.first;
            _pinnedPoint = LatLng(first.lat, first.lng);
            _selectedAddress = first.displayName;
            _hasSelection = true;
          }
        });
        if (results.isNotEmpty) {
          _moveMapIfReady(_pinnedPoint!, 15.0);
          _notifyChange();
        }
      }
    } on Exception catch (error) {
      if (mounted && epoch == _searchEpoch) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  void _selectSuggestion(GeocodeResult result) {
    final point = LatLng(result.lat, result.lng);
    setState(() {
      _pinnedPoint = point;
      _selectedAddress = result.displayName;
      _hasSelection = true;
      _queryController.text = result.displayName;
      _suggestions = const [];
    });
    _notifyChange();
    _moveMapIfReady(point, 15.0);
  }

  void _moveMapIfReady(LatLng point, double zoom) {
    if (!_showMap) return;
    try {
      _mapController.move(point, zoom);
    } on Object {
      // El controlador aún no está vinculado a un FlutterMap montado.
    }
  }

  void _notifyChange() {
    if (_pinnedPoint != null) {
      widget.onLocationSelected(
        SelectedLocation(
          lat: _pinnedPoint!.latitude,
          lng: _pinnedPoint!.longitude,
          addressText: _selectedAddress ?? _queryController.text.trim(),
        ),
      );
    }
  }

  void _onQueryChanged(String query) {
    // Invalida resultados de una búsqueda anterior: no se deben poder elegir
    // sugerencias que ya no corresponden al texto visible.
    _searchEpoch++;
    final selectedAddress = _selectedAddress?.trim();
    final invalidatesLocation =
        _hasSelection && selectedAddress != query.trim();

    setState(() {
      _suggestions = const [];
      _errorMessage = null;
      _isLoading = false;
      if (invalidatesLocation) {
        _hasSelection = false;
        _selectedAddress = null;
      }
    });

    if (invalidatesLocation) widget.onLocationCleared?.call();
  }

  Future<void> _useMyLocation() async {
    setState(() => _errorMessage = null);
    try {
      final selected = widget.locateCurrentPosition == null
          ? await _locateCurrentPosition()
          : await widget.locateCurrentPosition!();
      if (selected == null || !mounted) return;
      final point = LatLng(selected.lat, selected.lng);
      setState(() {
        _pinnedPoint = point;
        _selectedAddress = selected.addressText;
        _hasSelection = true;
        _queryController.text = selected.addressText;
      });
      _notifyChange();
      _moveMapIfReady(point, 15.0);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo obtener tu ubicación. Puedes ajustar el pin manualmente.';
      });
    }
  }

  Future<SelectedLocation?> _locateCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException('Permiso de ubicación denegado');
    }
    final position = await Geolocator.getCurrentPosition();
    return SelectedLocation(
      lat: position.latitude,
      lng: position.longitude,
      addressText: 'Mi ubicación actual',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: RoutbField(
                controller: _queryController,
                hint: widget.label,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: RoutbButton(
                  label: _isLoading ? '...' : 'Buscar',
                  onPressed: _isLoading ? null : _search,
                ),
              ),
            ),
          ],
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            constraints: const BoxConstraints(maxHeight: 180),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: palette.line),
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_pin,
                      color: palette.brand,
                      size: 20,
                    ),
                    title: Text(
                      item.displayName,
                      style: textTheme.bodySmall?.copyWith(color: palette.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectSuggestion(item),
                  );
                },
              ),
            ),
          ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _errorMessage!,
              style: textTheme.bodySmall?.copyWith(color: palette.rose),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _useMyLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('Usar mi ubicación'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showMap = !_showMap),
          icon: Icon(_showMap ? Icons.keyboard_arrow_up : Icons.map_outlined),
          label: Text(
            _showMap ? 'Ocultar mapa' : 'Ajustar ubicación en el mapa',
          ),
        ),
        if (_showMap) ...[
          const SizedBox(height: 8),
          Text(
            'Mueve el mapa para dejar el marcador en el punto exacto:',
            style: textTheme.labelMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _pinnedPoint ?? _defaultCenter,
                      initialZoom: 14.5,
                      onPositionChanged: (pos, hasGesture) {
                        if (hasGesture) {
                          setState(() {
                            _pinnedPoint = pos.center;
                            _hasSelection = true;
                          });
                          _notifyChange();
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'co.edu.utb.routb',
                      ),
                    ],
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Icon(
                        Icons.location_on,
                        size: 38,
                        color: palette.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
