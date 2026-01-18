# Development Test Scripts

Test scripts for validating LaunchLab installation across different environments.

## test-fresh-install.sh

Tests the complete installation process from scratch on the current system.

### What it does:

1. **Creates unique test folder** - Random name ensures isolated Docker containers
2. **Copies repository** - Tests local changes without affecting main repo
3. **Generates config** - Creates .env file with test credentials
4. **Starts services** - Runs `docker compose up -d`
5. **Monitors health** - Checks every 30 seconds for up to 10 minutes
6. **Reports results** - PASS if all services healthy, FAIL if timeout
7. **Cleans up** - Removes test folder and containers on exit

### Required Services:

- `postgres` - Must be healthy
- `paperless-ngx` - Must be healthy
- `matrix-synapse` - Must be healthy
- `immich-server` - Must be healthy

### Known Limitations:

**Port Conflicts:**
The test script currently uses the SAME ports as the main LaunchLab instance.

**Workaround:** Stop your main LaunchLab before running tests:
```bash
# From main LaunchLab directory
docker compose down

# Run test
bash scripts/devtest-scripts/test-fresh-install.sh

# Restart main LaunchLab after test
docker compose up -d
```

**Future Fix:** Dynamic port remapping to allow parallel testing.

### Usage:

```bash
# Run test from LaunchLab root directory
bash scripts/devtest-scripts/test-fresh-install.sh
```

### Configuration:

Edit these variables in the script to customize:

```bash
MAX_WAIT_MINUTES=10      # Timeout (default: 10 minutes)
CHECK_INTERVAL=30        # Check frequency (default: 30 seconds)
```

### Output:

**Success:**
```
[TEST] All required services are healthy!
[TEST] TEST PASSED - Installation successful!
```

**Failure:**
```
[TEST] Timeout reached (10 minutes)
[TEST] Not all services became healthy
[TEST] TEST FAILED - Services did not become healthy in time
```

### Cleanup:

The script automatically cleans up on exit:
- Stops and removes all test containers
- Removes test directory
- No manual cleanup needed

### Test Folder Location:

Test folders are created in `launchlab-startup-tests/` with pattern:
```
LaunchLab/
├── launchlab-startup-tests/
│   └── test-{timestamp}-{random}/
│       ├── docker-compose.yml
│       ├── .env
│       └── ... (all LaunchLab files)
```

Example: `launchlab-startup-tests/test-1705123456-12345/`

The `launchlab-startup-tests/` directory is gitignored and auto-created.

### Docker Container Names:

Docker Compose uses the folder name as project name, so containers will be named:
```
test-1705123456-12345-postgres-1
test-1705123456-12345-paperless-ngx-1
...
```

This ensures no conflicts with existing LaunchLab installations.

### Cleanup on Failure:

The script uses `trap cleanup EXIT INT TERM` which ensures cleanup happens:
- ✅ On normal exit (success or failure)
- ✅ On script interrupt (Ctrl+C)
- ✅ On termination signal
- ✅ On any error (even with `set -e`)

The cleanup function:
1. Stops and removes all Docker containers
2. Removes test directory
3. Removes base directory if empty
4. Preserves original exit code

## Future Tests

Additional test scripts will be added for:

- [ ] Ubuntu/Debian (Linux)
- [ ] macOS (ARM64)
- [ ] Windows (WSL2)
- [ ] CentOS/RHEL (Linux)

Each OS-specific test will use the same core logic with OS-specific adaptations.
