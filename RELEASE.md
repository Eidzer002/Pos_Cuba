# POS Cuba - Release Configuration

## Correr en desarrollo
```bash
flutter run --dart-define=SUPABASE_URL=https://uvqcfgrtddccklppynju.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2cWNmZ3J0ZGRjY2tscHB5bmp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NzExMzIsImV4cCI6MjA5MDA0NzEzMn0.SXlZhQOGedM6XzT5c60j8dnzn4yIr8JjmlvrZdR33_E --dart-define=POWERSYNC_URL=https://your-powersync-instance.powersync.co
```

## Build de release
```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info --dart-define=SUPABASE_URL=https://uvqcfgrtddccklppynju.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2cWNmZ3J0ZGRjY2tscHB5bmp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NzExMzIsImV4cCI6MjA5MDA0NzEzMn0.SXlZhQOGedM6XzT5c60j8dnzn4yIr8JjmlvrZdR33_E --dart-define=POWERSYNC_URL=https://your-powersync-instance.powersync.co
```
