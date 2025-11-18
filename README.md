# flutter_bunnymark

### Notes
- Impeller is not available on Web, Windows and Linux
- Impeller is the default on iOS with no ability to switch to Skia
- On macOS consider switching to fullscreen to enable Game Mode

### Results

| Hardware | Skia | Impeller |
| - | - | - |
| Apple M2 Max, macOS 15.6.1 | 500,000 | 185,000 |
| iPhone 15, iOS 26.1 | x | 14,000 |
| iPhone 15 Plus, iOS 18.6.2 | x | 14,000 |
| GTX 1070, Ryzen 3600X, Win 11 | 170,000 | x |


----


> Keep in mind that almost any benchmark can be written to show the best-case scenario, while a real project can behave completely differently. So run your own tests and don't rely too much on other people's benchmarks.