## Go Modules (Implicit Publishing)

Go modules are published automatically via git tags:

```bash
# Tag release
git tag v1.2.3
git push origin v1.2.3

# Users can install directly
go install github.com/your-org/your-cli@v1.2.3
```

**No workflow needed**. Go proxy fetches from GitHub tags automatically.

**Scorecard result**: Packaging 10/10
