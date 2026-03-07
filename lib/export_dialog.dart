/// Export dialog — preview and save/copy benchmark results as JSON.
library;

import "package:flutter/material.dart";

import "platform_utils.dart";

/// Dialog that shows a JSON preview with Save and Copy actions.
class ExportDialog extends StatelessWidget {
  /// The JSON string to export.
  final String json;

  const ExportDialog({super.key, required this.json});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Export Results"),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final ts = DateTime.now().millisecondsSinceEpoch;
                    final msg = await PlatformUtils.saveJsonFile(
                      json,
                      "benchmark_$ts.json",
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: Colors.greenAccent,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text("Save to File"),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    PlatformUtils.copyToClipboard(json);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Copied to clipboard"),
                        backgroundColor: Colors.greenAccent,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text("Copy"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Preview:",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  json,
                  style: const TextStyle(fontSize: 10, fontFamily: "monospace"),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
