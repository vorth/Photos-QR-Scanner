# Photos-QR-Scanner
## Features

This macOS app captures and processes photo metadata, including:
- QR code detection
- GPS coordinates and location information
- Historic temperature data
- User notes and collector information

### Web Viewer

The app includes a built-in HTTP server that allows you to view photo metadata in a web browser:

1. Select photos in the app
2. Click **"View in Browser"** button
3. The browser automatically opens to `http://localhost:8000`
4. View all photo metadata in a beautifully formatted HTML interface

### Export

You can also export the photo data to a JSON file by clicking **"Export to JSON"**.

## Requirements

- macOS 12.0+
- Photos library access permission