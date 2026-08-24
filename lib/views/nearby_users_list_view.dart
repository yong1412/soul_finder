import 'package:flutter/material.dart';

class MapRadarView extends StatefulWidget {
  const MapRadarView({super.key});

  @override
  State<MapRadarView> createState() => _MapRadarViewState();
}

class _MapRadarViewState extends State<MapRadarView> {
  // Keeps track of the selected mode. Default is 'friends'
  Set<String> _scanMode = {'friends'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Top Toggle Button (Friend vs Couple)
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 20.0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'friends',
                label: Text('Find Friends'),
                icon: Icon(Icons.people_alt),
              ),
              ButtonSegment<String>(
                value: 'couple',
                label: Text('Find Couple'),
                icon: Icon(Icons.favorite),
              ),
            ],
            selected: _scanMode,
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _scanMode = newSelection;
              });
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: theme.surface,
              selectedBackgroundColor: _scanMode.first == 'couple'
                  ? theme.secondary.withOpacity(0.3) // Pinkish for couples
                  : theme.primary.withOpacity(0.3),  // Blueish for friends
              foregroundColor: Colors.white70,
              selectedForegroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),

        // Radar takes up the remaining screen space and centers itself
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer radar ring
                    Container(
                      height: 250,
                      width: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primary.withOpacity(0.1), width: 1),
                        color: theme.primary.withOpacity(0.05),
                      ),
                    ),
                    // Middle radar ring
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.secondary.withOpacity(0.3), width: 1),
                        color: theme.secondary.withOpacity(0.05),
                      ),
                    ),
                    // Inner core
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [theme.primary, theme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        // Change icon in the middle based on mode
                        _scanMode.first == 'couple' ? Icons.favorite : Icons.location_on,
                        size: 35,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  // Dynamically update the scanning text based on selection
                  _scanMode.first == 'couple'
                      ? "Scanning for potential matches..."
                      : "Scanning for new friends...",
                  style: const TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 1.1),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.surface,
                    foregroundColor: _scanMode.first == 'couple' ? theme.secondary : theme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    // Trigger refresh animation/logic here
                  },
                  child: const Text("Pulse Location"),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
