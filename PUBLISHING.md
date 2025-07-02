# 🚀 Publishing Docker Images to GitHub Container Registry

## ⚡ Quick Start

### 1. 📋 Testing Before Publishing

```bash
Actions → Test Build → Run workflow
- Version: v1.0.0-test
- Branch: master
- Run tests: ✅
```

### 2. 🎯 Publishing

```bash
Actions → Release → Run workflow
- Version: v1.0.0
- Branch: master
- Create tag: ✅
```

### 3. ✅ Result

- Git tag `v1.0.0` created
- Image `ghcr.io/your-username/unbound:1.0.0` published
- GitHub Release created

## 🐳 Using Published Image

```bash
docker run -d \
  --name unbound \
  -p 53:53/udp \
  -p 53:53/tcp \
  ghcr.io/your-username/unbound:1.0.0
```

## 🧪 Workflows

| Workflow | Purpose | When to Use | Version Format |
|----------|---------|-------------|----------------|
| **Test Build** | Fast local testing | Development, debugging | `v1.0.0-test` |
| **Test Published Image** | Test ready images | Before production | `1.0.0`, `latest` |
| **Release** | Full publication | Official releases | `v1.0.0` |

## 🏷️ Versioning

- **v1.0.1** - 🐛 bug fixes
- **v1.1.0** - ✨ new features
- **v2.0.0** - 💥 breaking changes

### 📌 Important: Git vs Docker Tags

- **Git tags**: `v1.0.0` (with 'v' prefix)
- **Docker tags**: `1.0.0` (without 'v' prefix)

When you input `v1.0.0` in Release workflow, it creates:

- Git tag: `v1.0.0`
- Docker images: `ghcr.io/repo:1.0.0`, `ghcr.io/repo:1.0`, `ghcr.io/repo:1`

## 🔧 Troubleshooting

### ❌ Permission Error

Settings → Actions → General → "Read and write permissions"

### ⚠️ Tag Already Exists

Set **Create tag**: ❌

### 🚨 Build Error

Check Actions logs and Dockerfile
