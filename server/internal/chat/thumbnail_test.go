package chat

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"testing"
)

func newTestPNG(t *testing.T, width, height int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for x := 0; x < width; x++ {
		for y := 0; y < height; y++ {
			img.Set(x, y, color.RGBA{R: uint8(x % 256), G: uint8(y % 256), B: 120, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode test png: %v", err)
	}
	return buf.Bytes()
}

func newTestJPEG(t *testing.T, width, height int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for x := 0; x < width; x++ {
		for y := 0; y < height; y++ {
			img.Set(x, y, color.RGBA{R: uint8(x % 256), G: uint8(y % 256), B: 120, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 90}); err != nil {
		t.Fatalf("encode test jpeg: %v", err)
	}
	return buf.Bytes()
}

func TestGenerateImageThumbnailScalesWidth(t *testing.T) {
	thumb, w, h, err := generateImageThumbnail(newTestPNG(t, 1920, 1080), 360)
	if err != nil {
		t.Fatalf("generateImageThumbnail: %v", err)
	}
	if w != 360 {
		t.Errorf("expected width 360, got %d", w)
	}
	if h != 203 {
		t.Errorf("expected height 203 (1080*360/1920 rounded), got %d", h)
	}
	if len(thumb) == 0 {
		t.Error("expected non-empty thumbnail bytes")
	}

	cfg, _, err := image.DecodeConfig(bytes.NewReader(thumb))
	if err != nil {
		t.Fatalf("decode thumbnail: %v", err)
	}
	if cfg.Width != 360 || cfg.Height != 203 {
		t.Errorf("decoded thumbnail dimensions %dx%d, want 360x203", cfg.Width, cfg.Height)
	}
}

func TestGenerateImageThumbnailKeepsSmallImages(t *testing.T) {
	thumb, w, h, err := generateImageThumbnail(newTestJPEG(t, 200, 300), 360)
	if err != nil {
		t.Fatalf("generateImageThumbnail: %v", err)
	}
	if w != 200 || h != 300 {
		t.Errorf("expected original 200x300, got %dx%d", w, h)
	}
	if len(thumb) == 0 {
		t.Error("expected non-empty thumbnail bytes")
	}
}

func TestGenerateImageThumbnailPortrait(t *testing.T) {
	thumb, w, h, err := generateImageThumbnail(newTestPNG(t, 1000, 2000), 360)
	if err != nil {
		t.Fatalf("generateImageThumbnail: %v", err)
	}
	if w != 360 {
		t.Errorf("expected width 360, got %d", w)
	}
	if h != 720 {
		t.Errorf("expected height 720, got %d", h)
	}
	if len(thumb) == 0 {
		t.Error("expected non-empty thumbnail bytes")
	}
}

func TestGenerateImageThumbnailInvalidData(t *testing.T) {
	if _, _, _, err := generateImageThumbnail([]byte("not an image"), 360); err == nil {
		t.Error("expected error for invalid image data")
	}
}

func TestThumbnailName(t *testing.T) {
	tests := []struct {
		key  string
		want string
	}{
		{"abc_123.mp4", "abc_123_thumb.jpg"},
		{"abc_123.png", "abc_123_thumb.jpg"},
		{"noext", "noext_thumb.jpg"},
	}
	for _, tt := range tests {
		if got := thumbnailName(tt.key); got != tt.want {
			t.Errorf("thumbnailName(%q) = %q, want %q", tt.key, got, tt.want)
		}
	}
}

func TestGenerateVideoThumbnailFailsWithoutFFmpeg(t *testing.T) {
	if _, _, err := generateVideoThumbnail("/nonexistent/video.mp4", "/tmp/out.jpg", 360); err == nil {
		t.Error("expected error for missing video / ffmpeg")
	}
}

func TestDetectMediaType(t *testing.T) {
	tests := []struct {
		name        string
		contentType string
		filename    string
		want        string
	}{
		{"declared image", "image/jpeg", "photo.jpg", "image/jpeg"},
		{"declared video", "video/mp4", "clip.mp4", "video/mp4"},
		{"generic with image ext", "application/octet-stream", "photo.png", "image/png"},
		{"generic with video ext", "binary/octet-stream", "clip.mov", "video/quicktime"},
		{"generic unknown ext", "application/octet-stream", "archive.xyz", ""},
		{"empty with ext", "", "clip.webm", "video/webm"},
		{"empty unknown", "", "noext", ""},
	}
	for _, tt := range tests {
		if got := detectMediaType(tt.contentType, tt.filename); got != tt.want {
			t.Errorf("detectMediaType(%q, %q) = %q, want %q", tt.contentType, tt.filename, got, tt.want)
		}
	}
}
