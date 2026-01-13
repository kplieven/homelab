## Stirling-PDF Container Setup

This directory contains the configuration for running [Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF) — a locally hosted web-based PDF manipulation tool — using Docker Compose.

---

**What This Setup Does**

- Deploys Stirling-PDF for comprehensive PDF operations.
- Split, merge, rotate, and reorganize PDFs.
- Convert PDFs to and from various formats.
- OCR support for scanned documents.
- Add/remove passwords and security.
- Fill forms, add/extract images, and more.
- All processing done locally for maximum privacy.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that will be used to access Stirling-PDF. |
| `PORT` | Port for the Stirling-PDF web interface (default: 8484). |


---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)).

4. **Run the container** with Docker Compose:

```sh
docker compose up -d
```

5. **Access Stirling-PDF** at:
    - `http://localhost:8080` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

6. **Use Stirling-PDF**:
    - Upload PDFs or other documents
    - Choose from the available operations
    - Process files locally without uploading to external services

---

## Available Operations

- **General**: Merge, split, rotate, reorganize pages
- **Conversion**: PDF to/from images, Office documents, HTML, etc.
- **Security**: Add/remove passwords, permissions, watermarks
- **Content**: Extract/add images, extract text, OCR
- **Forms**: Fill forms, flatten fields
- **Optimization**: Compress, clean, sanitize
- **Metadata**: View/edit PDF metadata
- **Advanced**: Add page numbers, headers/footers, signatures

---

## Notes

- Configuration files are stored in the `./config` directory.
- Custom files can be placed in `./customFiles/`.
- Logs are available in the `./logs` directory.
- Pipeline configurations for batch processing can be stored in `./pipeline/`.
- OCR training data can be added to `./trainingData/` for improved accuracy.
- All file processing is done locally on your server.
- No files are uploaded to external services, ensuring privacy.
- The tool supports drag-and-drop for easy file management.
- Multiple languages are supported in the interface.
- Batch processing capabilities for automating repetitive tasks.
