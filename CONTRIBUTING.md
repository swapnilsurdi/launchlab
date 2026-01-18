# Contributing to LaunchLab

Thank you for your interest in contributing! LaunchLab is a community-driven project aimed at making self-hosting accessible to everyone.

## Philosophy

LaunchLab follows these guiding principles:

1. **Simplicity first** - Prefer easy over powerful
2. **Family-friendly** - Target non-technical users
3. **Official images only** - No custom Docker builds
4. **Pre-configured defaults** - Minimize manual setup
5. **VPN-secured** - Security through isolation, not complexity

## Ways to Contribute

### 1. Report Bugs

Found a bug? [Open an issue](../../issues/new) with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- System info (OS, Docker version)
- Relevant logs (`docker compose logs`)

### 2. Suggest Features

Have an idea? [Start a discussion](../../discussions) to:
- Explain the use case
- Describe the proposed solution
- Consider impact on simplicity (is it worth the complexity?)

### 3. Improve Documentation

Documentation PRs are always welcome:
- Fix typos or unclear instructions
- Add troubleshooting tips
- Create service-specific guides
- Translate to other languages

### 4. Add Services

Want to integrate a new service? Follow these guidelines:

**Before starting:**
- Check if service has official Docker image
- Verify it fits LaunchLab's scope (family homelab use)
- Discuss in GitHub Discussions first

**Requirements:**
- Must use official Docker image (no custom builds)
- Should integrate with existing PostgreSQL/Redis if possible
- Must work with default credentials (admin/changeme)
- Needs health check endpoint
- Requires documentation in `docs/services/[service].md`

**Process:**
1. Fork the repository
2. Create feature branch (`git checkout -b add-service-name`)
3. Add service to `docker-compose.yml`
4. Update `.env.template` with required variables
5. Create documentation
6. Test fresh deployment
7. Submit pull request

### 5. Code Contributions

**Setup development environment:**

```bash
# Clone your fork
git clone https://github.com/your-username/LaunchLab.git
cd LaunchLab

# Test fresh deployment
bash scripts/quicksetup.sh
docker compose up -d

# Make changes
# ...

# Test changes
docker compose down
rm -rf data/ .env
bash scripts/quicksetup.sh
docker compose up -d
```

**Code style:**
- Bash scripts: Follow Google Shell Style Guide
- Python scripts: PEP 8
- YAML: 2-space indentation
- Comments: Explain "why" not "what"

**Commit messages:**
```
[type]: Brief description (50 chars max)

Longer explanation if needed (72 chars per line)

Fixes #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## Pull Request Process

1. **Fork & branch** - Create feature branch from `main`
2. **Make changes** - Follow code style, add tests if applicable
3. **Test thoroughly** - Fresh install, all services work
4. **Update docs** - README, CHANGELOG, service docs
5. **Submit PR** - Clear description, link related issues
6. **Code review** - Address feedback, iterate
7. **Merge** - Maintainer merges when approved

**PR checklist:**
- [ ] Fresh install tested on clean VM
- [ ] All services start without errors
- [ ] Health checks pass
- [ ] Default credentials work
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No secrets in committed files

## Development Workflow

### Testing on Clean Environment

```bash
# Use Docker container for testing
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  ubuntu:24.04 bash

# Inside container
apt update && apt install -y docker.io docker-compose git
cd /workspace
bash scripts/quicksetup.sh
docker compose up -d
```

### Debugging Services

```bash
# View logs
docker compose logs [service]

# Follow logs live
docker compose logs -f [service]

# Check health status
docker compose ps

# Enter container shell
docker exec -it [container] sh

# Restart single service
docker compose restart [service]
```

## Release Process

Maintainers follow this release process:

1. **Prepare release**
   - Update VERSION file
   - Update CHANGELOG.md
   - Test on multiple platforms

2. **Create release**
   - Git tag: `git tag v1.0.0`
   - Push: `git push origin v1.0.0`
   - GitHub release with notes

3. **Announce**
   - Update README badges
   - Post in discussions
   - Social media (if applicable)

## Community Guidelines

### Be Respectful
- Treat everyone with respect
- Welcome newcomers
- Assume good faith
- No harassment, discrimination, or toxicity

### Be Helpful
- Answer questions patiently
- Share knowledge generously
- Document solutions for others
- Link to existing docs when possible

### Be Collaborative
- Credit others' ideas
- Review PRs constructively
- Discuss before major changes
- Reach consensus on direction

## Getting Help

- **Questions?** → [GitHub Discussions](../../discussions)
- **Bug reports?** → [GitHub Issues](../../issues)
- **Security issues?** → Email (see SECURITY.md)
- **Chat?** → (Coming soon)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to LaunchLab!** Every contribution, no matter how small, helps make self-hosting more accessible. 🚀
