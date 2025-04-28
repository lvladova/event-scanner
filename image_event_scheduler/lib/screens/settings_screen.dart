import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoOcr = true;
  bool _saveHistory = true;
  int _defaultReminderMinutes = 15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // OCR Settings
          _buildSectionHeader('OCR Settings'),
          SwitchListTile(
            title: const Text('Auto-extract text'),
            subtitle: const Text('Automatically extract text when image is selected'),
            value: _autoOcr,
            onChanged: (value) {
              setState(() => _autoOcr = value);
            },
            activeColor: Colors.blue,
            tileColor: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(height: 8),

          // Calendar Settings
          _buildSectionHeader('Calendar Settings'),
          ListTile(
            title: const Text('Default reminder time'),
            subtitle: Text('$_defaultReminderMinutes minutes before event'),
            tileColor: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            trailing: SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                value: _defaultReminderMinutes,
                dropdownColor: const Color(0xFF1E1E2C),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  border: InputBorder.none,
                ),
                items: [5, 10, 15, 30, 60, 120].map((minutes) {
                  return DropdownMenuItem<int>(
                    value: minutes,
                    child: Text('$minutes min'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _defaultReminderMinutes = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // App Settings
          _buildSectionHeader('App Settings'),
          SwitchListTile(
            title: const Text('Save scan history'),
            subtitle: const Text('Keep record of previously scanned events'),
            value: _saveHistory,
            onChanged: (value) {
              setState(() => _saveHistory = value);
            },
            activeColor: Colors.blue,
            tileColor: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),

          // About Section
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Event Scanner v1.0.0'),
                const SizedBox(height: 4),
                const Text('© 2025 - All rights reserved'),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Show about dialog or visit website
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Visit Website'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blue[300],
        ),
      ),
    );
  }
}