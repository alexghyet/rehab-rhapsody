/// A separate backing track whose media position is the song game's clock.
/// Asset paths use audioplayers' default `assets/` prefix implicitly.
abstract class SongAudioPlayer {
  Stream<Duration> get positions;
  Stream<void> get completions;

  /// Prepare an asset without starting it. Loading the current asset preserves
  /// its position, so an explicit play after pause resumes where it stopped.
  Future<void> load(String assetPath);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

/// Platform seam used to test source changes and cancellation deterministically.
abstract interface class SongAudioDriver {
  Stream<Duration> get positions;
  Stream<void> get completions;
  Future<void> load(String assetPath);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
