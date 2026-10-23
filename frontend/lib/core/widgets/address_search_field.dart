import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../constants/zones.dart';
import '../models/geocode_result.dart';
import '../network/google_maps_service.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';

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

/// Selector de ubicación completo con entrada de texto libre, GPS real del dispositivo,
/// sugerencias desplegables de barrios de Cartagena y opción de señalar en mapa.
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    required this.onLocationSelected,
    this.onLocationCleared,
    this.initialLocation,
    this.label = 'Escribe tu dirección o barrio',
    this.locateCurrentPosition,
    this.googleMapsService,
    this.toCampus,
    super.key,
  });

  final GoogleMapsService? googleMapsService;
  final ValueChanged<SelectedLocation> onLocationSelected;

  /// Se dispara cuando el texto deja de corresponder con el punto seleccionado.
  final VoidCallback? onLocationCleared;

  final SelectedLocation? initialLocation;
  final String label;

  /// `true` si el trayecto se dirige hacia la UTB; `false` si parte desde la UTB.
  /// Si se proporciona, muestra el contexto visual con la UTB fija en el extremo correspondiente.
  final bool? toCampus;

  @visibleForTesting
  final Future<SelectedLocation?> Function()? locateCurrentPosition;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  GoogleMapsService get _googleMaps =>
      widget.googleMapsService ?? GoogleMapsService.instance;

  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final MapController _mapController = MapController();

  List<GeocodeResult> _remoteSuggestions = const [];
  bool _isLoading = false;
  bool _isLocating = false;
  bool _showMap = false;
  bool _showDropdown = false;
  String? _errorMessage;
  LatLng? _pinnedPoint;
  String? _selectedAddress;
  bool _hasSelection = false;
  int _searchEpoch = 0;

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

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showDropdown = true);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    if (_pinnedPoint != null) {
      final text = _selectedAddress?.trim() ?? _queryController.text.trim();
      widget.onLocationSelected(
        SelectedLocation(
          lat: _pinnedPoint!.latitude,
          lng: _pinnedPoint!.longitude,
          addressText: text.isNotEmpty ? text : 'Cartagena',
        ),
      );
    }
  }

  void _selectZone(Zone zone) {
    final point = LatLng(zone.latitude, zone.longitude);
    setState(() {
      _pinnedPoint = point;
      _selectedAddress = '${zone.name}, Cartagena';
      _queryController.text = '${zone.name}, Cartagena';
      _hasSelection = true;
      _showDropdown = false;
      _errorMessage = null;
    });
    _focusNode.unfocus();
    _notifyChange();
    _moveMapIfReady(point, 15.0);
  }

  void _selectGeocodeResult(GeocodeResult result) {
    final point = LatLng(result.lat, result.lng);
    setState(() {
      _pinnedPoint = point;
      _selectedAddress = result.displayName;
      _queryController.text = result.displayName;
      _hasSelection = true;
      _showDropdown = false;
      _remoteSuggestions = const [];
      _errorMessage = null;
    });
    _focusNode.unfocus();
    _notifyChange();
    _moveMapIfReady(point, 15.0);
  }

  void _moveMapIfReady(LatLng point, double zoom) {
    if (!_showMap) return;
    try {
      _mapController.move(point, zoom);
    } on Object {
      // Controlador aún no montado en vista
    }
  }

  void _onQueryChanged(String query) {
    _searchEpoch++;
    final clean = query.trim();
    final selectedAddress = _selectedAddress?.trim();
    final invalidatesLocation = _hasSelection && selectedAddress != clean;

    setState(() {
      _showDropdown = true;
      _remoteSuggestions = const [];
      _errorMessage = null;
      if (invalidatesLocation) {
        _hasSelection = false;
        _selectedAddress = null;
      }
    });

    if (invalidatesLocation) {
      widget.onLocationCleared?.call();
    }
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

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
        _showDropdown = false;
        _isLocating = false;
      });

      _notifyChange();
      _moveMapIfReady(point, 15.0);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
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

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    // 1. Intento de geocodificación inversa exacta con Google Maps.
    try {
      final googleAddress = await _googleMaps.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (googleAddress != null && googleAddress.isNotEmpty) {
        return SelectedLocation(
          lat: position.latitude,
          lng: position.longitude,
          addressText: googleAddress,
        );
      }
    } catch (_) {}

    // 2. Si Google no responde, se usa el barrio más cercano del catálogo.
    Zone closestZone = Zones.neighborhoods.first;
    double minDistance = double.infinity;
    const distanceCalculator = Distance();

    for (final zone in Zones.neighborhoods) {
      final d = distanceCalculator.as(
        LengthUnit.Meter,
        LatLng(position.latitude, position.longitude),
        LatLng(zone.latitude, zone.longitude),
      );
      if (d < minDistance) {
        minDistance = d;
        closestZone = zone;
      }
    }

    return SelectedLocation(
      lat: position.latitude,
      lng: position.longitude,
      addressText: '${closestZone.name}, Cartagena',
    );
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.length < 2) return;
    final epoch = ++_searchEpoch;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showDropdown = true;
    });

    try {
      List<GeocodeResult> googleResults = const [];
      try {
        final suggestions = await _googleMaps.autocomplete(query);
        if (suggestions.isNotEmpty) {
          final detailsList = await Future.wait(
            suggestions
                .take(5)
                .map((s) => _googleMaps.getPlaceDetails(s.placeId)),
          );
          googleResults = [
            for (final d in detailsList)
              if (d != null)
                GeocodeResult(
                  lat: d.location.latitude,
                  lng: d.location.longitude,
                  displayName: d.formattedAddress,
                  source: 'google',
                ),
          ];
        }
      } catch (_) {}

      final results = googleResults;
      if (mounted && epoch == _searchEpoch) {
        setState(() {
          _isLoading = false;
          _remoteSuggestions = results;
          if (results.isNotEmpty) {
            final first = results.first;
            _pinnedPoint = LatLng(first.lat, first.lng);
            _selectedAddress = first.displayName;
            _hasSelection = true;
            _queryController.text = first.displayName;
          } else {
            final z = Zones.byName(query);
            if (z != null) {
              _pinnedPoint = LatLng(z.latitude, z.longitude);
              _selectedAddress = '${z.name}, Cartagena';
              _hasSelection = true;
            }
          }
        });
        if (results.isNotEmpty || _hasSelection) {
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

  List<Zone> _getFilteredZones() {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return Zones.neighborhoods;
    }
    final filtered = Zones.neighborhoods.where((zone) {
      return zone.name.toLowerCase().contains(query);
    }).toList();

    return filtered.isNotEmpty ? filtered : Zones.neighborhoods;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filteredZones = _getFilteredZones();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Contexto fijo si se parte desde la UTB
        if (widget.toCampus == false) ...[
          const _CampusFixedCard(
            label: 'Punto de partida (Fijo)',
            title: 'Universidad Tecnológica de Bolívar',
            subtitle: 'Campus Ternera',
            icon: Icons.school_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            '¿A dónde te diriges?',
            style: RoutbText.copy(
              13,
              color: palette.muted,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // 2. Contexto fijo si se va hacia la UTB (indicación previa)
        if (widget.toCampus == true) ...[
          Text(
            '¿De dónde sales?',
            style: RoutbText.copy(
              13,
              color: palette.muted,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // 3. Bloque de texto editable a mano con botón de búsqueda integrado
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _focusNode.hasFocus ? palette.brand : palette.line,
                    width: _focusNode.hasFocus ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_location_alt_outlined,
                      color: palette.brand,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        focusNode: _focusNode,
                        onChanged: _onQueryChanged,
                        onSubmitted: (_) {
                          _search();
                        },
                        style: RoutbText.copy(14, color: palette.ink),
                        decoration: InputDecoration(
                          hintText: widget.label,
                          hintStyle: RoutbText.copy(14, color: palette.muted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    if (_queryController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: palette.muted,
                        ),
                        onPressed: () {
                          _queryController.clear();
                          _onQueryChanged('');
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón de buscar
            Material(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _isLoading ? null : _search,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.line),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.brand,
                          ),
                        )
                      : Text(
                          'Buscar',
                          style: RoutbText.copy(
                            13,
                            color: palette.brand,
                            weight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 4. Botón "Usar mi ubicación" funcional con GPS real
        OutlinedButton.icon(
          onPressed: _isLocating ? null : _useMyLocation,
          icon: _isLocating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.brand,
                  ),
                )
              : Icon(Icons.my_location_rounded, size: 18, color: palette.brand),
          label: Text(
            _isLocating ? 'Obteniendo ubicación...' : 'Usar mi ubicación',
            style: RoutbText.copy(
              13,
              color: palette.brand,
              weight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: palette.brand.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        // Mensaje de error si falla el GPS
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _errorMessage!,
              style: RoutbText.copy(12, color: palette.rose),
            ),
          ),

        // 5. Lista desplegable de opciones de Cartagena o sugerencias remotas
        if (_showDropdown) ...[
          const SizedBox(height: 8),
          Material(
            color: palette.card,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.line),
              ),
              constraints: const BoxConstraints(maxHeight: 250),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    // Sugerencias remotas (si hubo búsqueda)
                    if (_remoteSuggestions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: Text(
                          'Resultados encontrados',
                          style: RoutbText.copy(
                            11,
                            color: palette.muted,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final item in _remoteSuggestions)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.location_pin,
                            color: palette.brand,
                            size: 20,
                          ),
                          title: Text(
                            item.displayName,
                            style: RoutbText.copy(
                              13,
                              color: palette.ink,
                              weight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectGeocodeResult(item),
                        ),
                      const Divider(height: 1),
                    ],

                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                      child: Text(
                        'Opciones en Cartagena',
                        style: RoutbText.copy(
                          11,
                          color: palette.muted,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final zone in filteredZones)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.location_on_outlined,
                          color: palette.brand,
                          size: 20,
                        ),
                        title: Text(
                          zone.name,
                          style: RoutbText.copy(
                            14,
                            color: palette.ink,
                            weight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Cartagena de Indias',
                          style: RoutbText.copy(11, color: palette.muted),
                        ),
                        trailing: Icon(
                          Icons.north_west_rounded,
                          size: 14,
                          color: palette.muted,
                        ),
                        onTap: () => _selectZone(zone),
                      ),

                    const Divider(height: 1),

                    // 6. Botón de señalar ubicación en el mapa al final de la lista
                    ListTile(
                      dense: true,
                      tileColor: palette.surface,
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: palette.brandSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          color: palette.brand,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Señalar ubicación en el mapa',
                        style: RoutbText.copy(
                          14,
                          color: palette.brand,
                          weight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Mueve el pin libremente para fijar el punto',
                        style: RoutbText.copy(11, color: palette.muted),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: palette.brand,
                      ),
                      onTap: () {
                        _focusNode.unfocus();
                        setState(() {
                          _showDropdown = false;
                          _showMap = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // 7. Acceso a mapa y visor interactivo
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () {
            _focusNode.unfocus();
            setState(() {
              _showDropdown = false;
              _showMap = !_showMap;
            });
          },
          icon: Icon(_showMap ? Icons.keyboard_arrow_up : Icons.map_outlined),
          label: Text(
            _showMap ? 'Ocultar mapa' : 'Ajustar ubicación en el mapa',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        if (_showMap) ...[
          const SizedBox(height: 8),
          Text(
            'Mueve el mapa para fijar el pin en el punto exacto:',
            style: RoutbText.copy(12, color: palette.muted),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _pinnedPoint ?? _defaultCenter,
                      initialZoom: 14.5,
                      onPositionChanged: (pos, hasGesture) {
                        if (hasGesture) {
                          final point = pos.center;
                          setState(() {
                            _pinnedPoint = point;
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
                        size: 40,
                        color: palette.brand,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: palette.brand,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () async {
                          if (_pinnedPoint != null) {
                            String? exactAddress;
                            try {
                              exactAddress = await _googleMaps.reverseGeocode(
                                _pinnedPoint!.latitude,
                                _pinnedPoint!.longitude,
                              );
                            } catch (_) {}

                            if (exactAddress != null &&
                                exactAddress.isNotEmpty) {
                              setState(() {
                                _selectedAddress = exactAddress;
                                _queryController.text = exactAddress!;
                                _showMap = false;
                              });
                              _notifyChange();
                              return;
                            }

                            // Resolver barrio más cercano al pin
                            Zone closest = Zones.neighborhoods.first;
                            double minD = double.infinity;
                            const dist = Distance();
                            for (final z in Zones.neighborhoods) {
                              final d = dist.as(
                                LengthUnit.Meter,
                                _pinnedPoint!,
                                LatLng(z.latitude, z.longitude),
                              );
                              if (d < minD) {
                                minD = d;
                                closest = z;
                              }
                            }
                            final label = '${closest.name}, Cartagena';
                            setState(() {
                              _selectedAddress = label;
                              _queryController.text = label;
                              _showMap = false;
                            });
                            _notifyChange();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            'Confirmar este punto',
                            style: RoutbText.copy(
                              12,
                              color: Colors.white,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // 8. Contexto fijo si se dirige hacia la UTB (Llegada fija)
        if (widget.toCampus == true) ...[
          const SizedBox(height: 14),
          const _CampusFixedCard(
            label: 'Destino final (Fijo)',
            title: 'Universidad Tecnológica de Bolívar',
            subtitle: 'Campus Ternera',
            icon: Icons.school_rounded,
          ),
        ],
      ],
    );
  }
}

/// Tarjeta limpia informativa para el extremo fijo de la UTB.
class _CampusFixedCard extends StatelessWidget {
  const _CampusFixedCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.brand.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.brand,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: RoutbText.copy(
                    11,
                    color: palette.brand,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  title,
                  style: RoutbText.copy(
                    13,
                    color: palette.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(subtitle, style: RoutbText.copy(11, color: palette.muted)),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded, size: 16, color: palette.brand),
        ],
      ),
    );
  }
}
