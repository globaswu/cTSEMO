# Minimal Git guide

Git records versions on this computer. A GitHub account is not required for
local use.

## Record the first version

Before the first commit, configure the author identity that should appear in
the public history:

```powershell
git config user.name "Your Name"
git config user.email "your-email@example.com"
git commit -m "Initial cTSEMO MATLAB companion release"
```

The files in this repository have already been prepared for that first
commit. Replace the example identity with the identity the author wishes to
publish.

## Inspect later changes

```powershell
git status
git diff
```

## Save later changes

```powershell
git add .
git commit -m "Describe the change"
```

## Publish online later

GitHub is optional. If the repository is eventually published there, create
an empty GitHub repository first and follow the commands GitHub displays for
adding a remote and pushing the local `main` branch. Do not include private
benchmark data, credentials, or unpublished material without reviewing the
staged files.
