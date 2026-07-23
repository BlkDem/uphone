package storage

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/uphone/server/internal/config"
)

type Storage interface {
	Upload(ctx context.Context, key string, reader io.Reader, size int64, contentType string) error
	Get(ctx context.Context, key string) (io.ReadCloser, error)
	GetContentType(ctx context.Context, key string) (string, error)
	Delete(ctx context.Context, key string) error
	Exists(ctx context.Context, key string) bool
}

// S3Storage implements Storage using MinIO/S3
type S3Storage struct {
	client *minio.Client
	bucket string
}

func NewS3Storage(cfg *config.Config) (*S3Storage, error) {
	if cfg.MinIOEndpoint == "" {
		return nil, fmt.Errorf("MINIO_ENDPOINT is not set")
	}

	minioClient, err := minio.New(cfg.MinIOEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
		Secure: cfg.MinIOUseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create minio client: %w", err)
	}

	s := &S3Storage{client: minioClient, bucket: cfg.MinIOBucket}

	exists, err := s.client.BucketExists(context.Background(), cfg.MinIOBucket)
	if err != nil {
		return nil, fmt.Errorf("failed to check bucket: %w", err)
	}
	if !exists {
		err = s.client.MakeBucket(context.Background(), cfg.MinIOBucket, minio.MakeBucketOptions{})
		if err != nil {
			return nil, fmt.Errorf("failed to create bucket: %w", err)
		}
		log.Printf("S3: created bucket %s", cfg.MinIOBucket)
	}

	log.Printf("S3: connected to %s, bucket=%s", cfg.MinIOEndpoint, cfg.MinIOBucket)
	return s, nil
}

func (s *S3Storage) Upload(ctx context.Context, key string, reader io.Reader, size int64, contentType string) error {
	_, err := s.client.PutObject(ctx, s.bucket, key, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	return err
}

func (s *S3Storage) Get(ctx context.Context, key string) (io.ReadCloser, error) {
	obj, err := s.client.GetObject(ctx, s.bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, err
	}
	_, err = obj.Stat()
	if err != nil {
		obj.Close()
		return nil, err
	}
	return obj, nil
}

func (s *S3Storage) GetContentType(_ context.Context, key string) (string, error) {
	obj, err := s.client.StatObject(context.Background(), s.bucket, key, minio.StatObjectOptions{})
	if err != nil {
		return "", err
	}
	return obj.ContentType, nil
}

func (s *S3Storage) Delete(ctx context.Context, key string) error {
	return s.client.RemoveObject(ctx, s.bucket, key, minio.RemoveObjectOptions{})
}

func (s *S3Storage) Exists(_ context.Context, key string) bool {
	_, err := s.client.StatObject(context.Background(), s.bucket, key, minio.StatObjectOptions{})
	return err == nil
}

// LocalStorage implements Storage using local filesystem (fallback)
type LocalStorage struct {
	dir string
}

func NewLocalStorage(dir string) *LocalStorage {
	return &LocalStorage{dir: dir}
}

func (l *LocalStorage) Upload(_ context.Context, key string, reader io.Reader, _ int64, _ string) error {
	path := filepath.Join(l.dir, filepath.Base(key))
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, reader)
	return err
}

func (l *LocalStorage) Get(_ context.Context, key string) (io.ReadCloser, error) {
	path := filepath.Join(l.dir, filepath.Base(key))
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil, fmt.Errorf("file not found")
	}
	return os.Open(path)
}

func (l *LocalStorage) GetContentType(_ context.Context, key string) (string, error) {
	path := filepath.Join(l.dir, filepath.Base(key))
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg", nil
	case ".png":
		return "image/png", nil
	case ".gif":
		return "image/gif", nil
	case ".webp":
		return "image/webp", nil
	case ".mp4":
		return "video/mp4", nil
	case ".webm":
		return "video/webm", nil
	case ".mp3":
		return "audio/mpeg", nil
	case ".ogg":
		return "audio/ogg", nil
	case ".pdf":
		return "application/pdf", nil
	case ".csv":
		return "text/csv", nil
	default:
		return "application/octet-stream", nil
	}
}

func (l *LocalStorage) Delete(_ context.Context, key string) error {
	path := filepath.Join(l.dir, filepath.Base(key))
	return os.Remove(path)
}

func (l *LocalStorage) Exists(_ context.Context, key string) bool {
	path := filepath.Join(l.dir, filepath.Base(key))
	_, err := os.Stat(path)
	return err == nil
}

// ServeFile serves a file from the appropriate storage backend
func ServeFile(w http.ResponseWriter, r *http.Request, s Storage, filename string) {
	reader, err := s.Get(r.Context(), filename)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer reader.Close()

	contentType, _ := s.GetContentType(r.Context(), filename)
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "public, max-age=31536000")
	io.Copy(w, reader)
}
