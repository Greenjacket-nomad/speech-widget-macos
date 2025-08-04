# Speech Widget for macOS

A menu bar speech-to-text widget that uses OpenAI Whisper for high-accuracy offline transcription. Works with any macOS application.

## Features

✅ **Menu bar widget** - Discrete microphone icon in your menu bar  
✅ **Fn key toggle** - Hold to record, release to transcribe  
✅ **Universal text input** - Inserts text at cursor in any application  
✅ **OpenAI Whisper integration** - High-accuracy speech recognition  
✅ **Offline processing** - No internet required after setup  
✅ **Plugin architecture** - Extensible for text processing

## Installation

### Prerequisites
- macOS 10.15 or later
- Xcode command line tools: `xcode-select --install`
- Python 3 and pip3

### Setup
1. **Install Whisper:**
   ```bash
   pip3 install --user openai-whisper
   ```

2. **Install FFmpeg** (if needed):
   ```bash
   # Download and install to ~/bin
   curl -L https://evermeet.cx/ffmpeg/ffmpeg-7.1.zip -o ffmpeg.zip
   unzip ffmpeg.zip
   mkdir -p ~/bin
   mv ffmpeg ~/bin/
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
   ```

3. **Compile and run:**
   ```bash
   swiftc SpeechWidget_final_backup.swift -o SpeechWidget \
     -framework Cocoa -framework AVFoundation -framework Carbon -framework ApplicationServices
   ./SpeechWidget &
   ```

## Usage

1. **Start the app** - A microphone icon appears in your menu bar
2. **Hold Fn key** - Start recording (icon fills in)
3. **Release Fn key** - Stop recording and transcribe
4. **Text appears** - At your cursor position in any app!

## Permissions Required

On first run, macOS will prompt for:
- **Microphone access** - Required for recording
- **Accessibility access** - Required to insert text in other apps

Grant both permissions in System Preferences > Security & Privacy > Privacy

## Architecture

The app uses a plugin-based architecture for extensibility:

```
SpeechWidgetApp
├── Audio Recording (AVAudioRecorder)
├── Speech Processing (OpenAI Whisper)
├── Text Insertion (Accessibility APIs)
└── Plugin System
    ├── Capitalization Plugin
    ├── Punctuation Plugin
    └── Custom Plugins...
```

## Files

- `SpeechWidget_final_backup.swift` - Main application (working version)
- `whisper_service.py` - Background Whisper service (optional)
- `README.md` - This documentation

## Troubleshooting

**"Microphone icon not showing"**
- Check if app is running: `ps aux | grep SpeechWidget`
- Try recompiling and running again

**"Recording failed"**
- Grant microphone permission in System Preferences

**"Text not inserting"**
- Grant accessibility permission in System Preferences

**"Whisper command not found"**
- Install whisper: `pip3 install --user openai-whisper`
- Check PATH includes ~/bin for ffmpeg

## Contributing

This project uses a plugin-based architecture for easy extension. To add new text processing features:

1. Create a new plugin implementing the `SpeechPlugin` protocol
2. Add it to the `loadPlugins()` function
3. Recompile and test

## License

MIT License - Feel free to use and modify as needed.