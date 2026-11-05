# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub's
"Report a vulnerability" button on the repository's Security tab, not in a
public issue. You will get an answer within a week.

## Supported versions

The latest minor release of the current major version receives security
fixes. Fixes are released on the affected `release/X.Y` branches first.

## Verifying a release

Every release ships checksums and signed build provenance:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```

```bash
gh attestation verify driverforge_1.0.0-1_amd64.deb --repo 7shantanu7/driverforge
```

The attestation proves the file was built by this repository's release
workflow from the tagged commit.
