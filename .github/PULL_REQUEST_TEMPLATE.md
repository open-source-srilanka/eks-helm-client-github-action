# Pull Request

## 📝 Description

### Summary

Provide a brief description of the changes in this PR.

### Related Issues

Fixes #(issue number)
Related to #(issue number)

## 🎯 Type of Change

Please check the type of change your PR introduces:

- [ ] 🐛 **Bug fix** (non-breaking change which fixes an issue)
- [ ] ✨ **New feature** (non-breaking change which adds functionality)
- [ ] 💥 **Breaking change** (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 **Documentation** (changes to documentation only)
- [ ] 🎨 **Style** (formatting, missing semicolons, etc; no production code change)
- [ ] ♻️ **Refactoring** (refactoring production code, e.g. renaming a variable)
- [ ] ⚡ **Performance** (changes that improve performance)
- [ ] 🧪 **Test** (adding missing tests, refactoring tests; no production code change)
- [ ] 🔧 **Chore** (updating grunt tasks etc; no production code change)
- [ ] 🔒 **Security** (changes that improve security)

## 🔍 Changes Made

### Core Changes
- [ ] Modified `action.yml`
- [ ] Updated `Dockerfile`
- [ ] Changed `scripts/entrypoint.sh`
- [ ] Updated documentation
- [ ] Added new scripts
- [ ] Modified templates
- [ ] Updated workflows

### Detailed Changes

#### Files Modified
List the main files that were changed and what was done to each:

- `file1.ext`: Description of changes
- `file2.ext`: Description of changes

#### New Features/Functionality
If this PR adds new features, describe them:

#### Bug Fixes
If this PR fixes bugs, describe what was broken and how it was fixed:

#### Breaking Changes
If this PR contains breaking changes, describe them and the migration path:

## 🧪 Testing

### Test Strategy

- [ ] **Unit Tests**: Added/updated unit tests
- [ ] **Integration Tests**: Tested with real EKS clusters
- [ ] **Manual Testing**: Manually verified functionality
- [ ] **Regression Testing**: Ensured existing functionality still works
- [ ] **Documentation Testing**: Verified examples work as documented

### Test Environment

**Infrastructure tested:**
- [ ] Public EKS cluster
- [ ] Private EKS cluster  
- [ ] Public Helm registry
- [ ] Private Helm registry

**Runner environment:**
- [ ] GitHub-hosted runners
- [ ] Self-hosted runners

**Tool versions tested:**
- kubectl: _____
- Helm: _____
- AWS CLI: _____

### Test Results

<details>
<summary>Click to expand test results</summary>

```
Paste test output, workflow run results, or any relevant testing information here.
```

</details>

## 📋 Checklist

### Development Checklist

- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

### Documentation Checklist

- [ ] Updated README.md if needed
- [ ] Updated CHANGELOG.md
- [ ] Updated migration guide if breaking changes
- [ ] Added examples for new features
- [ ] Updated troubleshooting guide if relevant

### Security Checklist

- [ ] No secrets or sensitive information in code
- [ ] No hardcoded credentials
- [ ] Proper input validation
- [ ] Secure handling of temporary files
- [ ] Appropriate cleanup of sensitive data

### Compatibility Checklist

- [ ] Backward compatibility maintained (or breaking changes documented)
- [ ] Works with both v1 and v2 input formats (if applicable)
- [ ] Compatible with supported kubectl versions
- [ ] Compatible with supported Helm versions
- [ ] Works with different EKS configurations

## 🚀 Deployment Impact

### Version Impact

Will this change require a version bump?

- [ ] **Patch** (bug fixes, minor improvements)
- [ ] **Minor** (new features, backward compatible)
- [ ] **Major** (breaking changes)

### User Impact

How will this change affect users?

- [ ] No impact on existing users
- [ ] Minor configuration changes needed
- [ ] Major migration required
- [ ] New capabilities available

### Rollback Plan

If this change causes issues, how can it be rolled back?

## 📸 Screenshots

If applicable, add screenshots showing:
- New functionality in action
- Before/after comparisons
- UI changes
- Error message improvements

## 🔗 Additional Context

### References

Links to relevant resources:
- Issue: #___
- Documentation: [link]
- Related PR: #___
- External reference: [link]

### Dependencies

Any dependencies or prerequisites:
- [ ] Requires specific AWS permissions
- [ ] Depends on external service
- [ ] Requires minimum tool versions
- [ ] Other: _____

### Future Considerations

What should be considered for future development?

---

## 📝 Review Notes

### For Reviewers

Please pay special attention to:

- [ ] Security implications
- [ ] Backward compatibility
- [ ] Error handling
- [ ] Documentation accuracy
- [ ] Test coverage

### Merge Requirements

This PR should not be merged until:

- [ ] All CI checks pass
- [ ] Documentation is updated
- [ ] At least one approval from maintainer
- [ ] All comments are resolved
- [ ] CHANGELOG.md is updated

---

**Thank you for contributing to the EKS Helm Client GitHub Action! 🙏**