# Nyan Read - Architecture & Engineering Design

## 1. Project Overall Architecture (Layered & Modular)

We follow a **Clean Architecture** approach adapted for Flutter, emphasizing strict separation of concerns to satisfy the "Plug-and-Play" modularity requirement.

### **Layer 1: Application Layer (The "Glue")**
- **Main Entry (`main.dart`)**: Initializes the app, dependency injection, and loads the Feature Flag configuration.
- **App Coordinator**: Routing and global state (Theme, Locale).

### **Layer 2: Feature Modules (The "Business Logic")**
Each module is a self-contained package/directory containing its own Views, Controllers (Providers), and Models.
- **CoreReader**: The engine. Handles file parsing (epub/pdf) and rendering logic.
- **Bookshelf**: Public file management and grid UI.
- **PrivacyShelf (Pro)**: Encrypted file management and authentication walls.
- **Bookmark**: CRUD operations for bookmarks, linked to Book IDs.
- **Reminder**: Timer logic and UI overlays.
- **Account/Admin**: Admin panel, Pro status toggling, Feature Flag controls.

### **Layer 3: Service Layer (Infrastructure)**
- **Storage Service**: Raw file I/O.
- **Database Service**: SQLite abstraction.
- **Encryption Service**: AES-256 logic (used by PrivacyShelf).
- **Preference Service**: Key-value pairs for simple settings (brightness, font size).

---

## 2. Module Dependency Graph

```mermaid
graph TD
    %% Infrastructure
    DB[Database Service]
    FS[File System]
    ENC[Encryption (AES-256)]
    PREF[Preferences]

    %% Core
    CR[CoreReader]
    ACC[Account/Admin]

    %% Features
    BS[Bookshelf]
    PS[PrivacyShelf]
    BM[Bookmark]
    RM[Reminder]
    UI[UITheme]

    %% Dependencies
    BS --> DB
    BS --> FS
    
    PS --> DB
    PS --> FS
    PS --> ENC
    PS --> ACC (Check Pro Status)

    BM --> DB
    BM --> CR (Get Page Index)

    CR --> UI (Apply Theme)
    CR --> PREF (Save Progress)
    
    RM --> PREF
    
    %% The Application
    APP[Nyan App] --> CR
    APP --> BS
    APP --> PS
    APP --> BM
    APP --> ACC
```

---

## 3. Database Table Structure (SQLite)

### Table: `books`
Stores metadata for both public and private books.

```sql
CREATE TABLE books (
    id TEXT PRIMARY KEY,              -- UUID
    title TEXT NOT NULL,
    author TEXT,
    file_path TEXT NOT NULL,          -- Local path (relative)
    cover_path TEXT,
    format TEXT NOT NULL,             -- 'epub', 'txt', 'pdf'
    is_private INTEGER DEFAULT 0,     -- 0: Public, 1: Private (Pro)
    total_pages INTEGER,
    current_progress REAL DEFAULT 0,  -- Percentage or Page Index
    last_read_at INTEGER,             -- Timestamp
    added_at INTEGER                  -- Timestamp
);
```

### Table: `bookmarks`
One-to-many relation with books.

```sql
CREATE TABLE bookmarks (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL,
    page_index INTEGER NOT NULL,
    cfi TEXT,                         -- EPUB CFI or specific locator
    content_snippet TEXT,             -- Small text preview
    note TEXT,                        -- User remark
    created_at INTEGER,
    color_code TEXT,                  -- For UI customization
    FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
);
```

### Table: `reading_stats`
For the "Reminder" and "Pro Stats" modules.

```sql
CREATE TABLE reading_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date_str TEXT NOT NULL,           -- YYYY-MM-DD
    duration_seconds INTEGER DEFAULT 0,
    books_opened INTEGER DEFAULT 0
);
```

---

## 4. Module Interface Definitions (Dart Draft)

### **IReaderModule**
```dart
abstract class IReaderModule {
  Future<void> openBook(String bookId, String path);
  Future<void> jumpToPage(int pageIndex);
  Future<void> changeFontSize(double size);
  Stream<double> get progressStream; 
}
```

### **IPrivacyModule**
```dart
abstract class IPrivacyModule {
  Future<bool> authenticate(); // Bio/Pin
  Future<File> encryptFile(File source);
  Future<List<int>> decryptFileToMemory(String encryptedPath);
  bool get isProEnabled;
}
```

### **IFeatureFlag**
```dart
abstract class IFeatureFlag {
  bool get isPrivacyShelfEnabled;
  bool get isAdsEnabled;
  bool get isTTSEnabled;
  void toggleFeature(String key, bool value);
}
```

---

## 5. Feature Flag Design (Free vs Pro)

We will use a singleton `FeatureManager`.

**Flags:**
- `enable_privacy_shelf`: Defaults to `false` (Free). `true` (Pro).
- `enable_ads`: Defaults to `true` (Free). `false` (Pro).
- `enable_cloud_sync`: Defaults to `false` (Free). `true` (Pro).
- `enable_tts`: Defaults to `false` (Placeholder).

**Control Flow:**
1. App Start -> Load `UserSubscriptionStatus`.
2. `FeatureManager.init(status)`.
3. In UI: 
   `if (FeatureManager.canUse(Features.privacyShelf)) { showShelf(); } else { showUpsell(); }`
