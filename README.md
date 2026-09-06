# HDShare for macOS

**HDShare** is a native macOS menu bar and window application built in Swift/SwiftUI with bundled FFmpeg. It slices videos **losslessly** (`ffmpeg -c copy`) into exact parts tailored to platform file size limits **without any video compression or re-encoding**.

---

## 💎 Pricing & Freemium Tiers

- **🆓 Free Plan (Included Forever):**
  - **WhatsApp Status (30-second & 60-second lossless slices):** Free for all users with zero limits.
- **👑 Pro Plan ($4.99 One-Time / Lifetime):**
  - **WhatsApp HD Chat (95 MB Limit):** Dynamically computed to stay under WhatsApp's 100 MB upload ceiling.
  - **Discord Free & Email Attachment (25 MB Limit):** Fits Gmail, Apple Mail, Outlook, and Discord without Nitro.
  - **Telegram Large Video (2 GB Limit):** Slices full-length 4K movies & recordings.
  - **Custom File Size (MB) & Custom Duration (Seconds):** Set any target limit.

---

## ✨ Features

- **📦 Self-Contained with Bundled FFmpeg:** FFmpeg binary is bundled directly inside the `.app` bundle (`Contents/Resources/ffmpeg`). No Homebrew or terminal setup required for end users.
- **⚡ Zero Video Compression & 100% Quality Preserved:** No re-encoding applied. Original 4K/1080p video & audio streams are preserved bit-for-bit.
- **🔑 Lemon Squeezy License System:** Built-in license activation and verification. License keys are stored securely in macOS Keychain.
- **📊 Dynamic Bitrate Formula:**
  $$\text{Max Duration (seconds)} = \frac{\text{Target MB} \times 8,000,000}{\text{Total Bitrate (bps)}}$$
- **🖱️ Finder Right-Click Quick Action:** Right-click any video file in Finder $\rightarrow$ Quick Actions $\rightarrow$ **"Split & Share for WhatsApp HD"**.
- **📋 One-Click "Copy All":** Copies all split parts directly to the macOS clipboard for instant sequential pasting with **Cmd+V**.
- **💻 Menu Bar Extra & Window:** Drag & drop from anywhere on your Mac.

---

## 🚀 Quick Start

### 1. Requirements
- macOS 13.0 (Ventura) or later
- `ffmpeg` (Installed via Homebrew: `brew install ffmpeg`)

### 2. Build the App
```bash
./build_app.sh
```
This produces `build/HDShare.app`. You can move it to your `/Applications` folder:
```bash
cp -R build/HDShare.app /Applications/
```

### 3. Install Finder Right-Click Quick Action
```bash
./install_finder_action.sh
```
After running this, right-click any video file in Finder $\rightarrow$ **Quick Actions** $\rightarrow$ **Split & Share for WhatsApp HD**.

---

## 🛠️ Usage

1. **Option A (Right-Click in Finder):**
   - Right-click any `.mp4`, `.mov`, `.mkv`, etc. $\rightarrow$ **Quick Actions** $\rightarrow$ **Split & Share for WhatsApp HD**.
2. **Option B (Drag & Drop in Menu Bar / App):**
   - Drag any video into the HDShare window or menu bar popup.
3. **Choose Mode:**
   - *WhatsApp Status (30s Lossless)*: Default for WhatsApp Status/Stories.
   - *WhatsApp Status (60s Lossless)*: For 60-second status updates.
   - *Custom Split Duration*: Set custom chunk length.
   - *WhatsApp HD Chat*: High-quality H.264 optimization.
   - *WhatsApp Document*: Send full file uncompressed.
4. **Click "Process & Split HD Video"**:
   - Takes just 1-2 seconds with lossless stream copy.
5. **Share to WhatsApp**:
   - Click **"Copy All for WhatsApp"** $\rightarrow$ Open WhatsApp chat $\rightarrow$ press **Cmd + V** to paste all parts in order.
   - Or click **"Open WhatsApp"** / **"Show in Finder"** / Share icon.
