package chat

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"
	"os"
	"os/exec"
	"strings"

	"github.com/disintegration/imaging"

	_ "golang.org/x/image/webp"
)

const thumbnailQuality = 82

// generateImageThumbnail resizes the image to at most maxWidth pixels wide
// (preserving aspect ratio) and re-encodes it as JPEG. It returns the JPEG
// bytes together with the resulting thumbnail dimensions.
func generateImageThumbnail(src []byte, maxWidth int) ([]byte, int, int, error) {
	if maxWidth <= 0 {
		maxWidth = 360
	}

	img, err := imaging.Decode(bytes.NewReader(src), imaging.AutoOrientation(true))
	if err != nil {
		return nil, 0, 0, fmt.Errorf("decode image: %w", err)
	}

	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()
	if w <= 0 || h <= 0 {
		return nil, 0, 0, fmt.Errorf("invalid image dimensions %dx%d", w, h)
	}

	if w > maxWidth {
		img = imaging.Resize(img, maxWidth, 0, imaging.Lanczos)
		bounds = img.Bounds()
		w, h = bounds.Dx(), bounds.Dy()
		if h <= 0 {
			h = 1
		}
	}

	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: thumbnailQuality}); err != nil {
		return nil, 0, 0, fmt.Errorf("encode thumbnail: %w", err)
	}
	return buf.Bytes(), w, h, nil
}

// generateVideoThumbnail extracts a frame from the video file located at
// inputPath and writes a JPEG thumbnail (at most maxWidth wide) to outputPath.
// It returns the thumbnail dimensions. The extraction relies on the ffmpeg
// binary; if it is unavailable an error is returned.
func generateVideoThumbnail(inputPath, outputPath string, maxWidth int) (int, int, error) {
	if maxWidth <= 0 {
		maxWidth = 360
	}

	ffmpegPath, err := exec.LookPath("ffmpeg")
	if err != nil {
		return 0, 0, fmt.Errorf("ffmpeg not found: %w", err)
	}

	for _, seek := range []string{"1", "0"} {
		cmd := exec.Command(ffmpegPath,
			"-y",
			"-ss", seek,
			"-i", inputPath,
			"-frames:v", "1",
			"-vf", fmt.Sprintf("scale=%d:-2", maxWidth),
			"-q:v", "3",
			outputPath,
		)
		if out, runErr := cmd.CombinedOutput(); runErr != nil {
			if seek == "1" {
				continue
			}
			return 0, 0, fmt.Errorf("ffmpeg: %v: %s", runErr, truncate(string(out), 300))
		}
		break
	}

	f, err := os.Open(outputPath)
	if err != nil {
		return 0, 0, fmt.Errorf("open video thumbnail: %w", err)
	}
	defer f.Close()

	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		return 0, 0, fmt.Errorf("decode video thumbnail: %w", err)
	}
	return cfg.Width, cfg.Height, nil
}

// thumbnailName returns the storage key for the thumbnail of the given
// uploaded file key (e.g. "abc_123.mp4" -> "abc_123_thumb.jpg").
func thumbnailName(key string) string {
	ext := ""
	if idx := strings.LastIndex(key, "."); idx >= 0 {
		ext = key[idx:]
	}
	return strings.TrimSuffix(key, ext) + "_thumb.jpg"
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
