# Project Context (XDUWhisperBox)

This file (`CONTEXT.md`) serves as the central source of truth for AI coding assistants (Gemini CLI, Cursor, Claude Code, etc.) to understand the project architecture, tech stack, and development conventions.

**Please read this file carefully before making any codebase modifications.**

## 1. Project Overview
XDUWhisperBox is a cross-platform anonymous social application (Treehole). It features a shared backend servicing multiple frontends.

## 2. Monorepo Architecture
This repository follows a multi-package Monorepo structure. All code is segregated into specific directories based on their domain.

```text
XDUWhisperBox/
├── backend/            # Python Backend Services (FastAPI/Flask/etc.)
├── flutter_app/        # Flutter Client (Mobile - Android/iOS & Web)
├── miniprogram/        # WeChat Mini Program (Upcoming)
├── docs/               # Project documentation and specifications
├── scripts/            # Shell scripts for building and deployment
├── deploy/             # Deployment configurations (e.g., Docker, Nginx)
├── test/               # Root-level integration or utility tests (if applicable)
└── CONTEXT.md          # THIS FILE: Global AI assistant context
```

### 2.1 Backend (`backend/`)
- **Language:** Python 3.x
- **Responsibilities:** API endpoints, database interactions (MySQL/PostgreSQL), authentication, business logic, object storage.
- **Note:** All frontends (Flutter, Mini Program) consume these APIs.

### 2.2 Flutter App (`flutter_app/`)
- **Framework:** Flutter / Dart
- **Target Platforms:** Android, iOS, Web
- **Structure:** Standard Flutter project structure. 
- **Important:** When running Flutter commands (e.g., `flutter pub get`, `flutter build`), you **MUST** execute them from within the `flutter_app/` directory, not the repository root.

### 2.3 WeChat Mini Program (`miniprogram/`)
- **Status:** Initialization Phase.
- **Framework:** (To be decided - Native WXML/WXSS, Taro, or UniApp).
- **Responsibilities:** WeChat ecosystem integration, utilizing the shared `backend/` APIs.

## 3. General AI Guidelines & Conventions

### 3.1 Directory Context Awareness
- **Always verify your working directory.** 
- If asked to fix a Flutter UI bug, target `flutter_app/lib/...`.
- If asked to modify an API endpoint, target `backend/handlers/...`.
- **Never** place Flutter-specific configurations (`pubspec.yaml`, etc.) at the project root anymore.

### 3.2 Code Style and Integrity
- **Idiomatic Code:** Follow the standard conventions of the target language (Dart for Flutter, Python for Backend).
- **Type Safety:** Maintain strict typing. Do not bypass type checkers or linters unless explicitly requested.
- **Testing:** When adding features or fixing bugs, verify if tests exist and update them accordingly.

### 3.3 State Management & Architecture
- **Flutter:** Adhere to the existing state management solutions established in `flutter_app/lib/`.
- **Backend:** Maintain the separation of concerns between `handlers/`, `services/`, and `helpers/`.

### 3.4 Operational Safety
- **No Unprompted Commits:** Do not stage or commit code (`git add`, `git commit`) unless the user explicitly asks you to.
- **Security:** Do not log, print, or expose API keys, secrets, or database credentials. Be cautious when modifying files in `deploy/` or `.env` files.

## 4. How to use this file
When starting a new session with an AI tool, if the tool does not automatically read workspace context, you can prompt it with:
> "Please review CONTEXT.md to understand the current monorepo structure and tech stack before proceeding."
